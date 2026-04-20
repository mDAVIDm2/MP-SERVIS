import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/repositories/staff_repository.dart';

/// Число входящих приглашений (для бейджей в профиле и настройках аккаунта).
final pendingInvitationsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final r = await ref.read(staffRepositoryProvider.notifier).getIncomingInvitations();
  final list = r.dataOrNull;
  if (list == null) return 0;
  return list.length;
});
