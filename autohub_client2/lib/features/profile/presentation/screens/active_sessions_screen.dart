import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/client_palette.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/api/sessions_api_service.dart';

class ActiveSessionsScreen extends ConsumerStatefulWidget {
  const ActiveSessionsScreen({super.key});

  @override
  ConsumerState<ActiveSessionsScreen> createState() => _ActiveSessionsScreenState();
}

class _ActiveSessionsScreenState extends ConsumerState<ActiveSessionsScreen> {
  List<SessionItemDto> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = ref.read(sessionsApiServiceProvider);
    final r = await api.listSessions();
    if (!mounted) return;
    r.when(
      success: (list) => setState(() {
        _items = list;
        _loading = false;
      }),
      failure: (e) => setState(() {
        _error = e.message;
        _loading = false;
      }),
    );
  }

  Future<void> _revoke(SessionItemDto s) async {
    if (s.isCurrent || s.revoked) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.palette.cardBg,
        title: Text('Завершить сессию?', style: TextStyle(color: context.palette.textPrimary)),
        content: Text(
          'Устройство выйдет из аккаунта на этом сеансе.',
          style: TextStyle(color: context.palette.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Завершить', style: TextStyle(color: context.palette.error)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final r = await ref.read(sessionsApiServiceProvider).revokeSession(s.id);
    if (!mounted) return;
    r.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Сессия завершена'), backgroundColor: context.palette.success),
        );
        _load();
      },
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: context.palette.error),
      ),
    );
  }

  Future<void> _revokeOthers() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.palette.cardBg,
        title: Text('Завершить другие сессии?', style: TextStyle(color: context.palette.textPrimary)),
        content: Text(
          'Выйдут все устройства, кроме этого.',
          style: TextStyle(color: context.palette.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Завершить', style: TextStyle(color: context.palette.error)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final r = await ref.read(sessionsApiServiceProvider).revokeOthers();
    if (!mounted) return;
    r.when(
      success: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Другие сессии завершены'), backgroundColor: context.palette.success),
        );
        _load();
      },
      failure: (e) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: context.palette.error),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.background,
        title: Text('Активные сессии', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
      ),
      body: RefreshIndicator(
        color: context.palette.primary,
        onRefresh: _load,
        child: _loading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 120),
                  Center(child: CircularProgressIndicator(color: context.palette.primary)),
                ],
              )
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(_error!, style: TextStyle(color: context.palette.error)),
                      TextButton(onPressed: _load, child: Text('Повторить')),
                    ],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                      if (_items.where((e) => !e.isCurrent && !e.revoked).length > 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: OutlinedButton(
                            onPressed: _revokeOthers,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: context.palette.error,
                              side: BorderSide(color: context.palette.error),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text('Завершить все, кроме текущей'),
                          ),
                        ),
                      ..._items.map((s) => _SessionTile(session: s, onRevoke: () => _revoke(s))),
                    ],
                  ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session, required this.onRevoke});

  final SessionItemDto session;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final title = session.deviceName?.trim().isNotEmpty == true
        ? session.deviceName!
        : (session.platform ?? 'Устройство');
    final sub = [
      if (session.platform != null && session.platform!.isNotEmpty) session.platform,
      if (session.createdAt != null) _shortDate(session.createdAt!),
      if (session.revoked) 'Отозвана',
      if (session.isCurrent) 'Текущая',
    ].whereType<String>().join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.palette.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.border),
      ),
      child: ListTile(
        title: Text(title, style: TextStyle(color: context.palette.textPrimary, fontWeight: FontWeight.w600)),
        subtitle: Text(sub, style: TextStyle(color: context.palette.textSecondary, fontSize: 13)),
        trailing: session.isCurrent || session.revoked
            ? null
            : IconButton(
                icon: Icon(Icons.logout_rounded, color: context.palette.error),
                tooltip: 'Завершить',
                onPressed: onRevoke,
              ),
      ),
    );
  }

  String _shortDate(String iso) {
    try {
      final d = DateTime.tryParse(iso);
      if (d == null) return iso;
      return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    } catch (_) {
      return iso;
    }
  }
}
