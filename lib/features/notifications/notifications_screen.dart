import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_error.dart';
import '../../core/services.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  Future<List<_Notice>> _load() async {
    final items = await Services.repo.listOpportunities();
    final now = DateTime.now();
    final notices = <_Notice>[];

    final endingSoon = items
        .where((item) => item.expiresAt != null)
        .where((item) {
          final days = item.expiresAt!.difference(now).inDays;
          return days >= 0 && days <= 14;
        })
        .toList()
      ..sort((a, b) => a.expiresAt!.compareTo(b.expiresAt!));

    for (final item in endingSoon) {
      final days = item.expiresAt!.difference(now).inDays;
      notices.add(
        _Notice(
          icon: Icons.timer_outlined,
          title: days == 0 ? 'Termina hoy' : 'Termina en $days ${days == 1 ? 'día' : 'días'}',
          body: item.title,
          opportunityId: item.id,
          tone: _NoticeTone.urgent,
        ),
      );
    }

    final recent = items
        .where((item) => now.difference(item.createdAt).inDays <= 7)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    for (final item in recent.take(8)) {
      notices.add(
        _Notice(
          icon: Icons.auto_awesome_outlined,
          title: 'Nueva oportunidad',
          body: item.title,
          opportunityId: item.id,
          tone: _NoticeTone.normal,
        ),
      );
    }

    return notices;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novedades'),
      ),
      body: FutureBuilder<List<_Notice>>(
        future: _load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.notifications_off_outlined,
              title: 'No podemos cargar las novedades',
              body: publicErrorMessage(snapshot.error),
            );
          }

          final notices = snapshot.data ?? const <_Notice>[];
          if (notices.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Todo al día',
              body: 'Cuando haya oportunidades nuevas o alguna esté a punto de terminar, aparecerá aquí.',
            );
          }

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                children: [
                  const SurfaceCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded, color: GratisCashTheme.green),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Este centro solo muestra avisos basados en oportunidades reales publicadas en GratisCash. Las notificaciones push se activarán únicamente cuando configuremos Android/iOS en producción.',
                            style: TextStyle(color: GratisCashTheme.muted, height: 1.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final notice in notices)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Card(
                        child: InkWell(
                          onTap: () => context.go('/opportunity/${notice.opportunityId}'),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: notice.tone == _NoticeTone.urgent
                                        ? const Color(0xFFFFF0E8)
                                        : const Color(0xFFE6F7F0),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    notice.icon,
                                    color: notice.tone == _NoticeTone.urgent
                                        ? const Color(0xFFC65A23)
                                        : GratisCashTheme.green,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        notice.title,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: GratisCashTheme.dark,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        notice.body,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: GratisCashTheme.muted,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: GratisCashTheme.muted),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

enum _NoticeTone { normal, urgent }

class _Notice {
  const _Notice({
    required this.icon,
    required this.title,
    required this.body,
    required this.opportunityId,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String body;
  final String opportunityId;
  final _NoticeTone tone;
}
