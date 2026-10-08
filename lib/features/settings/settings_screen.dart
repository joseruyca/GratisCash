import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/services.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final signedIn = Services.signedIn;
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
            children: [
              const _SectionTitle('Cuenta'),
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    if (signedIn) ...[
                      _tile(
                        context,
                        icon: Icons.person_outline_rounded,
                        title: 'Editar perfil',
                        subtitle: 'Nombre visible y usuario público',
                        route: '/profile/edit',
                      ),
                      const Divider(height: 1),
                    ] else
                      ListTile(
                        leading: const Icon(Icons.login_rounded),
                        title: const Text('Iniciar sesión'),
                        subtitle: const Text('Accede a tus guardadas y aportaciones'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.push('/auth'),
                      ),
                    _tile(
                      context,
                      icon: Icons.notifications_none_rounded,
                      title: 'Novedades',
                      subtitle: 'Oportunidades nuevas y las que terminan pronto',
                      route: '/notifications',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const _SectionTitle('Confianza, moderación y ayuda'),
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _tile(
                      context,
                      icon: Icons.help_outline_rounded,
                      title: 'Cómo funciona GratisCash',
                      subtitle: 'Qué publicamos, cómo verificamos y cómo participar',
                      route: '/legal/how',
                    ),
                    const Divider(height: 1),
                    _tile(
                      context,
                      icon: Icons.groups_outlined,
                      title: 'Normas de la comunidad',
                      subtitle: 'Contenido permitido, duplicados, denuncias y sanciones',
                      route: '/legal/community',
                    ),
                    const Divider(height: 1),
                    _tile(
                      context,
                      icon: Icons.policy_outlined,
                      title: 'Moderación y revisiones',
                      subtitle: 'Cómo decidimos y cómo puedes recurrir',
                      route: '/legal/moderation',
                    ),
                    const Divider(height: 1),
                    _tile(
                      context,
                      icon: Icons.campaign_outlined,
                      title: 'Afiliación y publicidad',
                      subtitle: 'Cómo puede ganar dinero GratisCash',
                      route: '/legal/affiliate',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const _SectionTitle('Privacidad y legal'),
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _tile(
                      context,
                      icon: Icons.privacy_tip_outlined,
                      title: 'Política de privacidad',
                      route: '/legal/privacy',
                    ),
                    const Divider(height: 1),
                    _tile(
                      context,
                      icon: Icons.cookie_outlined,
                      title: 'Cookies y almacenamiento web',
                      route: '/legal/cookies',
                    ),
                    const Divider(height: 1),
                    _tile(
                      context,
                      icon: Icons.description_outlined,
                      title: 'Términos de uso',
                      route: '/legal/terms',
                    ),
                    const Divider(height: 1),
                    _tile(
                      context,
                      icon: Icons.gavel_outlined,
                      title: 'Aviso legal y contacto',
                      route: '/legal/contact',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const _SectionTitle('Seguridad de la cuenta'),
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    if (signedIn) ...[
                      ListTile(
                        leading: const Icon(Icons.logout_rounded),
                        title: const Text('Cerrar sesión'),
                        subtitle: const Text('Cierra la sesión en este dispositivo'),
                        onTap: () async {
                          await Supabase.instance.client.auth.signOut();
                          if (!context.mounted) return;
                          context.go('/');
                        },
                      ),
                      const Divider(height: 1),
                      _tile(
                        context,
                        icon: Icons.delete_outline_rounded,
                        title: 'Eliminar cuenta y datos',
                        subtitle: 'Proceso irreversible con confirmación',
                        route: '/account/delete',
                        danger: true,
                      ),
                    ] else
                      const ListTile(
                        leading: Icon(Icons.security_outlined),
                        title: Text('Sin sesión iniciada'),
                        subtitle: Text('No hay datos de cuenta activos en este dispositivo.'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const Center(
                child: Text(
                  'GratisCash · versión 1.11.0 (13)',
                  style: TextStyle(color: GratisCashTheme.muted, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
    String? subtitle,
    bool danger = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: danger ? const Color(0xFFB33B46) : GratisCashTheme.muted,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: danger ? const Color(0xFF9A303A) : GratisCashTheme.dark,
        ),
      ),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.push(route),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: GratisCashTheme.muted,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
