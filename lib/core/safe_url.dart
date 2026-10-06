import 'package:url_launcher/url_launcher.dart';

Uri? parseSafeExternalUrl(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null ||
      uri.scheme.toLowerCase() != 'https' ||
      uri.host.isEmpty ||
      uri.hasFragment && uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri;
}

Future<void> launchExternal(String raw) async {
  final uri = parseSafeExternalUrl(raw);
  if (uri == null) {
    throw ArgumentError('El enlace no es HTTPS o no es válido.');
  }

  final opened = await launchUrl(uri, mode: LaunchMode.platformDefault);
  if (!opened) {
    throw StateError('No se pudo abrir el enlace.');
  }
}
