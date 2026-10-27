@Tags(['slow'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sonarar/core/app_state.dart';
import 'package:sonarar/library/compendium.dart';
import 'package:sonarar/library/track.dart';
import 'package:sonarar/screens/bonds_screen.dart';
import 'package:sonarar/screens/compendium_screen.dart';
import 'package:sonarar/screens/history_screen.dart';
import 'package:sonarar/theme/skin.dart';

void main() {
  testWidgets('the compendium renders its rows when embedded inside another list',
      (tester) async {
    final tracks = [
      for (var i = 0; i < 6; i++)
        (
          id: 't$i',
          title: 'Track $i',
        ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              const SizedBox(height: 20),
              CompendiumScreen(
                skin: kSkinCrimson,
                entries: [
                  for (final t in tracks)
                    CompendiumEntry(
                      track: _track(t.id, t.title),
                      plays: 1,
                      completions: 1,
                      lastPlayedAt: DateTime(2026, 10, 1),
                    ),
                ],
                inline: true,
                onSummon: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstRow = find.text('Track 0');
    expect(firstRow, findsOneWidget, reason: 'the embedded list painted nothing');
    expect(tester.getSize(firstRow).height, greaterThan(0));
  });

  testWidgets('the ranks board inside History has real height', (tester) async {
    final state = AppState();
    state.attachLibrary([
      for (var i = 0; i < 5; i++) _track('t$i', 'Track $i'),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HistoryScreen(
            skin: kSkinCrimson,
            events: const [],
            tracks: state.library,
            inline: true,
            ranks: BondsScreen(
              state: state,
              events: const [],
              tracks: state.library,
              inline: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final board = find.byType(BondsScreen);
    expect(board, findsOneWidget);
    expect(tester.getSize(board).height, greaterThan(0),
        reason: 'the ranks board laid out to zero — a list inside a list needs shrinkWrap');
  });
}

Track _track(String id, String title) => Track(
      id: id,
      title: title,
      artist: 'ATLUS Sound Team',
      album: 'Persona 5',
      duration: const Duration(minutes: 4),
      file: '$id.opus',
      cover: '',
      gainDb: null,
    );
