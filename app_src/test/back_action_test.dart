library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/main.dart';

void main() {
  group('a back press undoes the topmost thing', () {
    test('with a playlist open, it closes the LIST — not the app', () {
      expect(
        backActionFor(
          libraryListOpen: true,
          panelOpen: false,
          playerOpen: false,
          hasTabHistory: false,
        ),
        BackAction.closeList,
        reason: 'a back press with a playlist open must close the playlist. Returning leaveApp here is the '
            'bug that closed the app on the device',
      );
    });

    test('an open list outranks a panel, the player and tab history', () {
      expect(
        backActionFor(
          libraryListOpen: true,
          panelOpen: true,
          playerOpen: true,
          hasTabHistory: true,
        ),
        BackAction.closeList,
        reason: 'an open list must be decided before a panel, the player or tab history — it is the thing the '
            'person is actually looking at',
      );
    });

    test('with nothing on the Library, a panel comes off next', () {
      expect(
        backActionFor(
          libraryListOpen: false,
          panelOpen: true,
          playerOpen: true,
          hasTabHistory: true,
        ),
        BackAction.closePanel,
      );
    });

    test('then the player, then the tab history', () {
      expect(
        backActionFor(
          libraryListOpen: false,
          panelOpen: false,
          playerOpen: true,
          hasTabHistory: true,
        ),
        BackAction.closePlayer,
      );
      expect(
        backActionFor(
          libraryListOpen: false,
          panelOpen: false,
          playerOpen: false,
          hasTabHistory: true,
        ),
        BackAction.previousTab,
      );
    });

    test('only with EVERYTHING closed does the app leave', () {
      expect(
        backActionFor(
          libraryListOpen: false,
          panelOpen: false,
          playerOpen: false,
          hasTabHistory: false,
        ),
        BackAction.leaveApp,
      );
    });
  });
}
