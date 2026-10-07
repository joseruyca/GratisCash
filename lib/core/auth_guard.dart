import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'config.dart';
import 'services.dart';

Future<bool> ensureSignedIn(
  BuildContext context, {
  String message = 'Inicia sesión para usar esta función.',
}) async {
  if (Services.signedIn) {
    return true;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
  await context.push('/auth');
  return Services.signedIn;
}

Future<bool> ensureCommunityAccess(
  BuildContext context, {
  String message = 'Inicia sesión para participar en la comunidad.',
}) async {
  if (!await ensureSignedIn(
    context,
    message: message,
  )) {
    return false;
  }

  final profile = await Services.repo.currentProfile();
  if (!context.mounted || profile == null) {
    return false;
  }

  if (profile.isSuspended) {
    final reason = profile.suspensionReason?.trim();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          reason == null || reason.isEmpty
              ? 'Tu cuenta está temporalmente limitada. Contacta con soporte.'
              : 'Tu cuenta está limitada: $reason',
        ),
      ),
    );
    return false;
  }

  if (profile.hasCurrentCommunityConsent) {
    return true;
  }

  var accepted = false;
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Normas de la comunidad'),
      content: const Text(
        'Para publicar o comentar debes tener 18 años o más y aceptar la versión vigente de los Términos y las Normas de la comunidad.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Ahora no'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Soy mayor de 18 y acepto'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    try {
      await Services.repo.acceptCommunityTerms();
      accepted = true;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo guardar la aceptación. Inténtalo de nuevo.')),
        );
      }
    }
  }

  return accepted;
}
