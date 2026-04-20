import '../../shared/models/chat_model.dart';

/// Приоритет URL с заказа (API `client_avatar_url`), иначе поиск в загруженных чатах.
String? resolvedClientAvatarUrl({
  required List<ChatPreview> chats,
  String? orderClientAvatarUrl,
  String? clientPhone,
}) {
  final u = orderClientAvatarUrl?.trim();
  if (u != null && u.isNotEmpty) return u;
  return clientAvatarUrlFromChats(chats, clientPhone);
}

/// Ключ телефона как на бэкенде (`UsersService.clientPhoneMatchKey`) — для сопоставления с `ChatPreview.clientPhone`.
String clientPhoneMatchKeyForAvatar(String raw) {
  final d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.length == 11 && d.startsWith('8')) {
    return '7${d.substring(1)}';
  }
  if (d.length == 10) {
    return '7$d';
  }
  return d;
}

/// URL аватара из уже загруженного списка чатов (поле `client_avatar_url` с API).
String? clientAvatarUrlFromChats(List<ChatPreview> chats, String? clientPhone) {
  final key = clientPhoneMatchKeyForAvatar(clientPhone ?? '');
  if (key.isEmpty) return null;
  for (final c in chats) {
    if (c.isSupportChat) continue;
    final ck = clientPhoneMatchKeyForAvatar(c.clientPhone);
    if (ck != key) continue;
    final u = c.clientAvatarUrl?.trim();
    if (u != null && u.isNotEmpty) return u;
  }
  return null;
}
