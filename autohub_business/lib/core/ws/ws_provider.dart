import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'ws_client.dart';

final wsClientProvider = Provider<WsClient>((ref) {
  final client = WsClient();
  ref.onDispose(() => client.dispose());
  return client;
});
