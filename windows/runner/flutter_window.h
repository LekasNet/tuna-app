#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>
#include <flutter/encodable_value.h>

#include <memory>
#include <string>
#include <vector>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();
  static LRESULT CALLBACK TrayMenuWndProc(HWND hwnd, UINT message,
                                          WPARAM wparam, LPARAM lparam);

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  struct TrayTunnel {
    std::string id;
    std::wstring name;
    std::wstring subtitle;
    bool running;
    bool starting;
  };

  void InitializeTray();
  void RemoveTray();
  void RestoreFromTray();
  void HideToTray();
  void QuitFromTray();
  void ShowTrayMenu();
  void HideTrayMenu();
  void PaintTrayMenu(HWND hwnd);
  void HandleTrayMenuClick(int x, int y);
  void UpdateTrayMenu(const flutter::EncodableValue* arguments);
  void InvokeFlutterMethod(const std::string& method,
                           std::unique_ptr<flutter::EncodableValue> arguments);

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      tray_channel_;
  NOTIFYICONDATA tray_icon_data_ = {};
  std::vector<TrayTunnel> tray_tunnels_;
  HWND tray_menu_window_ = nullptr;
  bool tray_initialized_ = false;
  bool has_running_tunnels_ = false;
  bool force_quit_ = false;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
