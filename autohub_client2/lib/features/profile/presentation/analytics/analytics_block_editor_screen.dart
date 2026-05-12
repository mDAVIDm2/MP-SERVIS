import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_scope.dart';
import '../../../../core/theme/client_palette.dart';
import 'analytics_dashboard_models.dart';

/// Полноэкранный редактор блока: сверху фильтры, ниже превью; по «Сохранить» возвращает [AnalyticsBlockConfig].
class AnalyticsBlockEditorScreen extends StatefulWidget {
  const AnalyticsBlockEditorScreen({
    super.key,
    required this.initial,
    required this.filtersCard,
    required this.preview,
  });

  final AnalyticsBlockConfig initial;
  final Widget Function(AnalyticsBlockConfig draft, ValueChanged<AnalyticsBlockConfig> onDraftChanged) filtersCard;
  final Widget Function(AnalyticsBlockConfig draft) preview;

  @override
  State<AnalyticsBlockEditorScreen> createState() => _AnalyticsBlockEditorScreenState();
}

class _AnalyticsBlockEditorScreenState extends State<AnalyticsBlockEditorScreen> {
  late AnalyticsBlockConfig _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial.duplicate();
  }

  void _onDraftChanged(AnalyticsBlockConfig next) {
    setState(() => _draft = next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = L10nScope.of(context);
    final p = context.palette;
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        title: Text(l10n.analyticsBlockEditorTitle, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: Icon(Icons.close_rounded, color: p.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                widget.filtersCard(_draft, _onDraftChanged),
                const SizedBox(height: 16),
                Text(
                  l10n.analyticsBlockEditorPreview,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.textSecondary),
                ),
                const SizedBox(height: 10),
                widget.preview(_draft),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _draft),
                style: FilledButton.styleFrom(
                  backgroundColor: p.primary,
                  foregroundColor: p.onAccent,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(l10n.analyticsBlockEditorSave),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
