import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/services.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _refreshKey = 0;

  Future<_ProfileData> _load() async {
    final profile = await Services.repo.currentProfile();
    final submissions = await Services.repo.mySubmissions();
    final saved = await Services.repo.savedIds();
    return _ProfileData(
      profile: profile,
      submissions: submissions,
      savedCount: saved.length,
    );
  }

  Future<void> _appeal(Opportunity item) async {
    final controller = TextEditingController();
    final message = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Pedir una nueva revisión'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.moderationReason != null && item.moderationReason!.isNotEmpty) ...[
              const Text('Motivo de moderación', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(item.moderationReason!),
              const SizedBox(height: 14),
            ],
            TextField(
              controller: controller,
              minLines: 3,
              maxLines: 6,
              maxLength: 1200,
              decoration: const InputDecoration(
                labelText: 'Explica por qué deberíamos revisarla de nuevo',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Enviar revisión'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (message == null || message.length < 10) {
      if (message != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Explica el motivo con un poco más de detalle.')),
        );
      }
      return;
    }

    try {
      await Services.repo.appealModeration(item.id, message);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud de revisión enviada.')),
      );
      setState(() => _refreshKey++);
    } catch (error) {
      if (!mounted) return;
      final text = error.toString().toLowerCase();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            text.contains('unique') || text.contains('duplicate')
                ? 'Ya existe una solicitud de revisión abierta para esta oportunidad.'
                : 'No se pudo enviar la revisión. Inténtalo de nuevo.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = Services.signedIn;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          if (signedIn)
            IconButton(
              tooltip: 'Editar perfil',
              onPressed: () async {
                await context.push('/profile/edit');
                if (mounted) setState(() => _refreshKey++);
              },
              icon: const Icon(Icons.edit_outlined),
            ),
          IconButton(
            tooltip: 'Ajustes',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: !signedIn
          ? EmptyState(
              icon: Icons.person_outline_rounded,
              title: 'Tu espacio en GratisCash',
              body:
                  'Inicia sesión para guardar oportunidades, comentar y seguir el estado de lo que publiques.',
              action: FilledButton(
                onPressed: () async {
                  await context.push('/auth');
                  if (mounted) setState(() => _refreshKey++);
                },
                child: const Text('Iniciar sesión'),
              ),
            )
          : FutureBuilder<_ProfileData>(
              key: ValueKey(_refreshKey),
              future: _load(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'No podemos cargar tu perfil',
                    body: 'Comprueba tu conexión e inténtalo de nuevo.',
                  );
                }
                final data = snapshot.data;
                final profile = data?.profile;
                if (profile == null) {
                  return const EmptyState(
                    icon: Icons.person_off_outlined,
                    title: 'Perfil no disponible',
                    body: 'Vuelve a iniciar sesión e inténtalo de nuevo.',
                  );
                }
                return _ProfileBody(data: data!, onAppeal: _appeal);
              },
            ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  const _ProfileBody({required this.data, required this.onAppeal});

  final _ProfileData data;
  final Future<void> Function(Opportunity item) onAppeal;

  @override
  Widget build(BuildContext context) {
    final profile = data.profile!;
    final pending = data.submissions
        .where((item) => item.status == OpportunityStatus.pending)
        .length;
    final approved = data.submissions
        .where(
          (item) =>
              item.status == OpportunityStatus.active ||
              item.status == OpportunityStatus.expired,
        )
        .length;
    final rejected = data.submissions
        .where((item) => item.status == OpportunityStatus.rejected)
        .length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 110),
      children: [
        SurfaceCard(
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: const Color(0xFFE0F7EE),
                    backgroundImage: profile.avatarUrl == null
                        ? null
                        : NetworkImage(profile.avatarUrl!),
                    child: profile.avatarUrl == null
                        ? Text(
                            profile.displayName.isEmpty
                                ? '?'
                                : profile.displayName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 26,
                              color: GratisCashTheme.greenDark,
                              fontWeight: FontWeight.w900,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.displayName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '@${profile.username}',
                          style: const TextStyle(color: GratisCashTheme.muted),
                        ),
                        if (profile.isSuspended) ...[
                          const SizedBox(height: 6),
                          const StatusPill('Cuenta limitada', active: false),
                        ],
                      ],
                    ),
                  ),
                  if (profile.isStaff)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1D8),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shield_outlined, size: 15),
                          const SizedBox(width: 4),
                          Text(
                            profile.role == 'admin' ? 'Admin' : 'Moderación',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      value: '${data.submissions.length}',
                      label: 'Enviadas',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _Stat(value: '$approved', label: 'Aprobadas')),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Stat(value: '${data.savedCount}', label: 'Guardadas'),
                  ),
                ],
              ),
              if (profile.isSuspended) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFD7DB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cuenta limitada',
                        style: TextStyle(
                          color: Color(0xFF9A303A),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        profile.suspensionReason?.trim().isNotEmpty == true
                            ? profile.suspensionReason!.trim()
                            : 'Tu cuenta no puede crear contenido mientras revisamos una incidencia.',
                        style: const TextStyle(height: 1.4),
                      ),
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: () => context.push('/legal/moderation'),
                        child: const Text('Ver política de moderación y contacto'),
                      ),
                    ],
                  ),
                ),
              ],
              if (pending > 0 || rejected > 0) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F6F7),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    [
                      if (pending > 0) '$pending en revisión',
                      if (rejected > 0) '$rejected rechazadas',
                    ].join(' · '),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: profile.isSuspended ? null : () => context.go('/submit'),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Publicar oportunidad'),
                ),
              ),
              if (profile.isStaff) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/admin'),
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: const Text('Panel de administración'),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Tus aportaciones',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ),
            TextButton.icon(
              onPressed: () => context.go('/saved'),
              icon: const Icon(Icons.bookmark_border_rounded),
              label: const Text('Guardadas'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (data.submissions.isEmpty)
          const SurfaceCard(
            child: Text(
              'Todavía no has enviado ninguna oportunidad. Cuando publiques una, podrás seguir aquí su estado de revisión.',
              style: TextStyle(color: GratisCashTheme.muted, height: 1.45),
            ),
          )
        else
          for (final item in data.submissions) ...[
            OpportunityCard(
              item: item,
              showStatus: true,
              onTap: () {
                if (item.status == OpportunityStatus.active ||
                    item.status == OpportunityStatus.expired) {
                  context.go('/opportunity/${item.id}');
                }
              },
            ),
            if (item.status == OpportunityStatus.rejected) ...[
              const SizedBox(height: 6),
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3F4),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: const Color(0xFFF1D4D7)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFA33B45)),
                        SizedBox(width: 7),
                        Text(
                          'Motivo de moderación',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.moderationReason?.trim().isNotEmpty == true
                          ? item.moderationReason!
                          : 'La propuesta no cumple actualmente los criterios de publicación.',
                      style: const TextStyle(height: 1.4),
                    ),
                    if (item.duplicateOf != null) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'La moderación la marcó como posible duplicado de otra oportunidad existente.',
                        style: TextStyle(color: GratisCashTheme.muted, fontSize: 12.5),
                      ),
                    ],
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => onAppeal(item),
                      icon: const Icon(Icons.rate_review_outlined),
                      label: const Text('Pedir revisión'),
                    ),
                  ],
                ),
              ),
            ] else
              const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: GratisCashTheme.muted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _ProfileData {
  const _ProfileData({
    required this.profile,
    required this.submissions,
    required this.savedCount,
  });

  final UserProfile? profile;
  final List<Opportunity> submissions;
  final int savedCount;
}
