library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late final String src;

  setUpAll(() {
    src = File('lib/main.dart').readAsStringSync();
  });

  String bodyOf(String signature) {
    var start = src.indexOf(signature);
    expect(start, greaterThan(-1), reason: '$signature not found — did it move or get renamed?');

    var j = src.indexOf('(', start);
    var pdepth = 0;
    for (; j < src.length; j++) {
      if (src[j] == '(') pdepth++;
      if (src[j] == ')') {
        pdepth--;
        if (pdepth == 0) break;
      }
    }
    var i = src.indexOf('{', j);
    final open = i;
    var depth = 0;
    for (; i < src.length; i++) {
      if (src[i] == '{') depth++;
      if (src[i] == '}') {
        depth--;
        if (depth == 0) break;
      }
    }
    return src.substring(open, i + 1);
  }

  test('the play/pause handler pings the route', () {
    // The transport used to live in _togglePlay and had to call _shellChanged
    // itself. It lives in PlayerController now, and the shell hears it through
    // _onPlayerChanged — so that is where the ping has to happen. The route is
    // outside the shell's builder: setState alone would leave the play icon
    // stale until the player was reopened.
    final body = bodyOf('void _onPlayerChanged()');
    expect(body.contains('setState('), isTrue,
        reason: 'the transport listener does not repaint, so the PLAYER ROUTE\'s '
            'play button will keep drawing the old icon. That is "the play/pause '
            'doesn\'t change the icon inside".');
  });

  test('every shell setState is what pings the route', () {
    // The mechanism the listener relies on: the override bumps _shellTick, and
    // the pushed route listens to it. If this stops being true, everything that
    // repaints the shell silently stops repainting the player.
    final body = bodyOf('void setState(VoidCallback fn)');
    expect(body.contains('_shellTick.value++'), isTrue,
        reason: 'setState no longer pings the route — pushed routes will go stale');
  });

  test('the track-load path pings the route', () {
    final body = bodyOf('Future<bool> _loadCurrentTrack(');
    expect(body.contains('_shellChanged('), isTrue,
        reason: '_loadCurrentTrack only uses setState, so a skip rebuilds the shell and NOT the pushed player '
            'route. The player keeps showing the previous track.');
  });

  test('the player is wired to its transport buttons — NOT just its swipes', () {
    final playerSite = src.substring(src.indexOf('Widget _playerBody('));
    expect(playerSite.contains('onNext:'), isTrue,
        reason: 'the player is not wired to onNext — the button will do nothing while the swipe still works, '
            'which is the reported asymmetry');
    expect(playerSite.contains('onPrevious:'), isTrue,
        reason: 'the player is not wired to onPrevious');

    expect(playerSite.contains('onNext: () {'), isTrue);
    expect(playerSite.contains('onPrevious: () {'), isTrue);
  });

  test('and the swipe is wired too, so a button fix cannot be a swipe regression', () {
    final playerSite = src.substring(src.indexOf('Widget _playerBody('));
    expect(playerSite.contains('onSwipeNext:'), isTrue);
    expect(playerSite.contains('onSwipePrevious:'), isTrue);
  });

  test('and nothing in the load path fell back to a bare setState for _playing', () {
    final body = bodyOf('Future<bool> _loadCurrentTrack(');
    expect(body.contains('setState(() => _playing'), isFalse,
        reason: '_playing is being set with a bare setState in the load path — the route will not redraw');
  });
}
