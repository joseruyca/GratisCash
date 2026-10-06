import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_error.dart';
import '../../core/services.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayName = TextEditingController();
  final _username = TextEditingController();
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _displayName.dispose();
    _username.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await Services.repo.currentProfile();
      if (!mounted) return;
      if (profile == null) {
        setState(() {
          _loading = false;
          _error = 'No se ha podido cargar tu perfil.';
        });
        return;
      }
      _displayName.text = profile.displayName;
      _username.text = profile.username;
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = publicErrorMessage(error);
      });
    }
  }

  String? _nameValidator(String? value) {
    final text = value?.trim() ?? '';
    if (text.length < 2 || text.length > 60) {
      return 'Usa entre 2 y 60 caracteres.';
    }
    return null;
  }

  String? _usernameValidator(String? value) {
    final text = (value?.trim() ?? '').toLowerCase();
    const reserved = <String>{
      'gratiscash', 'gratiscashapp', 'admin', 'administrator', 'moderator',
      'moderador', 'support', 'soporte', 'staff', 'official', 'oficial',
    };
    if (text.length < 3 || text.length > 32) {
      return 'Usa entre 3 y 32 caracteres.';
    }
    if (!RegExp(r'^[a-z0-9_.]+$').hasMatch(text)) {
      return 'Solo letras minúsculas, números, punto y guion bajo.';
    }
    if (reserved.contains(text)) {
      return 'Ese usuario está reservado por seguridad.';
    }
    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      await Services.repo.updateMyProfile(
        displayName: _displayName.text.trim(),
        username: _username.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil actualizado.')),
      );
      context.pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(publicErrorMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(
                  icon: Icons.person_off_outlined,
                  title: 'Perfil no disponible',
                  body: _error!,
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Form(
                      key: _formKey,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        children: [
                          const SurfaceCard(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.shield_outlined, color: GratisCashTheme.green),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Tu nombre visible y tu usuario son públicos. El email de acceso no se muestra en tu perfil.',
                                    style: TextStyle(color: GratisCashTheme.muted, height: 1.45),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _displayName,
                            validator: _nameValidator,
                            maxLength: 60,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Nombre visible',
                              prefixIcon: Icon(Icons.person_outline_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _username,
                            validator: _usernameValidator,
                            maxLength: 32,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'Usuario',
                              prefixText: '@',
                              prefixIcon: Icon(Icons.alternate_email_rounded),
                            ),
                          ),
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed: _busy ? null : _save,
                            child: Text(_busy ? 'Guardando…' : 'Guardar cambios'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }
}
