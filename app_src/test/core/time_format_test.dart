import 'package:flutter_test/flutter_test.dart';
import 'package:sonarar/core/time_format.dart';

/// The rule the app says a length in. Four copies of this existed; only one of
/// them handled an hour, which is why a 75-minute mix read `75:03`.
void main() {
  test('under an hour is minutes and seconds', () {
    expect(mmss(Duration.zero), '0:00');
    expect(mmss(const Duration(minutes: 4, seconds: 7)), '4:07');
    expect(mmss(const Duration(minutes: 59, seconds: 59)), '59:59');
  });

  test('an hour or more grows an hours field', () {
    expect(mmss(const Duration(hours: 1)), '1:00:00');
    expect(mmss(const Duration(minutes: 64, seconds: 7)), '1:04:07');
    expect(mmss(const Duration(hours: 12, minutes: 5)), '12:05:00');
  });
}
