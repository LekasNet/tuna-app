#include "flutter_window.h"

#include <flutter/standard_method_codec.h>
#include <shellapi.h>
#include <windowsx.h>

#include <algorithm>
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
constexpr wchar_t kTrayMenuWindowClassName[] = L"TU_CLIENT_TRAY_MENU_WINDOW";
constexpr int kTrayMenuWidth = 640;
constexpr int kTunnelRowHeight = 108;
constexpr int kCommandRowHeight = 68;
constexpr int kMenuPadding = 16;
constexpr int kMenuRadius = 24;
constexpr int kRowRadius = 16;
constexpr int kActionButtonSize = 60;
constexpr int kActionButtonRight = 36;

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

bool IsWindowsLightTheme() {
  DWORD value = 1;
  DWORD value_size = sizeof(value);
  const auto status = RegGetValue(
      HKEY_CURRENT_USER,
      L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
      L"AppsUseLightTheme", RRF_RT_REG_DWORD, nullptr, &value, &value_size);
  return status != ERROR_SUCCESS || value != 0;
}

COLORREF Rgb(int red, int green, int blue) {
  return RGB(red, green, blue);
}

std::wstring StripProtocol(const std::wstring& url) {
  constexpr wchar_t https[] = L"https://";
  constexpr wchar_t http[] = L"http://";
  if (url.rfind(https, 0) == 0) {
    return url.substr(wcslen(https));
  }
  if (url.rfind(http, 0) == 0) {
    return url.substr(wcslen(http));
  }
  return url;
}

void FillRectColor(HDC hdc, const RECT& rect, COLORREF color) {
  HBRUSH brush = CreateSolidBrush(color);
  FillRect(hdc, &rect, brush);
  DeleteObject(brush);
}

void DrawRoundRect(HDC hdc,
                   const RECT& rect,
                   COLORREF fill,
                   COLORREF stroke,
                   int radius) {
  HBRUSH brush = CreateSolidBrush(fill);
  HPEN pen = CreatePen(PS_SOLID, 1, stroke);
  auto old_brush = SelectObject(hdc, brush);
  auto old_pen = SelectObject(hdc, pen);
  RoundRect(hdc, rect.left, rect.top, rect.right, rect.bottom, radius, radius);
  SelectObject(hdc, old_pen);
  SelectObject(hdc, old_brush);
  DeleteObject(pen);
  DeleteObject(brush);
}

HFONT CreateMenuFont(int size, int weight) {
  return CreateFontW(-size, 0, 0, 0, weight, FALSE, FALSE, FALSE,
                     DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
                     CLEARTYPE_QUALITY, DEFAULT_PITCH | FF_DONTCARE,
                     L"Segoe UI");
}

int TrayMenuHeight(size_t tunnel_count) {
  const auto rows = tunnel_count == 0 ? 1 : tunnel_count;
  return kMenuPadding * 2 + static_cast<int>(rows) * kTunnelRowHeight + 1 +
         kCommandRowHeight * 3;
}

