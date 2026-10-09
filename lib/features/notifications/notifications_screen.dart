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
    final signedIn = Services.signedIn;
    final savedIds = await Services.repo.savedIds();
    final preferences = signedIn
        ? await Services.repo.notificationPreferences()
        : const NotificationPreferences();
    final submissions = signedIn && preferences.includeSubmissionUpdates
        ? await Services.repo.mySubmissions()
        : <Opportunity>[];

    final now = DateTime.now();
    final notices = <_Notice>[];
    final alreadyAdded = <String>{};

    if (signedIn && preferences.includeSubmissionUpdates) {
      final recentSubmissions = submissions
          .where((item) => now.difference(item.createdAt).inDays <= 30)
          .take(8);

      for (final item in recentSubmissions) {
        switch (item.status) {
          case OpportunityStatus.active:
            notices.add(
              _Notice(
                icon: Icons.check_circle_outline_rounded,
                title: 'Tu publicación ya está activa',
                body: item.title,
                route: '/opportunity/${item.id}',
                tone: _NoticeTone.success,
              ),
            );
            alreadyAdded.add(item.id);
            break;
          case OpportunityStatus.pending:
            notices.add(
              _Notice(
                icon: Icons.hourglass_top_rounded,
                title: 'Tu publicación está en revisión',
                body: item.title,
                route: '/profile',
                tone: _NoticeTone.review,
              ),
            );
            break;
          case OpportunityStatus.rejected:
            notices.add(
              _Notice(
                icon: Icons.info_outline_rounded,
                title: 'Tu publicación necesita atención',
                body: item.title,
                route: '/profile',
                tone: _NoticeTone.urgent,
              ),
            );
            break;
          case OpportunityStatus.expired:
          case OpportunityStatus.draft:
            break;
        }
      }
    }

    if (!signedIn) {
      final endingSoon = items
          .where((item) => item.expiresAt != null)
          .where((item) {
            final days = item.expiresAt!.difference(now).inDays;
            return days >= 0 && days <= 14;
          })
          .toList()
        ..sort((a, b) => a.expiresAt!.compareTo(b.expiresAt!));

      for (final item in endingSoon.take(5)) {
        final days = item.expiresAt!.difference(now).inDays;
        notices.add(
          _Notice(
            icon: Icons.timer_outlined,
            title: days == 0
                ? 'Termina hoy'
                : 'Termina en $days ${days == 1 ? 'día' : 'días'}',
            body: item.title,
            route: '/opportunity/${item.id}',
            tone: _NoticeTone.urgent,
          ),
        );
        alreadyAdded.add(item.id);
      }
    } else if (preferences.includeSavedDeadlines) {
      final endingSaved = items
          .where((item) => savedIds.contains(item.id))
          .where((item) => item.expiresAt != null)
          .where((item) {
            final days = item.expiresAt!.difference(now).inDays;
            return days >= 0 && days <= 14;
          })
          .toList()
        ..sort((a, b) => a.expiresAt!.compareTo(b.expiresAt!));

      for (final item in endingSaved) {
        final days = item.expiresAt!.difference(now).inDays;
        notices.add(
          _Notice(
            icon: Icons.bookmark_rounded,
            title: days == 0
                ? 'Guardada · termina hoy'
                : 'Guardada · termina en $days ${days == 1 ? 'día' : 'días'}',
            body: item.title,
            route: '/opportunity/${item.id}',
            tone: _NoticeTone.saved,
          ),
        );
        alreadyAdded.add(item.id);
      }
    }

    if (preferences.includeNew) {
      final recent = items
          .where((item) => !alreadyAdded.contains(item.id))
          .where((item) => preferences.follows(item.category))
          .where((item) => now.difference(item.createdAt).inDays <= 7)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      for (final item in recent.take(10)) {
        notices.add(
          _Notice(
            icon: Icons.auto_awesome_outlined,
            title: 'Nueva · ${item.category.label}',
            body: item.title,
            route: '/opportunity/${item.id}',
            tone: _NoticeTone.normal,
          ),
        );
      }
    }

    return notices;
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novedades'),
        actions: [
          if (Services.signedIn)
            IconButton(
              tooltip: 'Personalizar novedades',
              onPressed: () => context.push('/settings/following'),
              icon: const Icon(Icons.tune_rounded),
            ),
          const SizedBox(width: 6),
        ],
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
                  SurfaceCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.notifications_active_outlined,
                          color: GratisCashTheme.violet,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            Services.signedIn
                                ? 'Tus novedades combinan lo que sigues, tus guardadas y el estado de tus publicaciones.'
                                : 'Aquí reunimos oportunidades nuevas y las que están a punto de terminar.',
                            style: const TextStyle(
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
                          onTap: () => context.go(notice.route),
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
                                      _NoticeTone.success => const Color(0xFFE5F7F0),
                                      _NoticeTone.review => const Color(0xFFFFF3D9),
                                    },
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    notice.icon,
                                    color: switch (notice.tone) {
                                      _NoticeTone.urgent => const Color(0xFFC65A23),
                                      _NoticeTone.saved => GratisCashTheme.violet,
                                      _NoticeTone.normal => GratisCashTheme.blue,
                                      _NoticeTone.success => GratisCashTheme.greenDark,
                                      _NoticeTone.review => GratisCashTheme.amber,
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

enum _NoticeTone { normal, urgent, saved, success, review }

class _Notice {
  const _Notice({
    required this.icon,
    required this.title,
    required this.body,
    required this.route,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String body;
  final String route;
  final _NoticeTone tone;
}
