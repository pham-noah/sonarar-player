library;

import 'package:flutter/material.dart';

import '../theme/skin.dart';

enum PanelSize {
  small(0.45),
  mid(0.78),
  full(1.0);

  const PanelSize(this.factor);
  final double factor;

  PanelSize get up => switch (this) {
        PanelSize.small => PanelSize.mid,
        PanelSize.mid => PanelSize.full,
        PanelSize.full => PanelSize.full,
      };

  PanelSize get down => switch (this) {
        PanelSize.small => PanelSize.small,
        PanelSize.mid => PanelSize.small,
        PanelSize.full => PanelSize.mid,
      };
}

class InlinePanelSheet extends StatefulWidget {
  const InlinePanelSheet({
    super.key,
    required this.skin,
    required this.title,
    required this.child,
    required this.onClose,
    this.onBack,
    this.initialSize = PanelSize.mid,
  });

  final Skin skin;
  final String title;
  final Widget child;

  final VoidCallback onClose;

  final VoidCallback? onBack;

  final PanelSize initialSize;

  @override
  State<InlinePanelSheet> createState() => _InlinePanelSheetState();
}

class _InlinePanelSheetState extends State<InlinePanelSheet> {
  late PanelSize _size = widget.initialSize;

  double _dy = 0;

  void _onDragUpdate(DragUpdateDetails d) => _dy += d.primaryDelta ?? 0;

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    final dy = _dy;
    _dy = 0;

    final up = v < -220 || dy < -48;
    final down = v > 220 || dy > 48;
    if (!up && !down) return;

    setState(() {
      if (up) {
        _size = _size.up;
      } else if (_size == PanelSize.small) {
        widget.onClose();
        return;
      } else {
        _size = _size.down;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin;
    final screen = MediaQuery.of(context).size;

    return Positioned.fill(
      child: Stack(
        children: [

          GestureDetector(
            onTap: widget.onClose,
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.55)),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              height: screen.height * _size.factor,
              decoration: BoxDecoration(
                color: skin.background,
                border: Border(top: BorderSide(color: skin.accent, width: 2)),
              ),
              child: Column(
                children: [

                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragUpdate: _onDragUpdate,
                    onVerticalDragEnd: _onDragEnd,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 8, 6, 2),
                      child: Row(
                        children: [

                          Icon(
                            _size == PanelSize.full
                                ? Icons.keyboard_arrow_down_rounded
                                : Icons.drag_handle_rounded,
                            color: skin.textSecondary,
                          ),
                          if (widget.onBack != null)
                            IconButton(
                              onPressed: widget.onBack,
                              icon: Icon(Icons.arrow_back_rounded,
                                  color: skin.textSecondary),
                              tooltip: 'Back',
                            )
                          else
                            const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: LayoutSpec.fontLabel,
                                letterSpacing: 4,
                                fontWeight: FontWeight.w800,
                                color: skin.accent,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: widget.onClose,
                            icon: Icon(Icons.close_rounded,
                                color: skin.textSecondary),
                            tooltip: 'Close',
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(child: widget.child),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
