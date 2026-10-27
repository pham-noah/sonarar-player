library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/art/art_focus.dart';

const _p3r = (w: 1920.0, h: 1080.0);
const _p5r = (w: 1500.0, h: 1250.0);
const _portraitSlot = (w: 400.0, h: 750.0);
const _thumbSlot = (w: 56.0, h: 56.0);

bool _covers(
  ({double w, double h}) src,
  ({double w, double h}) slot,
  ArtFocus focus,
) {
  final f = frameFor(
    srcW: src.w,
    srcH: src.h,
    slotW: slot.w,
    slotH: slot.h,
    focus: focus,
  );
  final drawnW = src.w * f.scale;
  final drawnH = src.h * f.scale;

  final left = f.offsetX - drawnW / 2;
  final right = f.offsetX + drawnW / 2;
  final top = f.offsetY - drawnH / 2;
  final bottom = f.offsetY + drawnH / 2;
  const eps = 1e-9;
  return left <= -slot.w / 2 + eps &&
      right >= slot.w / 2 - eps &&
      top <= -slot.h / 2 + eps &&
      bottom >= slot.h / 2 - eps;
}

void main() {
  group('cover', () {
    test('an untouched focus fills the slot', () {
      for (final src in [_p3r, _p5r]) {
        for (final slot in [_portraitSlot, _thumbSlot]) {
          expect(
            _covers(src, slot, ArtFocus.centre),
            isTrue,
            reason: 'centre framing of $src in $slot left a bare edge',
          );
        }
      }
    });

    test('the default scale is exactly BoxFit.cover', () {
      final f = frameFor(
        srcW: _p3r.w,
        srcH: _p3r.h,
        slotW: _portraitSlot.w,
        slotH: _portraitSlot.h,
        focus: ArtFocus.centre,
      );
      final coverScale = math.max(
        _portraitSlot.w / _p3r.w,
        _portraitSlot.h / _p3r.h,
      );
      expect(f.scale, closeTo(coverScale, 1e-12));
    });
  });

  group('the clamp holds at every extreme', () {
    const zooms = [kMinArtZoom, 1.2, 1.5, 2.0, kMaxArtZoom];
    const offsets = [-1.0, -0.5, -0.01, 0.0, 0.01, 0.5, 1.0];

    const wild = [-40.0, -2.5, 2.5, 40.0, double.infinity, -double.infinity];

    test('every in-range focus covers the slot', () {
      for (final src in [_p3r, _p5r]) {
        for (final slot in [_portraitSlot, _thumbSlot]) {
          for (final z in zooms) {
            for (final dx in offsets) {
              for (final dy in offsets) {
                final focus = ArtFocus(dx: dx, dy: dy, zoom: z);
                expect(
                  _covers(src, slot, focus),
                  isTrue,
                  reason: 'bare edge at $focus in $slot from $src',
                );
              }
            }
          }
        }
      }
    });

    test('an out-of-range focus covers the slot too', () {
      for (final src in [_p3r, _p5r]) {
        for (final slot in [_portraitSlot, _thumbSlot]) {
          for (final v in wild) {
            for (final focus in [
              ArtFocus(dx: v, dy: 0, zoom: 1),
              ArtFocus(dx: 0, dy: v, zoom: 1.5),
              ArtFocus(dx: v, dy: v, zoom: 1.5),
              ArtFocus(dx: 0, dy: 0, zoom: v),
            ]) {
              expect(
                _covers(src, slot, focus),
                isTrue,
                reason: 'bare edge at $focus in $slot from $src',
              );
            }
          }
        }
      }
    });

    test('the clamp is tight, not merely safe', () {
      final slot = _portraitSlot;
      final src = _p3r;
      for (final dx in [-1.0, 1.0]) {
        for (final zoom in [1.2, 2.0]) {
          final f = frameFor(
            srcW: src.w,
            srcH: src.h,
            slotW: slot.w,
            slotH: slot.h,
            focus: ArtFocus(dx: dx, zoom: zoom),
          );
          final drawnW = src.w * f.scale;
          final room = (drawnW - slot.w) / 2;
          expect(
            f.offsetX.abs(),
            closeTo(room, 1e-9),
            reason: 'dx=$dx at x$zoom did not reach the edge it could reach',
          );
        }
      }
    });

    test('a landscape source in a tall slot cannot pan vertically at all', () {
      final reach = reachFor(
        srcW: _p3r.w,
        srcH: _p3r.h,
        slotW: _portraitSlot.w,
        slotH: _portraitSlot.h,
        zoom: 1.0,
      );
      expect(reach.y, closeTo(0.0, 1e-9));
      expect(reach.x, greaterThan(0.0));
    });

    test('reach agrees with what the frame actually allows', () {
      for (final src in [_p3r, _p5r]) {
        final slot = _portraitSlot;
        for (final zoom in [1.0, 1.4, 2.5]) {
          final reach = reachFor(
            srcW: src.w,
            srcH: src.h,
            slotW: slot.w,
            slotH: slot.h,
            zoom: zoom,
          );
          for (final (axis, allowed) in [('x', reach.x), ('y', reach.y)]) {
            final atLimit = axis == 'x'
                ? ArtFocus(dx: allowed, zoom: zoom)
                : ArtFocus(dy: allowed, zoom: zoom);
            final fLimit = frameFor(
              srcW: src.w,
              srcH: src.h,
              slotW: slot.w,
              slotH: slot.h,
              focus: atLimit,
            );
            final offset = axis == 'x' ? fLimit.offsetX : fLimit.offsetY;
            final scaled = axis == 'x' ? src.w * fLimit.scale : src.h * fLimit.scale;
            final slotSize = axis == 'x' ? slot.w : slot.h;
            final room = (scaled - slotSize) / 2;
            expect(
              offset.abs(),
              closeTo(room, 1e-9),
              reason: 'reach() understated $axis travel for $src at x$zoom',
            );

            final beyond = allowed + 0.5;
            final fBeyond = frameFor(
              srcW: src.w,
              srcH: src.h,
              slotW: slot.w,
              slotH: slot.h,
              focus: axis == 'x'
                  ? ArtFocus(dx: beyond, zoom: zoom)
                  : ArtFocus(dy: beyond, zoom: zoom),
            );
            expect(
              (axis == 'x' ? fBeyond.offsetX : fBeyond.offsetY),
              closeTo(offset, 1e-9),
            );
          }
        }
      }
    });
  });

  group('normalising an input', () {
    test('clamped() forces every field into range', () {
      final c = const ArtFocus(dx: 9, dy: -9, zoom: 99).clamped();
      expect(c.dx, 1.0);
      expect(c.dy, -1.0);
      expect(c.zoom, kMaxArtZoom);

      expect(const ArtFocus(zoom: 0.2).clamped().zoom, kMinArtZoom);
    });

    test('copyWith returns an already-clamped focus', () {
      final f = const ArtFocus().copyWith(zoom: 500);
      expect(f.zoom, kMaxArtZoom);
      expect(f, const ArtFocus(zoom: kMaxArtZoom));
    });
  });

  group('round-tripping through disk', () {
    test('a written focus reads back identical', () {
      const f = ArtFocus(dx: 0.56, dy: -0.2, zoom: 1.35);
      expect(ArtFocus.fromJson(f.toJson()), f);
    });

    test('an unusable entry reads as null, so the piece keeps its own default', () {
      for (final bad in <Object?>[
        null,
        'nonsense',
        42,
        <String, dynamic>{},
        {'dx': 'left', 'dy': 0.0, 'zoom': 1.0},
        {'dx': 0.0, 'dy': 0.0},
        {'dx': double.nan, 'dy': 0.0, 'zoom': 1.0},
        {'dx': 0.0, 'dy: ': 0.0, 'zoom': double.infinity},
      ]) {
        expect(ArtFocus.fromJson(bad), isNull, reason: 'accepted $bad');
      }
    });

    test('an out-of-range entry is clamped rather than rejected', () {
      final f = ArtFocus.fromJson({'dx': 40.0, 'dy': -40.0, 'zoom': 900.0});
      expect(f, isNotNull);
      expect(f!.dx, 1.0);
      expect(f.dy, -1.0);
      expect(f.zoom, kMaxArtZoom);
    });

    test('centre is recognised, so it does not need storing', () {
      expect(const ArtFocus().isCentre, isTrue);
      expect(const ArtFocus(dx: 0.1).isCentre, isFalse);
      expect(const ArtFocus(zoom: 1.01).isCentre, isFalse);
    });
  });

  group('degenerate geometry', () {
    test('a zero-sized source or slot frames to identity, not to NaN', () {
      for (final f in [
        frameFor(srcW: 0, srcH: 100, slotW: 10, slotH: 10, focus: ArtFocus.centre),
        frameFor(srcW: 100, srcH: 100, slotW: 0, slotH: 10, focus: ArtFocus.centre),
        frameFor(srcW: 100, srcH: 0, slotW: 10, slotH: 0, focus: ArtFocus.centre),
      ]) {
        expect(f.scale.isFinite, isTrue);
        expect(f.offsetX.isFinite, isTrue);
        expect(f.offsetY.isFinite, isTrue);
      }
    });
  });
}
