import 'package:flutter_test/flutter_test.dart';
import 'package:oportu/core/app_error.dart';

void main() {
  test('no expone errores internos desconocidos al usuario', () {
    final text = publicErrorMessage(Exception('internal database detail xyz'));
    expect(text.contains('internal database detail'), isFalse);
  });

  test('traduce errores de red a un mensaje útil', () {
    final text = publicErrorMessage(Exception('SocketException: failed host lookup'));
    expect(text.toLowerCase(), contains('conexión'));
  });

  test('conserva errores de validación controlados', () {
    final text = publicErrorMessage(ArgumentError('Nombre no válido.'));
    expect(text, 'Nombre no válido.');
  });
}
