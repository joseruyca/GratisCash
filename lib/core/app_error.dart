String publicErrorMessage(
  Object? error, {
  String fallback = 'Ha ocurrido un problema. Inténtalo de nuevo.',
}) {
  if (error == null) return fallback;

  final raw = error.toString().trim();
  final value = raw.toLowerCase();

  if (value.contains('socket') ||
      value.contains('network') ||
      value.contains('connection') ||
      value.contains('failed host lookup') ||
      value.contains('xmlhttprequest')) {
    return 'No podemos conectar ahora mismo. Comprueba tu conexión y vuelve a intentarlo.';
  }
  if (value.contains('jwt') ||
      value.contains('session') && value.contains('expired') ||
      value.contains('not authenticated')) {
    return 'Tu sesión ha caducado. Inicia sesión de nuevo.';
  }
  if (value.contains('permission') ||
      value.contains('row-level security') ||
      value.contains('rls') ||
      value.contains('42501')) {
    return 'No tienes permiso para realizar esta acción.';
  }
  if (value.contains('rate limit') || value.contains('too many requests')) {
    return 'Demasiados intentos seguidos. Espera un poco y vuelve a probar.';
  }
  if (value.contains('duplicate') || value.contains('23505')) {
    return 'Ese contenido ya existe o entra en conflicto con otro registro.';
  }
  if (error is ArgumentError || error is StateError) {
    final cleaned = raw
        .replaceFirst('Invalid argument(s): ', '')
        .replaceFirst('Bad state: ', '');
    if (cleaned.isNotEmpty && cleaned.length <= 180) return cleaned;
  }

  return fallback;
}
