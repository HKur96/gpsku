import 'package:flutter/material.dart';

/// Interactive horizontal slider widget that requires an intentional drag gesture
/// (drag progress >= 90% of track width) to trigger confirmation for high-risk commands.
///
/// If released before the 90% threshold, it automatically snaps back to the starting point.
class SlideToConfirmWidget extends StatefulWidget {
  final VoidCallback? onConfirmed;
  final String label;
  final String confirmedLabel;
  final Color activeColor;
  final Color backgroundColor;
  final bool enabled;
  final bool isLoading;
  final double height;

  const SlideToConfirmWidget({
    super.key,
    this.onConfirmed,
    this.label = 'Geser untuk Konfirmasi',
    this.confirmedLabel = 'Terkonfirmasi',
    this.activeColor = const Color(0xFFDC2626), // Destructive Red
    this.backgroundColor = const Color(0xFFF1F5F9), // Slate 100
    this.enabled = true,
    this.isLoading = false,
    this.height = 54.0,
  });

  @override
  State<SlideToConfirmWidget> createState() => _SlideToConfirmWidgetState();
}

class _SlideToConfirmWidgetState extends State<SlideToConfirmWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _resetController;
  late Animation<double> _resetAnimation;

  double _dragOffset = 0.0;
  bool _isConfirmed = false;
  static const double _thumbPadding = 4.0;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _resetAnimation =
        Tween<double>(begin: 0.0, end: 0.0).animate(_resetController)
          ..addListener(() {
            setState(() {
              _dragOffset = _resetAnimation.value;
            });
          });
  }

  @override
  void didUpdateWidget(covariant SlideToConfirmWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isLoading && oldWidget.isLoading && !_isConfirmed) {
      _resetSlider();
    }
    if (!widget.enabled && oldWidget.enabled) {
      _resetSlider();
    }
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  void _resetSlider() {
    _resetAnimation = Tween<double>(
      begin: _dragOffset,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _resetController, curve: Curves.easeOut));
    _resetController.forward(from: 0.0);
  }

  void _handleDragUpdate(DragUpdateDetails details, double maxDrag) {
    if (!widget.enabled || widget.isLoading || _isConfirmed) return;
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx).clamp(0.0, maxDrag);
    });
  }

  void _handleDragEnd(DragEndDetails details, double maxDrag) {
    if (!widget.enabled || widget.isLoading || _isConfirmed) return;

    if (maxDrag > 0 && (_dragOffset / maxDrag) >= 0.90) {
      // Trigger confirmation (Threshold >= 90%)
      setState(() {
        _dragOffset = maxDrag;
        _isConfirmed = true;
      });
      widget.onConfirmed?.call();
    } else {
      _resetSlider();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final thumbSize = widget.height - (_thumbPadding * 2);

    final trackBg = widget.enabled
        ? (isDark ? const Color(0xFF334155) : widget.backgroundColor)
        : (isDark ? Colors.grey[800]! : Colors.grey[200]!);

    final activeColor = widget.enabled ? widget.activeColor : Colors.grey[500]!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final maxDrag = (totalWidth - thumbSize - (_thumbPadding * 2)).clamp(
          0.0,
          double.infinity,
        );

        final dragPercent = maxDrag > 0
            ? (_dragOffset / maxDrag).clamp(0.0, 1.0)
            : 0.0;

        return Container(
          key: const Key('slide_to_confirm_track'),
          width: totalWidth,
          height: widget.height,
          decoration: BoxDecoration(
            color: trackBg,
            borderRadius: BorderRadius.circular(widget.height / 2),
            border: Border.all(
              color: widget.enabled
                  ? activeColor.withValues(alpha: 0.3)
                  : Colors.grey[400]!,
              width: 1.5,
            ),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Filled progress track behind thumb
              Container(
                width: _dragOffset + thumbSize + _thumbPadding,
                height: widget.height,
                decoration: BoxDecoration(
                  color: activeColor.withValues(
                    alpha: 0.15 + (dragPercent * 0.15),
                  ),
                  borderRadius: BorderRadius.circular(widget.height / 2),
                ),
              ),

              // Center label text
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48.0),
                  child: Text(
                    _isConfirmed
                        ? widget.confirmedLabel
                        : (widget.enabled
                              ? widget.label
                              : 'Terkunci / Nonaktif'),
                    key: const Key('slide_to_confirm_label'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: widget.enabled
                          ? (isDark ? Colors.white70 : activeColor)
                          : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // Draggable Thumb
              Positioned(
                left: _thumbPadding + _dragOffset,
                child: GestureDetector(
                  key: const Key('slide_to_confirm_thumb'),
                  onHorizontalDragUpdate: (d) => _handleDragUpdate(d, maxDrag),
                  onHorizontalDragEnd: (d) => _handleDragEnd(d, maxDrag),
                  child: Container(
                    width: thumbSize,
                    height: thumbSize,
                    decoration: BoxDecoration(
                      color: activeColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.35),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: widget.isLoading
                          ? const SizedBox(
                              key: Key('slide_to_confirm_loading'),
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _isConfirmed
                                  ? Icons.check
                                  : Icons.chevron_right_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
