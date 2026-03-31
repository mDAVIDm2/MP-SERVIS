// Создаёт JSON для `flutter run --dart-define-from-file=...` из google-services.json
// (скачивается в Firebase Console → настройки проекта → ваше Android-приложение).
//
// Имя пакета Android берётся из Flutter-проекта: android/app/build.gradle.kts → applicationId
// (должно совпадать с полем package_name в JSON и с приложением в Firebase).
//
// Запуск из каталога autohub_client2:
//   dart run tool/google_services_to_dart_define.dart android/app/google-services.json
//
// По умолчанию пишет в config/firebase_define.json
//
// SHA-1 для FCM обычно не нужен; добавляйте в Firebase при Google Sign-In / Auth.

import 'dart:convert';
import 'dart:io';

/// `applicationId` из [gradleKts] или null.
String? readApplicationIdFromGradleFile(File gradleKts) {
  if (!gradleKts.existsSync()) return null;
  final text = gradleKts.readAsStringSync();
  final re = RegExp(r'''applicationId\s*=\s*["']([^"']+)["']''');
  return re.firstMatch(text)?.group(1);
}

File _resolveAndroidAppGradle() {
  final toolFile = File.fromUri(Platform.script);
  final projectRoot = toolFile.parent.parent;
  final fromPackage = File('${projectRoot.path}/android/app/build.gradle.kts');
  if (fromPackage.existsSync()) return fromPackage;
  final fromCwd = File('${Directory.current.path}/android/app/build.gradle.kts');
  if (fromCwd.existsSync()) return fromCwd;
  return fromPackage;
}

void main(List<String> args) {
  if (args.isEmpty || args[0] == '-h' || args[0] == '--help') {
    stderr.writeln(
      'Использование: dart run tool/google_services_to_dart_define.dart '
      '<android/app/google-services.json> [выходной.json]\n'
      'По умолчанию выход: config/firebase_define.json\n'
      'Пакет Android читается из android/app/build.gradle.kts → applicationId.',
    );
    exitCode = args.isEmpty ? 64 : 0;
    return;
  }

  final gradle = _resolveAndroidAppGradle();
  final packageName = readApplicationIdFromGradleFile(gradle);
  if (packageName == null || packageName.isEmpty) {
    stderr.writeln(
      'Не удалось прочитать applicationId из ${gradle.path}\n'
      'Убедитесь, что в android/app/build.gradle.kts есть строка вида: applicationId = "..."',
    );
    exitCode = 1;
    return;
  }
  stdout.writeln('Пакет Android (из Flutter-проекта): $packageName');

  final input = File(args[0]);
  if (!input.existsSync()) {
    stderr.writeln('Файл не найден: ${input.path}');
    exitCode = 1;
    return;
  }

  final outPath = args.length > 1 ? args[1] : 'config/firebase_define.json';
  final outFile = File(outPath);

  final map = jsonDecode(input.readAsStringSync()) as Map<String, dynamic>;
  final projectInfo = map['project_info'] as Map<String, dynamic>?;
  if (projectInfo == null) {
    stderr.writeln('Некорректный google-services.json: нет project_info');
    exitCode = 1;
    return;
  }

  final clients = map['client'] as List<dynamic>?;
  if (clients == null || clients.isEmpty) {
    stderr.writeln('Некорректный google-services.json: нет client[]');
    exitCode = 1;
    return;
  }

  Map<String, dynamic>? picked;
  for (final c in clients) {
    if (c is! Map<String, dynamic>) continue;
    final ci = c['client_info'] as Map<String, dynamic>?;
    final android = ci?['android_client_info'] as Map<String, dynamic>?;
    final name = android?['package_name'] as String?;
    if (name == packageName) {
      picked = c;
      break;
    }
  }

  if (picked == null) {
    stderr.writeln(
      'В google-services.json нет приложения с package_name="$packageName".\n'
      'В Firebase Console добавьте Android-приложение с package name, совпадающим с '
      'applicationId в android/app/build.gradle.kts, и скачайте json заново.\n'
      '(App nickname в консоли — любое имя; SHA-1 для FCM обычно не обязателен.)',
    );
    exitCode = 1;
    return;
  }

  final clientInfo = picked['client_info'] as Map<String, dynamic>?;
  final appId = clientInfo?['mobilesdk_app_id'] as String?;
  final apiKeys = picked['api_key'] as List<dynamic>?;
  final currentKey = (apiKeys != null && apiKeys.isNotEmpty)
      ? (apiKeys.first as Map<String, dynamic>)['current_key'] as String?
      : null;

  if (appId == null || appId.isEmpty || currentKey == null || currentKey.isEmpty) {
    stderr.writeln('В выбранном клиенте нет mobilesdk_app_id или api_key');
    exitCode = 1;
    return;
  }

  final projectId = projectInfo['project_id'] as String? ?? '';
  final senderId = projectInfo['project_number'] as String? ?? '';
  final bucket = projectInfo['storage_bucket'] as String? ?? '';

  final defines = <String, String>{
    'FIREBASE_API_KEY': currentKey,
    'FIREBASE_APP_ID': appId,
    'FIREBASE_SENDER_ID': senderId,
    'FIREBASE_PROJECT_ID': projectId,
    'FIREBASE_STORAGE_BUCKET': bucket,
  };

  outFile.parent.createSync(recursive: true);
  const encoder = JsonEncoder.withIndent('  ');
  outFile.writeAsStringSync('${encoder.convert(defines)}\n');
  stdout.writeln('Записано: ${outFile.absolute.path}');
  stdout.writeln('Запуск: flutter run --dart-define-from-file=${outFile.path}');
}
