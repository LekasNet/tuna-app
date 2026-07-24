#include "flutter_window.h"

#include <flutter/standard_method_codec.h>
#include <shellapi.h>

#include <optional>
#include <sstream>

#include "flutter/generated_plugin_registrant.h"
#include "resource.h"
#include "utils.h"

namespace {

constexpr UINT kTrayCallbackMessage = WM_APP + 1;
constexpr UINT kFirstTunnelOpenMenuId = 40001;
constexpr UINT kFirstTunnelActionMenuId = 40051;
constexpr UINT kOpenProgramMenuId = 40101;
constexpr UINT kStopAllTunnelsMenuId = 40201;
constexpr UINT kQuitMenuId = 40202;

UINT ShowExistingWindowMessage() {
  static const UINT message =
      RegisterWindowMessage(L"ru.lek4s.tuna.show_existing_window");
  return message;
}

std::wstring WStringFromEncodable(const flutter::EncodableValue& value) {
  if (const auto* text = std::get_if<std::string>(&value)) {
    return Utf16FromUtf8(*text);
  }
  return L"";
}

std::string StringFromMap(const flutter::EncodableMap& map,
                          const char* key) {
  auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) {
    return "";
  }

  if (const auto* text = std::get_if<std::string>(&it->second)) {
    return *text;
  }
  return "";
}

std::wstring WStringFromMap(const flutter::EncodableMap& map,
                            const char* key,
                            const std::wstring& fallback = L"") {
  auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) {
    return fallback;
  }

  auto value = WStringFromEncodable(it->second);
  return value.empty() ? fallback : value;
}

int IntFromMap(const flutter::EncodableMap& map, const char* key) {
  auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) {
    return 0;
  }

  if (const auto* value = std::get_if<int32_t>(&it->second)) {
    return *value;
  }
  if (const auto* value = std::get_if<int64_t>(&it->second)) {
    return static_cast<int>(*value);
  }
  return 0;
}

