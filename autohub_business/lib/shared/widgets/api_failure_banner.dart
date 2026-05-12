import 'package:flutter/material.dart';
import '../../core/config/app_config.dart';

/// Баннер: API недоступен — пояснение и кнопка повтора.
class ApiFailureBanner extends StatelessWidget {
  const ApiFailureBanner({
    super.key,
    required this.message,
    required this.onRetry,
    this.dense = false,
  });

  final String message;
  final VoidCallback onRetry;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFF4E5),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: dense ? 12 : 16, vertical: dense ? 8 : 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.cloud_off_rounded, color: Colors.orange.shade800, size: dense ? 20 : 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: dense ? 12 : 13,
                      height: 1.35,
                      color: Colors.brown.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    'API: ${AppConfig.baseUrl}',
                    style: TextStyle(fontSize: dense ? 10 : 11, color: Colors.brown.shade700),
                  ),
                  Text(
                    'Проверьте, что бэкенд запущен, порт открыт в брандмауэре Windows и при сборке указаны верные хост/порт: '
                    '--dart-define=MP_SERVIS_API_HOST=… --dart-define=MP_SERVIS_API_PORT=3001',
                    style: TextStyle(fontSize: dense ? 10 : 11, color: Colors.brown.shade700, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh_rounded, size: dense ? 18 : 20),
              label: Text(dense ? 'Ещё раз' : 'Повторить'),
              style: TextButton.styleFrom(foregroundColor: Colors.orange.shade900),
            ),
          ],
        ),
      ),
    );
  }
}
