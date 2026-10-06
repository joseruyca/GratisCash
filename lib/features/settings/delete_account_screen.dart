import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/services.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_confirm.text.trim().toUpperCase() != 'ELIMINAR') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe ELIMINAR para confirmar.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Última confirmación'),
        content: const Text(
          'La eliminación es permanente. Se eliminarán tu cuenta y el contenido generado por ti que siga asociado a ella. ¿Quieres continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFC13A45),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar cuenta'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await Services.repo.deleteMyAccount();
      if (mounted) context.go('/');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo eliminar la cuenta: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canDelete = Services.signedIn;
    return Scaffold(
      appBar: AppBar(title: const Text('Eliminar cuenta')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const SizedBox(height: 20),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFEAEC),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_forever_outlined,
                        color: Color(0xFFC13A45),
                        size: 27,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Eliminar tu cuenta y datos',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'La cuenta dejará de existir. GratisCash eliminará el contenido generado por ti que siga asociado a la cuenta, además de guardados, votos, comentarios y datos de perfil. Solo se conservará un dato concreto si existe una obligación legal que lo exija.',
                      style: TextStyle(
                        color: GratisCashTheme.muted,
                        height: 1.48,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Antes de continuar:',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• La acción no se puede deshacer.\n• Perderás tus guardados y acceso a la cuenta.\n• Tus comentarios y oportunidades creadas como usuario se eliminarán.\n• Las fichas editoriales de GratisCash no dependen de tu cuenta.',
                      style: TextStyle(height: 1.55),
                    ),
                    const SizedBox(height: 18),
                    if (!canDelete)
                      FilledButton(
                        onPressed: () => context.push('/auth'),
                        child: const Text('Iniciar sesión para continuar'),
                      )
                    else ...[
                      TextField(
                        controller: _confirm,
                        enabled: !_busy,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Escribe ELIMINAR',
                          hintText: 'ELIMINAR',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFC13A45),
                          ),
                          onPressed: _busy ? null : _delete,
                          child: Text(
                            _busy ? 'Eliminando…' : 'Eliminar definitivamente',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'También disponible en la web: ${AppConfig.websiteUrl}/account/delete',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: GratisCashTheme.muted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
