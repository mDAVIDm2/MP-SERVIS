import 'dart:async';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';

/// Текст, который при переполнении прокручивается по горизонтали (маркер):
/// полный оборот → пауза 3 сек → повтор.
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int pauseSeconds;

  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.pauseSeconds = 3,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  final ScrollController _scrollController = ScrollController();
  bool _needsMarquee = false;
  double _contentWidth = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleCheck());
  }

  void _scheduleCheck() {
    if (!mounted) return;
    _checkOverflow();
  }

  void _checkOverflow() {
    if (!mounted || context.size == null) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final maxW = box.size.width;
    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style ?? const TextStyle(fontSize: 16, color: Colors.white)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: double.infinity);
    final textW = textPainter.width;
    if (textW > maxW && maxW > 0) {
      if (!_needsMarquee || _contentWidth != textW) {
        setState(() {
          _needsMarquee = true;
          _contentWidth = textW;
        });
        _startMarquee();
      }
    } else {
      if (_needsMarquee) {
        _timer?.cancel();
        setState(() => _needsMarquee = false);
      }
    }
  }

  void _startMarquee() {
    _timer?.cancel();
    void run() {
      if (!mounted || _scrollController.hasClients == false) return;
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) return;
      const step = 1.5;
      const period = Duration(milliseconds: 30);
      _timer = Timer.periodic(period, (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        final pos = _scrollController.offset + step;
        if (pos >= maxScroll) {
          t.cancel();
          _scrollController.jumpTo(0);
          _timer = Timer(Duration(seconds: widget.pauseSeconds), () {
            if (mounted) run();
          });
          return;
        }
        _scrollController.jumpTo(pos.clamp(0.0, maxScroll));
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => run());
  }

  @override
  void didUpdateWidget(MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_needsMarquee && _contentWidth > 0) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            width: constraints.maxWidth,
            height: 24,
            child: ListView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                SizedBox(
                  width: _contentWidth,
                  child: Text(
                    widget.text,
                    style: widget.style,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth),
          child: Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}
