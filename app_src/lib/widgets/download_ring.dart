library;

import 'package:flutter/material.dart';

import '../download/download_manager.dart';
import '../theme/skin.dart';

class DownloadRing extends StatelessWidget {
  const DownloadRing({
    super.key,
    required this.manager,
    required this.skin,
    required this.coverOf,
    this.onTap,
    this.size = 44,
  });

  final DownloadManager manager;
  final Skin skin;

  final ImageProvider? Function(DownloadJob job) coverOf;

  final VoidCallback? onTap;

  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: manager,
      builder: (context, _) {
        final job = manager.current;
        if (job == null) return const SizedBox.shrink();

        final waiting = manager.pendingCount;

        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: GestureDetector(
            key: const Key('download-ring'),
            onTap: onTap,
            child: Tooltip(
              message: waiting > 0
                  ? '${job.title} · ${job.progressText} · $waiting more waiting'
                  : '${job.title} · ${job.progressText}',
              child: SizedBox(
                width: size,
                height: size,
                child: Stack(
                  alignment: Alignment.center,
                  children: [

                    ClipRRect(
                      borderRadius: BorderRadius.circular(size / 2),
                      child: SizedBox(
                        width: size - 6,
                        height: size - 6,
                        child: coverOf(job) == null
                            ? ColoredBox(
                                color: skin.panel,
                                child: Icon(Icons.downloading_rounded,
                                    size: 18, color: skin.accent),
                              )
                            : Image(image: coverOf(job)!, fit: BoxFit.cover),
                      ),
                    ),

                    SizedBox(
                      width: size,
                      height: size,
                      child: CircularProgressIndicator(
                        value: job.fraction,
                        strokeWidth: 3,
                        color: skin.accent,
                        backgroundColor: skin.panel,
                      ),
                    ),

                    if (waiting > 0)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: skin.accent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$waiting',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: skin.onAccent,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
