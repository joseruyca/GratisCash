import 'package:flutter_test/flutter_test.dart';
import 'package:gratiscash/core/safe_url.dart';

void main() {
  test('acepta HTTPS normal', () {
    expect(parseSafeExternalUrl('https://example.com/oferta'), isNotNull);
  });

  test('rechaza HTTP y credenciales embebidas', () {
    expect(parseSafeExternalUrl('http://example.com'), isNull);
    expect(parseSafeExternalUrl('https://user:pass@example.com'), isNull);
  });
}
