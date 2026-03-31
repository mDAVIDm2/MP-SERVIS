import 'dart:io' show Platform;

/// True при запуске на настольных ОС (Windows, macOS, Linux).
bool get isDesktopPlatform =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;
