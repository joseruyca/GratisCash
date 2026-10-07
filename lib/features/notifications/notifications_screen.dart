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
    final savedIds = await Services.repo.savedIds();
    final now = DateTime.now();
    final notices = <_Notice>[];
    final alreadyAdded = <String>{};

    final endingSoon = items
        .where((item) => item.expiresAt != null)
        .where((item) {
          final days = item.expiresAt!.difference(now).inDays;
          return days >= 0 && days <= 14;
        })
        .toList()
      ..sort((a, b) {
        final aSaved = savedIds.contains(a.id);
        final bSaved = savedIds.contains(b.id);
        if (aSaved != bSaved) return aSaved ? -1 : 1;
        return a.expiresAt!.compareTo(b.expiresAt!);
      });

    for (final item in endingSoon) {
      final days = item.expiresAt!.difference(now).inDays;
      final saved = savedIds.contains(item.id);
      notices.add(
        _Notice(
          icon: saved ? Icons.bookmark_rounded : Icons.timer_outlined,
          title: saved
              ? (days == 0
                  ? 'Guardada · termina hoy'
                  : 'Guardada · termina en $days ${days == 1 ? 'día' : 'días'}')
              : (days == 0
                  ? 'Termina hoy'
                  : 'Termina en $days ${days == 1 ? 'día' : 'días'}'),
          body: item.title,
          opportunityId: item.id,
          tone: saved ? _NoticeTone.saved : _NoticeTone.urgent,
        ),
      );
      alreadyAdded.add(item.id);
    }

    final recent = items
        .where((item) => !alreadyAdded.contains(item.id))
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
                        Icon(
                          Icons.notifications_active_outlined,
                          color: GratisCashTheme.violet,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Aquí reunimos oportunidades nuevas y avisos de fecha límite. Si has guardado una oportunidad, sus avisos aparecen primero.',
                            style: TextStyle(
                              color: GratisCashTheme.muted,
                              height: 1.45,
                            ),
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
                                    color: switch (notice.tone) {
                                      _NoticeTone.urgent => const Color(0xFFFFF0E8),
                                      _NoticeTone.saved => const Color(0xFFF0ECFF),
                                      _NoticeTone.normal => const Color(0xFFEAF0FF),
                                    },
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    notice.icon,
                                    color: switch (notice.tone) {
                                      _NoticeTone.urgent => const Color(0xFFC65A23),
                                      _NoticeTone.saved => GratisCashTheme.violet,
                                      _NoticeTone.normal => GratisCashTheme.blue,
                                    },
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

enum _NoticeTone { normal, urgent, saved }

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