bool BoolFromMap(const flutter::EncodableMap& map, const char* key) {
  auto it = map.find(flutter::EncodableValue(key));
  if (it == map.end()) {
    return false;
  }

  if (const auto* value = std::get_if<bool>(&it->second)) {
    return *value;
  }
  return false;
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  tray_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "ru.lek4s.tuna/status_bar",
      &flutter::StandardMethodCodec::GetInstance());
  tray_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        const auto& method = call.method_name();
        if (method == "initialize") {
          InitializeTray();
          result->Success();
        } else if (method == "updateMenu") {
          UpdateTrayMenu(call.arguments());
          result->Success();
        } else if (method == "hideWindow") {
          HideToTray();
          result->Success();
        } else {
          result->NotImplemented();
        }
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  RemoveTray();
  tray_channel_.reset();

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == ShowExistingWindowMessage()) {
    RestoreFromTray();
    return 0;
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_CLOSE:
      if (force_quit_ || (::GetKeyState(VK_SHIFT) & 0x8000) != 0) {
        force_quit_ = true;
        DestroyWindow(hwnd);
      } else {
        HideToTray();
      }
      return 0;

    case WM_COMMAND: {
      const UINT command_id = LOWORD(wparam);
      const UINT tunnel_count = static_cast<UINT>(tray_tunnels_.size());
      if (command_id >= kFirstTunnelOpenMenuId &&
          command_id < kFirstTunnelOpenMenuId + tunnel_count) {
        const auto index = command_id - kFirstTunnelOpenMenuId;
        RestoreFromTray();
        InvokeFlutterMethod(
            "statusBarOpenTunnel",
            std::make_unique<flutter::EncodableValue>(tray_tunnels_[index].id));
        return 0;
      }
      if (command_id >= kFirstTunnelActionMenuId &&
          command_id < kFirstTunnelActionMenuId + tunnel_count) {
        const auto index = command_id - kFirstTunnelActionMenuId;
        InvokeFlutterMethod(
            "statusBarToggleTunnel",
            std::make_unique<flutter::EncodableValue>(tray_tunnels_[index].id));
        return 0;
      }
      if (command_id == kOpenProgramMenuId) {
        RestoreFromTray();
        return 0;
      }
      if (command_id == kStopAllTunnelsMenuId) {
        InvokeFlutterMethod("statusBarStopAll", nullptr);
        return 0;
      }
      if (command_id == kQuitMenuId) {
        QuitFromTray();
        return 0;
      }
      break;
    }

    case kTrayCallbackMessage:
      if (lparam == WM_LBUTTONUP) {
        RestoreFromTray();
      } else if (lparam == WM_RBUTTONUP || lparam == WM_CONTEXTMENU) {
        ShowTrayMenu();
      }
      return 0;

    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

void FlutterWindow::InitializeTray() {
  if (tray_initialized_) {
    return;
  }

  HWND hwnd = GetHandle();
  if (hwnd == nullptr) {
    return;
  }

  tray_icon_data_ = {};
  tray_icon_data_.cbSize = sizeof(NOTIFYICONDATA);
  tray_icon_data_.hWnd = hwnd;
  tray_icon_data_.uID = 1;
  tray_icon_data_.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
  tray_icon_data_.uCallbackMessage = kTrayCallbackMessage;
  tray_icon_data_.hIcon =
      LoadIcon(GetModuleHandle(nullptr), MAKEINTRESOURCE(IDI_TRAY_ICON));
  wcscpy_s(tray_icon_data_.szTip, L"TU Client");

  tray_initialized_ = Shell_NotifyIcon(NIM_ADD, &tray_icon_data_) == TRUE;
  if (tray_initialized_) {
    tray_icon_data_.uVersion = NOTIFYICON_VERSION_4;
    Shell_NotifyIcon(NIM_SETVERSION, &tray_icon_data_);
  }
}

void FlutterWindow::RemoveTray() {
  if (!tray_initialized_) {
    return;
  }

  Shell_NotifyIcon(NIM_DELETE, &tray_icon_data_);
  tray_initialized_ = false;
}

void FlutterWindow::RestoreFromTray() {
  HWND hwnd = GetHandle();
  if (hwnd == nullptr) {
    return;
  }

  ShowWindow(hwnd, SW_SHOW);
  if (IsIconic(hwnd)) {
    ShowWindow(hwnd, SW_RESTORE);
  }
  SetForegroundWindow(hwnd);
  SetFocus(hwnd);
}

void FlutterWindow::HideToTray() {
  InitializeTray();
  HWND hwnd = GetHandle();
  if (hwnd != nullptr) {
    ShowWindow(hwnd, SW_HIDE);
  }
}

void FlutterWindow::QuitFromTray() {
  force_quit_ = true;
  HWND hwnd = GetHandle();
  if (hwnd != nullptr) {
    DestroyWindow(hwnd);
  }
}

void FlutterWindow::ShowTrayMenu() {
  HWND hwnd = GetHandle();
  if (hwnd == nullptr) {
    return;
  }

  HMENU menu = CreatePopupMenu();
  if (menu == nullptr) {
    return;
  }

  if (tray_tunnels_.empty()) {
    AppendMenu(menu, MF_STRING | MF_DISABLED, 0, L"Нет сохранённых тоннелей");
  } else {
    for (size_t i = 0; i < tray_tunnels_.size(); ++i) {
      AppendMenu(menu, MF_STRING, kFirstTunnelOpenMenuId + i,
                 tray_tunnels_[i].title.c_str());
      AppendMenu(menu,
                 MF_STRING | (tray_tunnels_[i].starting ? MF_DISABLED : MF_ENABLED),
                 kFirstTunnelActionMenuId + i,
                 tray_tunnels_[i].action_title.c_str());
    }
  }

  AppendMenu(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenu(menu, MF_STRING, kOpenProgramMenuId, L"Открыть программу");
  AppendMenu(menu,
             MF_STRING | (has_running_tunnels_ ? MF_ENABLED : MF_DISABLED),
             kStopAllTunnelsMenuId, L"Остановить все тоннели");
  AppendMenu(menu, MF_SEPARATOR, 0, nullptr);
  AppendMenu(menu, MF_STRING, kQuitMenuId, L"Закрыть TU client");

  POINT cursor_position;
  GetCursorPos(&cursor_position);
  SetForegroundWindow(hwnd);
  TrackPopupMenu(menu, TPM_RIGHTBUTTON | TPM_BOTTOMALIGN | TPM_LEFTALIGN,
                 cursor_position.x, cursor_position.y, 0, hwnd, nullptr);
  PostMessage(hwnd, WM_NULL, 0, 0);
  DestroyMenu(menu);
}

void FlutterWindow::UpdateTrayMenu(const flutter::EncodableValue* arguments) {
  tray_tunnels_.clear();
  has_running_tunnels_ = false;

  if (arguments == nullptr) {
    return;
  }

  const auto* args = std::get_if<flutter::EncodableMap>(arguments);
  if (args == nullptr) {
    return;
  }

  has_running_tunnels_ = BoolFromMap(*args, "hasRunningTunnels");
  auto tunnels_it = args->find(flutter::EncodableValue("tunnels"));
  if (tunnels_it == args->end()) {
    return;
  }

  const auto* tunnels = std::get_if<flutter::EncodableList>(&tunnels_it->second);
  if (tunnels == nullptr) {
    return;
  }

  for (const auto& item : *tunnels) {
    const auto* tunnel = std::get_if<flutter::EncodableMap>(&item);
    if (tunnel == nullptr) {
      continue;
    }

    const auto id = StringFromMap(*tunnel, "id");
    if (id.empty()) {
      continue;
    }

    const auto name = WStringFromMap(*tunnel, "name", L"Тоннель");
    const auto type = WStringFromMap(*tunnel, "type");
    const auto port = IntFromMap(*tunnel, "localPort");
    const auto running = BoolFromMap(*tunnel, "running");
    const auto status = StringFromMap(*tunnel, "status");
    const auto starting = status == "starting";
    const auto status_icon = starting ? L"◌" : (running ? L"■" : L"▶");
    const auto action = starting
        ? L"  ◌ Запускается..."
        : (running ? L"  ■ Остановить" : L"  ▶ Запустить");

    std::wstringstream title;
    title << status_icon << L" " << name << L" (" << type << L" " << port << L")";
    tray_tunnels_.push_back({id, title.str(), action, starting});
  }
}

void FlutterWindow::InvokeFlutterMethod(
    const std::string& method,
    std::unique_ptr<flutter::EncodableValue> arguments) {
  if (!tray_channel_) {
    return;
  }

  tray_channel_->InvokeMethod(method, std::move(arguments));
}
