#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

// 添加计算窗口居中位置的函数
 Win32Window::Point GetCenteredWindowOrigin(int windowWidth, int windowHeight) {
  // 获取屏幕尺寸
  int screenWidth = GetSystemMetrics(SM_CXSCREEN);
  int screenHeight = GetSystemMetrics(SM_CYSCREEN);
  
  // 计算居中位置
  int originX = (screenWidth - windowWidth) / 2;
  int originY = (screenHeight - windowHeight) / 2;
  
  // 确保坐标不为负数
  if (originX < 0) originX = 0;
  if (originY < 0) originY = 0;
  
  return Win32Window::Point(originX, originY);
}

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  HANDLE hMutex = CreateMutex(NULL, FALSE, L"Global\\ayaka");
  if (hMutex == NULL) {
      MessageBox(NULL, L"Failed to create mutex.", L"Error", MB_OK | MB_ICONERROR);
      return EXIT_FAILURE;
   }
                    
   DWORD last_error = GetLastError();
   if (last_error == ERROR_ALREADY_EXISTS) {
       MessageBox(NULL, L"appcation already running", L"Error", MB_OK | MB_ICONERROR);
       CloseHandle(hMutex);
       return EXIT_FAILURE;
   }
  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  // 修改为使用居中显示的位置计算
  Win32Window::Size size(1280, 720);
  Win32Window::Point origin = GetCenteredWindowOrigin(1280, 720);
  if (!window.Create(L"ayaka", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}