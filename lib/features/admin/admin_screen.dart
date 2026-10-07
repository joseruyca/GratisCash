import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_error.dart';
import '../../core/services.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 6, vsync: this);
  int _refreshKey = 0;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _refresh() => setState(() => _refreshKey++);

  Future<String?> _askReason({
    required String title,
    required String hint,
    String initial = '',
  }) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 7,
          maxLength: 1200,
          decoration: InputDecoration(
            labelText: 'Motivo visible para el usuario',
            hintText: hint,
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _moderate(
    String id,
    String status, {
    String? duplicateOf,
    String? defaultReason,
  }) async {
    String? reason;
    if (status == 'rejected') {
      reason = await _askReason(
        title: duplicateOf == null ? 'Rechazar propuesta' : 'Marcar como duplicada',
        hint: duplicateOf == null
            ? 'Explica qué debe corregirse o por qué no puede publicarse.'
            : 'Explica que ya existe una oportunidad equivalente.',
        initial: defaultReason ?? '',
      );
      if (reason == null) return;
      if (reason.trim().length < 8) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('El motivo debe tener al menos 8 caracteres.')),
          );
        }
        return;
      }
    }

    try {
      await Services.repo.moderate(
        id,
        status,
        reason: reason,
        duplicateOf: duplicateOf,
      );
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'active'
                ? 'Oportunidad aprobada.'
                : status == 'expired'
                    ? 'Oportunidad archivada.'
                    : 'Oportunidad rechazada con motivo registrado.',
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo completar la moderación.')),
        );
      }
    }
  }

  Future<void> _report(String id, String status) async {
    try {
      await Services.repo.reviewReport(id, status);
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Denuncia revisada.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar la denuncia.')),
        );
      }
    }
  }

  Future<void> _resolveAppeal(ModerationAppeal appeal, String decision) async {
    final response = await _askReason(
      title: switch (decision) {
        'reopen' => 'Reabrir para nueva revisión',
        'uphold' => 'Confirmar decisión anterior',
        _ => 'Cerrar solicitud',
      },
      hint: 'Explica la decisión de forma clara para la persona que publicó.',
    );
    if (response == null || response.trim().length < 8) return;

    try {
      await Services.repo.resolveAppeal(
        id: appeal.id,
        decision: decision,
        response: response,
      );
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud de revisión resuelta.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo resolver la solicitud.')),
        );
      }
    }
  }

  Future<void> _setUserRole(Map<String, dynamic> row, String role) async {
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) return;

    try {
      await Services.repo.setUserRole(id: id, role: role);
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rol actualizado y registrado.')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo cambiar el rol. Solo un administrador puede hacerlo.'),
          ),
        );
      }
    }
  }

  Future<void> _toggleUser(Map<String, dynamic> row) async {
    final id = row['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final suspended = row['is_suspended'] == true;
    final reason = await _askReason(
      title: suspended ? 'Restaurar cuenta' : 'Suspender cuenta',
      hint: suspended
          ? 'Explica por qué se restaura el acceso a la comunidad.'
          : 'Explica qué norma se ha incumplido o qué riesgo requiere la suspensión.',
    );
    if (reason == null || reason.trim().length < 8) return;

    try {
      await Services.repo.setUserSuspended(
        id: id,
        suspended: !suspended,
        reason: reason,
      );
      if (!mounted) return;
      _refresh();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(suspended ? 'Cuenta restaurada.' : 'Cuenta suspendida.'),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo actualizar la cuenta.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: Services.repo.currentProfile(),
      builder: (context, access) {
        if (access.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (access.data?.isStaff != true) {
          return Scaffold(
            appBar: AppBar(title: const Text('Administración')),
            body: const EmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Acceso restringido',
              body: 'Esta zona solo está disponible para moderación y administración.',
            ),
          );
        }

        final canManageRoles = access.data?.role == 'admin';
        final currentUserId = access.data?.id;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Administración · GratisCash'),
            bottom: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Pendientes'),
                Tab(text: 'Publicadas'),
                Tab(text: 'Denuncias'),
                Tab(text: 'Revisiones'),
                Tab(text: 'Usuarios'),
                Tab(text: 'Métricas'),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: FilledButton.icon(
                  onPressed: () async {
                    await context.push('/admin/new');
                    if (mounted) _refresh();
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Nueva'),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                color: const Color(0xFFF3F8F6),
                child: const Text(
                  'Toda decisión negativa debe llevar un motivo. Las coincidencias se señalan, pero una similitud nunca rechaza contenido automáticamente.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: GratisCashTheme.muted),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _PendingTab(
                      key: ValueKey('pending-$_refreshKey'),
                      onModerate: _moderate,
                    ),
                    _PublishedTab(
                      key: ValueKey('published-$_refreshKey'),
                      onChanged: _refresh,
                    ),
                    _ReportsTab(
                      key: ValueKey('reports-$_refreshKey'),
                      onReview: _report,
                    ),
                    _AppealsTab(
                      key: ValueKey('appeals-$_refreshKey'),
                      onResolve: _resolveAppeal,
                    ),
                    _UsersTab(
                      key: ValueKey('users-$_refreshKey'),
                      onToggle: _toggleUser,
                      onRole: _setUserRole,
                      canManageRoles: canManageRoles,
                      currentUserId: currentUserId,
                    ),
                    _MetricsTab(
                      key: ValueKey('metrics-$_refreshKey'),
                      canEdit: canManageRoles,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PendingTab extends StatelessWidget {
  const _PendingTab({super.key, required this.onModerate});

  final Future<void> Function(
    String id,
    String status, {
    String? duplicateOf,
    String? defaultReason,
  }) onModerate;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Services.repo.pendingForAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'No se puede cargar la cola',
            body: 'Comprueba la conexión con el backend.',
          );
        }
        final rows = snapshot.data ?? <Map<String, dynamic>>[];
        if (rows.isEmpty) {
          return const EmptyState(
            icon: Icons.task_alt_rounded,
            title: 'Cola vacía',
            body: 'No hay propuestas pendientes de revisión.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            final id = row['id']?.toString() ?? '';
            final duplicateId = row['duplicate_candidate_id']?.toString();
            final duplicateTitle = row['duplicate_candidate_title']?.toString();
            final duplicateScore = _toDouble(row['duplicate_score']);
            final duplicateExactUrl = row['duplicate_exact_url'] == true;
            final strongDuplicate =
                (duplicateExactUrl && duplicateScore >= 0.55) ||
                duplicateScore >= 0.78;
            final mediumDuplicate = duplicateExactUrl || duplicateScore >= 0.50;
            final risk = strongDuplicate
                ? 'Alta'
                : mediumDuplicate
                    ? 'Media'
                    : 'Baja';
            final riskColor = strongDuplicate
                ? const Color(0xFFB43A46)
                : mediumDuplicate
                    ? const Color(0xFFC17A16)
                    : GratisCashTheme.greenDark;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            (row['title'] ?? 'Sin título').toString(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const StatusPill(
                          'En revisión',
                          active: false,
                          icon: Icons.schedule_rounded,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if ((row['image_url'] ?? '').toString().trim().isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.network(
                            row['image_url'].toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              color: const Color(0xFFF2F4F5),
                              alignment: Alignment.center,
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.broken_image_outlined,
                                    color: GratisCashTheme.muted,
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'No se ha podido cargar la imagen',
                                    style: TextStyle(
                                      color: GratisCashTheme.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Row(
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 16,
                            color: GratisCashTheme.muted,
                          ),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Imagen aportada por el usuario. Revísala antes de aprobar.',
                              style: TextStyle(
                                color: GratisCashTheme.muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 7),
                    Text(
                      '${row['source_name'] ?? ''} · ${row['reward_text'] ?? ''}',
                      style: const TextStyle(
                        color: GratisCashTheme.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (row['description'] ?? '').toString(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    SelectableText(
                      (row['source_url'] ?? '').toString(),
                      style: const TextStyle(
                        color: GratisCashTheme.greenDark,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9FA),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.copy_all_outlined, size: 18, color: riskColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              duplicateTitle == null
                                  ? 'Sin coincidencias relevantes detectadas'
                                  : duplicateExactUrl && duplicateScore < 0.55
                                      ? 'Misma página fuente, pero contenido posiblemente distinto: $duplicateTitle'
                                      : 'Posible parecido ($risk · ${(duplicateScore * 100).round()}%): $duplicateTitle',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                          if (duplicateId != null)
                            IconButton(
                              tooltip: 'Abrir candidata',
                              onPressed: () => context.push('/opportunity/$duplicateId'),
                              icon: const Icon(Icons.open_in_new_rounded, size: 19),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: id.isEmpty ? null : () => onModerate(id, 'active'),
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Aprobar'),
                        ),
                        OutlinedButton.icon(
                          onPressed: id.isEmpty ? null : () => onModerate(id, 'rejected'),
                          icon: const Icon(Icons.close_rounded),
                          label: const Text('Rechazar'),
                        ),
                        if (duplicateId != null && mediumDuplicate)
                          OutlinedButton.icon(
                            onPressed: id.isEmpty
                                ? null
                                : () => onModerate(
                                      id,
                                      'rejected',
                                      duplicateOf: duplicateId,
                                      defaultReason:
                                          'Ya existe una oportunidad equivalente publicada o en revisión.',
                                    ),
                            icon: const Icon(Icons.copy_rounded),
                            label: const Text('Marcar duplicada'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _PublishedTab extends StatelessWidget {
  const _PublishedTab({super.key, required this.onChanged});
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Opportunity>>(
      future: Services.repo.adminPublished(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'No se pueden cargar las publicadas',
            body: 'Comprueba la conexión con el backend.',
          );
        }
        final items = snapshot.data ?? <Opportunity>[];
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'Sin publicaciones',
            body: 'Publica la primera oportunidad desde Nueva.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 60),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    OpportunityImage(
                      item: item,
                      width: 92,
                      height: 84,
                      borderRadius: 14,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${item.rewardText} · ${item.sourceName}',
                            style: const TextStyle(
                              color: GratisCashTheme.muted,
                              fontSize: 12.5,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              StatusPill(
                                item.isExpired ? 'Terminada' : 'Activa',
                                active: !item.isExpired,
                              ),
                              if (item.isFeatured) ...[
                                const SizedBox(width: 6),
                                const StatusPill(
                                  'Destacada',
                                  icon: Icons.star_rounded,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Editar',
                      onPressed: () async {
                        await context.push('/admin/edit/${item.id}');
                        onChanged();
                      },
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ReportsTab extends StatelessWidget {
  const _ReportsTab({super.key, required this.onReview});
  final Future<void> Function(String id, String status) onReview;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Services.repo.reportsForAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'No se pueden cargar las denuncias',
            body: 'Comprueba la conexión con el backend.',
          );
        }
        final rows = snapshot.data ?? <Map<String, dynamic>>[];
        if (rows.isEmpty) {
          return const EmptyState(
            icon: Icons.verified_user_outlined,
            title: 'Sin denuncias abiertas',
            body: 'No hay contenido pendiente de revisión.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            final id = row['id']?.toString() ?? '';
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.flag_outlined, color: Color(0xFFC13A45)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            (row['reason'] ?? 'Sin motivo').toString(),
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tipo: ${_reportReasonLabel((row['reason_code'] ?? 'other').toString())}',
                      style: const TextStyle(color: GratisCashTheme.muted, fontSize: 12.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Objetivo: ${row['target_label'] ?? row['target_type'] ?? 'contenido'}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Reportado por ${row['reporter_name'] ?? 'usuario'} · Estado: ${row['status'] ?? 'open'}',
                      style: const TextStyle(color: GratisCashTheme.muted),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton(
                          onPressed: id.isEmpty ? null : () => onReview(id, 'resolved'),
                          child: const Text('Resolver'),
                        ),
                        OutlinedButton(
                          onPressed: id.isEmpty ? null : () => onReview(id, 'dismissed'),
                          child: const Text('Descartar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _UsersTab extends StatelessWidget {
  const _UsersTab({
    super.key,
    required this.onToggle,
    required this.onRole,
    required this.canManageRoles,
    required this.currentUserId,
  });

  final Future<void> Function(Map<String, dynamic> row) onToggle;
  final Future<void> Function(Map<String, dynamic> row, String role) onRole;
  final bool canManageRoles;
  final String? currentUserId;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: Services.repo.usersForAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'No se pueden cargar los usuarios',
            body: 'Comprueba la conexión con el backend.',
          );
        }
        final rows = snapshot.data ?? <Map<String, dynamic>>[];
        if (rows.isEmpty) {
          return const EmptyState(
            icon: Icons.people_outline_rounded,
            title: 'Sin usuarios',
            body: 'Todavía no hay cuentas registradas.',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            final suspended = row['is_suspended'] == true;
            final reports = row['open_report_count'] ?? 0;
            final role = (row['role'] ?? 'user').toString();
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: suspended
                      ? const Color(0xFFFFEAEC)
                      : const Color(0xFFE4F7EF),
                  child: Icon(
                    suspended ? Icons.person_off_outlined : Icons.person_outline_rounded,
                    color: suspended ? const Color(0xFFC13A45) : GratisCashTheme.greenDark,
                  ),
                ),
                title: Text(
                  (row['display_name'] ?? row['username'] ?? 'Usuario').toString(),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(
                  '@${row['username'] ?? 'usuario'} · $role · $reports denuncias abiertas',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (canManageRoles &&
                        row['id']?.toString() != currentUserId)
                      PopupMenuButton<String>(
                        tooltip: 'Cambiar rol',
                        onSelected: (value) => onRole(row, value),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'user',
                            enabled: role != 'user',
                            child: const Text('Usuario'),
                          ),
                          PopupMenuItem(
                            value: 'moderator',
                            enabled: role != 'moderator',
                            child: const Text('Moderador'),
                          ),
                          PopupMenuItem(
                            value: 'admin',
                            enabled: role != 'admin',
                            child: const Text('Administrador'),
                          ),
                        ],
                        icon: const Icon(Icons.admin_panel_settings_outlined),
                      ),
                    OutlinedButton(
                      onPressed: () => onToggle(row),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: suspended
                            ? GratisCashTheme.greenDark
                            : const Color(0xFF9A303A),
                      ),
                      child: Text(suspended ? 'Restaurar' : 'Suspender'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _AppealsTab extends StatelessWidget {
  const _AppealsTab({super.key, required this.onResolve});

  final Future<void> Function(ModerationAppeal appeal, String decision) onResolve;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ModerationAppeal>>(
      future: Services.repo.appealsForAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const EmptyState(
            icon: Icons.error_outline_rounded,
            title: 'No se pueden cargar las revisiones',
            body: 'Comprueba la conexión con el backend.',
          );
        }
        final items = snapshot.data ?? <ModerationAppeal>[];
        if (items.isEmpty) {
          return const EmptyState(
            icon: Icons.rate_review_outlined,
            title: 'Sin solicitudes abiertas',
            body: 'No hay decisiones de moderación pendientes de revisión.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.opportunityTitle ?? 'Oportunidad',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Solicitud de ${item.authorName ?? 'usuario'}',
                      style: const TextStyle(color: GratisCashTheme.muted),
                    ),
                    const SizedBox(height: 10),
                    Text(item.message, style: const TextStyle(height: 1.45)),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () => onResolve(item, 'reopen'),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reabrir'),
                        ),
                        OutlinedButton(
                          onPressed: () => onResolve(item, 'uphold'),
                          child: const Text('Confirmar decisión'),
                        ),
                        OutlinedButton(
                          onPressed: () => onResolve(item, 'dismiss'),
                          child: const Text('Descartar revisión'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

String _reportReasonLabel(String code) {
  return switch (code) {
    'ended' => 'Ya terminó',
    'broken_link' => 'Enlace roto',
    'misleading' => 'Información engañosa',
    'scam' => 'Posible estafa',
    'duplicate' => 'Duplicado',
    'spam' => 'Spam',
    'harassment' => 'Acoso o amenazas',
    'hate' => 'Odio o discriminación',
    'personal_data' => 'Datos personales',
    'illegal' => 'Contenido ilegal',
    _ => 'Otro',
  };
}

double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}


class _MetricsTab extends StatefulWidget {
  const _MetricsTab({
    super.key,
    required this.canEdit,
  });

  final bool canEdit;

  @override
  State<_MetricsTab> createState() => _MetricsTabState();
}

class _MetricsTabState extends State<_MetricsTab> {
  int _refreshKey = 0;

  Future<void> _editMonetization(Map<String, dynamic> row) async {
    if (!widget.canEdit) return;

    final network = TextEditingController(
      text: (row['monetization_network'] ?? '').toString(),
    );
    final commission = TextEditingController(
      text: row['commission_estimate'] == null
          ? ''
          : _toDouble(row['commission_estimate']).toStringAsFixed(2),
    );
    final conversions = TextEditingController(
      text: _toInt(row['conversions']).toString(),
    );
    final revenue = TextEditingController(
      text: _toDouble(row['revenue_total']).toStringAsFixed(2),
    );
    final currency = TextEditingController(
      text: (row['monetization_currency'] ?? 'EUR').toString(),
    );
    var model = (row['monetization_model'] ?? 'none').toString();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Monetización de la oportunidad'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: model,
                    decoration: const InputDecoration(labelText: 'Modelo'),
                    items: const [
                      DropdownMenuItem(value: 'none', child: Text('Sin monetizar')),
                      DropdownMenuItem(value: 'affiliate', child: Text('Afiliación')),
                      DropdownMenuItem(value: 'cpa', child: Text('CPA · adquisición')),
                      DropdownMenuItem(value: 'cpl', child: Text('CPL · lead')),
                      DropdownMenuItem(value: 'sponsored', child: Text('Patrocinada')),
                      DropdownMenuItem(value: 'direct', child: Text('Acuerdo directo')),
                    ],
                    onChanged: (value) {
                      if (value != null) setDialogState(() => model = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: network,
                    maxLength: 120,
                    decoration: const InputDecoration(
                      labelText: 'Red / programa',
                      hintText: 'Awin, Tradedoubler, Directo…',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: commission,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Comisión estimada'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 110,
                        child: TextField(
                          controller: currency,
                          maxLength: 3,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(labelText: 'Moneda', counterText: ''),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: conversions,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Conversiones'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: revenue,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Ingresos confirmados'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Datos privados. No modifican votos, ranking ni la selección editorial.',
                    style: TextStyle(color: GratisCashTheme.muted, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) {
      network.dispose(); commission.dispose(); conversions.dispose();
      revenue.dispose(); currency.dispose();
      return;
    }

    final parsedCommission = commission.text.trim().isEmpty
        ? null
        : double.tryParse(commission.text.trim().replaceAll(',', '.'));
    final parsedConversions = int.tryParse(conversions.text.trim()) ?? 0;
    final parsedRevenue = double.tryParse(revenue.text.trim().replaceAll(',', '.')) ?? 0;
    final parsedCurrency = currency.text.trim().toUpperCase();

    if ((commission.text.trim().isNotEmpty && parsedCommission == null) ||
        parsedConversions < 0 ||
        parsedRevenue < 0 ||
        !RegExp(r'^[A-Z]{3}$').hasMatch(parsedCurrency)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Revisa comisión, conversiones, ingresos y moneda.')),
        );
      }
      network.dispose(); commission.dispose(); conversions.dispose();
      revenue.dispose(); currency.dispose();
      return;
    }

    try {
      await Services.repo.saveOpportunityMonetization(
        opportunityId: row['opportunity_id'].toString(),
        model: model,
        network: network.text,
        commissionEstimate: parsedCommission,
        currency: parsedCurrency,
        conversions: parsedConversions,
        revenueTotal: parsedRevenue,
      );
      if (!mounted) return;
      setState(() => _refreshKey++);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Monetización actualizada.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(publicErrorMessage(error))),
        );
      }
    } finally {
      network.dispose(); commission.dispose(); conversions.dispose();
      revenue.dispose(); currency.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey(_refreshKey),
      future: Services.repo.opportunityMetricsForAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const EmptyState(
            icon: Icons.query_stats_rounded,
            title: 'No se pueden cargar las métricas',
            body: 'Estas métricas son internas y solo están disponibles para el equipo.',
          );
        }

        final rows = snapshot.data ?? <Map<String, dynamic>>[];
        if (rows.isEmpty) {
          return const EmptyState(
            icon: Icons.bar_chart_rounded,
            title: 'Todavía no hay datos',
            body: 'Los clics de salida aparecerán aquí cuando empiece a haber uso real.',
          );
        }

        final total30d = rows.fold<int>(0, (sum, row) => sum + _toInt(row['clicks_30d']));
        final conversions = rows.fold<int>(0, (sum, row) => sum + _toInt(row['conversions']));
        final revenueTotal = rows.fold<double>(0, (sum, row) => sum + _toDouble(row['revenue_total']));
        final monetized = rows.where((row) => (row['monetization_model'] ?? 'none').toString() != 'none').length;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricSummary(label: 'Salidas · 30 días', value: '$total30d', icon: Icons.open_in_new_rounded),
                _MetricSummary(label: 'Ingresos registrados', value: '${revenueTotal.toStringAsFixed(2)} €', icon: Icons.euro_rounded),
                _MetricSummary(label: 'Conversiones', value: '$conversions', icon: Icons.task_alt_rounded),
                _MetricSummary(label: 'Monetizadas', value: '$monetized / ${rows.length}', icon: Icons.payments_outlined),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text('Rendimiento por oportunidad', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                ),
                if (widget.canEdit)
                  const Text('Pulsa el lápiz para editar', style: TextStyle(color: GratisCashTheme.muted, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Los clics son orientativos. Conversiones e ingresos deben venir de datos confirmados por la red o acuerdo comercial.',
              style: TextStyle(color: GratisCashTheme.muted, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 12),
            for (final row in rows)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: (row['monetization_model'] ?? 'none') == 'none'
                        ? const Color(0xFFF0F2F4)
                        : const Color(0xFFEAF0FF),
                    child: Icon(
                      (row['monetization_model'] ?? 'none') == 'none' ? Icons.open_in_new_rounded : Icons.payments_outlined,
                      color: (row['monetization_model'] ?? 'none') == 'none' ? GratisCashTheme.muted : GratisCashTheme.blue,
                    ),
                  ),
                  title: Text(
                    (row['title'] ?? 'Oportunidad').toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  subtitle: Text(_monetizationSubtitle(row), maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: SizedBox(
                    width: widget.canEdit ? 150 : 92,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${_toInt(row['clicks_30d'])}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                            const Text('clics · 30 d', style: TextStyle(color: GratisCashTheme.muted, fontSize: 10.5)),
                          ],
                        ),
                        if (widget.canEdit) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            tooltip: 'Editar monetización',
                            onPressed: () => _editMonetization(row),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  String _monetizationSubtitle(Map<String, dynamic> row) {
    final model = (row['monetization_model'] ?? 'none').toString();
    final network = (row['monetization_network'] ?? '').toString().trim();
    final conversions = _toInt(row['conversions']);
    final revenue = _toDouble(row['revenue_total']);
    final currency = (row['monetization_currency'] ?? 'EUR').toString();
    final parts = <String>[
      _modelLabel(model),
      if (network.isNotEmpty) network,
      '$conversions conv.',
      '${revenue.toStringAsFixed(2)} $currency',
    ];
    return parts.join(' · ');
  }

  String _modelLabel(String value) => switch (value) {
        'affiliate' => 'Afiliación',
        'cpa' => 'CPA',
        'cpl' => 'CPL',
        'sponsored' => 'Patrocinada',
        'direct' => 'Directo',
        _ => 'Sin monetizar',
      };
}

class _MetricSummary extends StatelessWidget {
  const _MetricSummary({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GratisCashTheme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF0ECFF),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: GratisCashTheme.violet),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    color: GratisCashTheme.muted,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

int _toInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