ATOM RegisterTrayMenuWindowClass() {
  static ATOM atom = 0;
  if (atom != 0) {
    return atom;
  }

  WNDCLASS window_class{};
  window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
  window_class.lpszClassName = kTrayMenuWindowClassName;
  window_class.hInstance = GetModuleHandle(nullptr);
  window_class.hbrBackground = nullptr;
  window_class.lpfnWndProc = FlutterWindow::TrayMenuWndProc;
  atom = RegisterClass(&window_class);
  return atom;
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
  HideTrayMenu();
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

  if (message == kTrayCallbackMessage) {
    if (LOWORD(lparam) == WM_LBUTTONUP || LOWORD(lparam) == NIN_SELECT ||
        LOWORD(lparam) == NIN_KEYSELECT) {
      RestoreFromTray();
    } else if (LOWORD(lparam) == WM_RBUTTONUP ||
               LOWORD(lparam) == WM_CONTEXTMENU) {
      ShowTrayMenu();
    }
    return 0;
  }

  if (message == WM_COMMAND) {
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
  }

  if (message == WM_SETTINGCHANGE) {
    UpdateTrayIcon();
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
  tray_icon_data_.hIcon = LoadIcon(
      GetModuleHandle(nullptr),
      MAKEINTRESOURCE(IsWindowsLightTheme() ? IDI_TRAY_ICON
                                            : IDI_TRAY_ICON_LIGHT));
  wcscpy_s(tray_icon_data_.szTip, L"TU Client");

  tray_initialized_ = Shell_NotifyIcon(NIM_ADD, &tray_icon_data_) == TRUE;
  if (tray_initialized_) {
    tray_icon_data_.uVersion = NOTIFYICON_VERSION_4;
    Shell_NotifyIcon(NIM_SETVERSION, &tray_icon_data_);
  }
}

void FlutterWindow::UpdateTrayIcon() {
  if (!tray_initialized_) {
    return;
  }

  tray_icon_data_.uFlags = NIF_ICON | NIF_TIP;
  tray_icon_data_.hIcon = LoadIcon(
      GetModuleHandle(nullptr),
      MAKEINTRESOURCE(IsWindowsLightTheme() ? IDI_TRAY_ICON
                                            : IDI_TRAY_ICON_LIGHT));
  wcscpy_s(tray_icon_data_.szTip, L"TU Client");
  Shell_NotifyIcon(NIM_MODIFY, &tray_icon_data_);
}

void FlutterWindow::RemoveTray() {
  if (!tray_initialized_) {
    return;
  }

  Shell_NotifyIcon(NIM_DELETE, &tray_icon_data_);
  tray_initialized_ = false;
}

void FlutterWindow::RestoreFromTray() {
  HideTrayMenu();
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
  HideTrayMenu();
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

  if (RegisterTrayMenuWindowClass() == 0) {
    return;
  }

  const int menu_height = TrayMenuHeight(tray_tunnels_.size());
  if (tray_menu_window_ == nullptr) {
    tray_menu_window_ = CreateWindowEx(
        WS_EX_TOPMOST | WS_EX_TOOLWINDOW, kTrayMenuWindowClassName, L"",
        WS_POPUP | WS_CLIPCHILDREN, 0, 0, kTrayMenuWidth, menu_height, hwnd,
        nullptr, GetModuleHandle(nullptr), this);
    if (tray_menu_window_ == nullptr) {
      return;
    }
  }

  POINT cursor_position;
  GetCursorPos(&cursor_position);
  HMONITOR monitor = MonitorFromPoint(cursor_position, MONITOR_DEFAULTTONEAREST);
  MONITORINFO monitor_info{};
  monitor_info.cbSize = sizeof(MONITORINFO);
  GetMonitorInfo(monitor, &monitor_info);

  int x = cursor_position.x - kTrayMenuWidth + 36;
  int y = cursor_position.y - menu_height - 16;
  const int min_x = static_cast<int>(monitor_info.rcWork.left) + 8;
  const int max_x =
      static_cast<int>(monitor_info.rcWork.right) - kTrayMenuWidth - 8;
  x = std::max(min_x, std::min(x, max_x));
  if (y < static_cast<int>(monitor_info.rcWork.top)) {
    y = cursor_position.y + 16;
  }

  SetWindowPos(tray_menu_window_, HWND_TOPMOST, x, y, kTrayMenuWidth,
               menu_height, SWP_SHOWWINDOW);
  SetForegroundWindow(tray_menu_window_);
  ClearTrayMenuHover();
  InvalidateRect(tray_menu_window_, nullptr, TRUE);
}

void FlutterWindow::HideTrayMenu() {
  if (tray_menu_window_ != nullptr) {
    DestroyWindow(tray_menu_window_);
    tray_menu_window_ = nullptr;
  }
  ClearTrayMenuHover();
}

void FlutterWindow::PaintTrayMenu(HWND hwnd) {
  PAINTSTRUCT paint;
  HDC hdc = BeginPaint(hwnd, &paint);

  RECT client;
  GetClientRect(hwnd, &client);
  FillRectColor(hdc, client, Rgb(249, 250, 252));
  DrawRoundRect(hdc, client, Rgb(249, 250, 252), Rgb(210, 216, 224),
                kMenuRadius);

  SetBkMode(hdc, TRANSPARENT);

  HFONT title_font = CreateMenuFont(30, FW_SEMIBOLD);
  HFONT subtitle_font = CreateMenuFont(24, FW_NORMAL);
  HFONT command_font = CreateMenuFont(28, FW_NORMAL);
  HFONT icon_font = CreateMenuFont(34, FW_SEMIBOLD);

  int y = kMenuPadding;
  if (tray_tunnels_.empty()) {
    RECT empty_rect = {32, y + 28, kTrayMenuWidth - 32, y + 72};
    SetTextColor(hdc, Rgb(104, 113, 123));
    auto old_font = SelectObject(hdc, command_font);
    DrawText(hdc, L"Нет сохранённых тоннелей", -1, &empty_rect,
             DT_SINGLELINE | DT_VCENTER | DT_LEFT | DT_END_ELLIPSIS);
    SelectObject(hdc, old_font);
    y += kTunnelRowHeight;
  } else {
    for (size_t index = 0; index < tray_tunnels_.size(); ++index) {
      const auto& tunnel = tray_tunnels_[index];
      const bool row_hover =
          tray_hover_tunnel_index_ == static_cast<int>(index);
      RECT row = {16, y, kTrayMenuWidth - 16, y + kTunnelRowHeight};
      DrawRoundRect(hdc, row, row_hover ? Rgb(239, 244, 249)
                                        : Rgb(249, 250, 252),
                    row_hover ? Rgb(224, 231, 239) : Rgb(249, 250, 252),
                    kRowRadius);

      RECT title_rect = {36, y + 16, kTrayMenuWidth - 146, y + 54};
      SetTextColor(hdc, Rgb(24, 30, 36));
      auto old_font = SelectObject(hdc, title_font);
      DrawText(hdc, tunnel.name.c_str(), -1, &title_rect,
               DT_SINGLELINE | DT_LEFT | DT_END_ELLIPSIS);

      RECT subtitle_rect = {36, y + 58, kTrayMenuWidth - 146, y + 94};
      SelectObject(hdc, subtitle_font);
      SetTextColor(hdc, tunnel.running ? Rgb(35, 117, 211)
                                       : Rgb(104, 113, 123));
      DrawText(hdc, tunnel.subtitle.c_str(), -1, &subtitle_rect,
               DT_SINGLELINE | DT_LEFT | DT_END_ELLIPSIS);
      SelectObject(hdc, old_font);

      RECT action_rect = {kTrayMenuWidth - kActionButtonRight -
                              kActionButtonSize,
                          y + 24, kTrayMenuWidth - kActionButtonRight, y + 84};
      if (tunnel.starting) {
        HPEN pen = CreatePen(PS_SOLID, 4, Rgb(65, 135, 225));
        auto old_pen = SelectObject(hdc, pen);
        Arc(hdc, action_rect.left + 12, action_rect.top + 12,
            action_rect.right - 12, action_rect.bottom - 12,
            action_rect.right - 14, action_rect.top + 18,
            action_rect.left + 22, action_rect.bottom - 14);
        SelectObject(hdc, old_pen);
        DeleteObject(pen);
      } else {
        const bool action_hover = row_hover && tray_hover_action_;
        DrawRoundRect(hdc, action_rect, action_hover ? Rgb(226, 234, 242)
                                                     : Rgb(239, 243, 247),
                      action_hover ? Rgb(204, 214, 225)
                                   : Rgb(222, 228, 235),
                      kActionButtonSize);
        auto old_icon_font = SelectObject(hdc, icon_font);
        SetTextColor(hdc, tunnel.running ? Rgb(200, 58, 70)
                                         : Rgb(40, 149, 92));
        DrawText(hdc, tunnel.running ? L"■" : L"▶", -1, &action_rect,
                 DT_SINGLELINE | DT_CENTER | DT_VCENTER);
        SelectObject(hdc, old_icon_font);
      }

      y += kTunnelRowHeight;
    }
  }

  RECT separator = {24, y, kTrayMenuWidth - 24, y + 1};
  FillRectColor(hdc, separator, Rgb(224, 229, 236));
  y += 1;

  const struct CommandRow {
    const wchar_t* title;
    bool enabled;
  } commands[] = {
      {L"Открыть программу", true},
      {L"Остановить все тоннели", has_running_tunnels_},
      {L"Закрыть TU client", true},
  };

  for (int index = 0; index < 3; ++index) {
    const auto& command = commands[index];
    const bool command_hover = tray_hover_command_index_ == index;
    RECT row = {16, y + 4, kTrayMenuWidth - 16, y + kCommandRowHeight - 4};
    if (command.enabled && command_hover) {
      DrawRoundRect(hdc, row, Rgb(239, 244, 249), Rgb(239, 244, 249),
                    kRowRadius);
    }
    RECT text = {36, y, kTrayMenuWidth - 36, y + kCommandRowHeight};
    SetTextColor(hdc, command.enabled ? Rgb(35, 42, 50) : Rgb(155, 164, 174));
    auto old_font = SelectObject(hdc, command_font);
    DrawText(hdc, command.title, -1, &text,
             DT_SINGLELINE | DT_LEFT | DT_VCENTER | DT_END_ELLIPSIS);
    SelectObject(hdc, old_font);
    y += kCommandRowHeight;
  }

  DeleteObject(title_font);
  DeleteObject(subtitle_font);
  DeleteObject(command_font);
  DeleteObject(icon_font);
  EndPaint(hwnd, &paint);
}

void FlutterWindow::HandleTrayMenuClick(int x, int y) {
  const auto tunnel_count = tray_tunnels_.empty() ? 1 : tray_tunnels_.size();
  const int tunnels_top = kMenuPadding;
  const int tunnels_bottom =
      tunnels_top + static_cast<int>(tunnel_count) * kTunnelRowHeight;

  if (!tray_tunnels_.empty() && y >= tunnels_top && y < tunnels_bottom) {
    const auto index = static_cast<size_t>((y - tunnels_top) / kTunnelRowHeight);
    if (index >= tray_tunnels_.size()) {
      return;
    }

    if (x >= kTrayMenuWidth - kActionButtonRight - kActionButtonSize - 12) {
      if (!tray_tunnels_[index].starting) {
        InvokeFlutterMethod(
            "statusBarToggleTunnel",
            std::make_unique<flutter::EncodableValue>(tray_tunnels_[index].id));
      }
    } else {
      RestoreFromTray();
      InvokeFlutterMethod(
          "statusBarOpenTunnel",
          std::make_unique<flutter::EncodableValue>(tray_tunnels_[index].id));
      HideTrayMenu();
    }
    return;
  }

  const int commands_top = tunnels_bottom + 1;
  if (y < commands_top) {
    return;
  }

  const int command_index = (y - commands_top) / kCommandRowHeight;
  if (command_index == 0) {
    RestoreFromTray();
    HideTrayMenu();
  } else if (command_index == 1) {
    if (has_running_tunnels_) {
      InvokeFlutterMethod("statusBarStopAll", nullptr);
    }
  } else if (command_index == 2) {
    QuitFromTray();
  }
}

void FlutterWindow::UpdateTrayMenuHover(int x, int y) {
  if (tray_menu_window_ == nullptr) {
    return;
  }

  const int previous_tunnel_index = tray_hover_tunnel_index_;
  const int previous_command_index = tray_hover_command_index_;
  const bool previous_action = tray_hover_action_;

  tray_hover_tunnel_index_ = -1;
  tray_hover_command_index_ = -1;
  tray_hover_action_ = false;

  const auto tunnel_count = tray_tunnels_.empty() ? 1 : tray_tunnels_.size();
  const int tunnels_top = kMenuPadding;
  const int tunnels_bottom =
      tunnels_top + static_cast<int>(tunnel_count) * kTunnelRowHeight;

  if (!tray_tunnels_.empty() && y >= tunnels_top && y < tunnels_bottom) {
    const auto index = static_cast<int>((y - tunnels_top) / kTunnelRowHeight);
    if (index >= 0 && index < static_cast<int>(tray_tunnels_.size())) {
      tray_hover_tunnel_index_ = index;
      tray_hover_action_ =
          x >= kTrayMenuWidth - kActionButtonRight - kActionButtonSize - 12;
    }
  } else {
    const int commands_top = tunnels_bottom + 1;
    if (y >= commands_top) {
      const int command_index = (y - commands_top) / kCommandRowHeight;
      if (command_index >= 0 && command_index < 3) {
        tray_hover_command_index_ = command_index;
      }
    }
  }

  if (previous_tunnel_index != tray_hover_tunnel_index_ ||
      previous_command_index != tray_hover_command_index_ ||
      previous_action != tray_hover_action_) {
    InvalidateRect(tray_menu_window_, nullptr, TRUE);
  }
}

void FlutterWindow::ClearTrayMenuHover() {
  tray_hover_tunnel_index_ = -1;
  tray_hover_command_index_ = -1;
  tray_hover_action_ = false;
  tray_menu_tracking_mouse_ = false;
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
    const auto local_address = WStringFromMap(*tunnel, "localAddress");
    const auto public_url = WStringFromMap(*tunnel, "publicUrl");

    std::wstringstream fallback_address;
    fallback_address << type << L" " << port;
    const auto subtitle = running && !public_url.empty()
                              ? StripProtocol(public_url)
                              : (local_address.empty() ? fallback_address.str()
                                                       : local_address);

    tray_tunnels_.push_back({id, name, subtitle, running, starting});
  }

  if (tray_menu_window_ != nullptr) {
    SetWindowPos(tray_menu_window_, HWND_TOPMOST, 0, 0, kTrayMenuWidth,
                 TrayMenuHeight(tray_tunnels_.size()),
                 SWP_NOMOVE | SWP_NOACTIVATE);
    InvalidateRect(tray_menu_window_, nullptr, TRUE);
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

LRESULT CALLBACK FlutterWindow::TrayMenuWndProc(HWND hwnd,
                                                UINT message,
                                                WPARAM wparam,
                                                LPARAM lparam) {
  auto* window =
      reinterpret_cast<FlutterWindow*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));

  if (message == WM_NCCREATE) {
    const auto* create_struct = reinterpret_cast<CREATESTRUCT*>(lparam);
    SetWindowLongPtr(hwnd, GWLP_USERDATA,
                     reinterpret_cast<LONG_PTR>(create_struct->lpCreateParams));
    return TRUE;
  }

  switch (message) {
    case WM_PAINT:
      if (window != nullptr) {
        window->PaintTrayMenu(hwnd);
        return 0;
      }
      break;
    case WM_MOUSEMOVE:
      if (window != nullptr) {
        if (!window->tray_menu_tracking_mouse_) {
          TRACKMOUSEEVENT event{};
          event.cbSize = sizeof(TRACKMOUSEEVENT);
          event.dwFlags = TME_LEAVE;
          event.hwndTrack = hwnd;
          TrackMouseEvent(&event);
          window->tray_menu_tracking_mouse_ = true;
        }
        window->UpdateTrayMenuHover(GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam));
        return 0;
      }
      break;
    case WM_MOUSELEAVE:
      if (window != nullptr) {
        window->ClearTrayMenuHover();
        InvalidateRect(hwnd, nullptr, TRUE);
        return 0;
      }
      break;
    case WM_LBUTTONUP:
      if (window != nullptr) {
        window->HandleTrayMenuClick(GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam));
        return 0;
      }
      break;
    case WM_ACTIVATE:
      if (LOWORD(wparam) == WA_INACTIVE && window != nullptr) {
        window->HideTrayMenu();
        return 0;
      }
      break;
    case WM_KILLFOCUS:
      if (window != nullptr) {
        window->HideTrayMenu();
        return 0;
      }
      break;
    case WM_KEYDOWN:
      if (wparam == VK_ESCAPE && window != nullptr) {
        window->HideTrayMenu();
        return 0;
      }
      break;
    case WM_DESTROY:
      if (window != nullptr && window->tray_menu_window_ == hwnd) {
        window->tray_menu_window_ = nullptr;
      }
      break;
  }

  return DefWindowProc(hwnd, message, wparam, lparam);
}
