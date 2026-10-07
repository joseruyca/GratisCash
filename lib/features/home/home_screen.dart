import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_guard.dart';
import '../../core/app_error.dart';
import '../../core/services.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  OpportunityCategory? _category;
  String _sort = 'Destacados';
  int _refreshKey = 0;

  Future<_HomeData> _load() async {
    final items = await Services.repo.listOpportunities(category: _category);
    final saved = await Services.repo.savedIds();

    if (_sort == 'Más votados') {
      items.sort((a, b) => b.upvotes.compareTo(a.upvotes));
    } else if (_sort == 'Nuevos') {
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } else if (_sort == 'Terminan pronto') {
      items.sort((a, b) {
        final aEnd = a.expiresAt ?? DateTime(2999);
        final bEnd = b.expiresAt ?? DateTime(2999);
        return aEnd.compareTo(bEnd);
      });
    } else if (_sort == 'Subiendo') {
      items.sort((a, b) {
        final scoreA = a.upvotes * 3 + a.comments;
        final scoreB = b.upvotes * 3 + b.comments;
        final byScore = scoreB.compareTo(scoreA);
        return byScore != 0 ? byScore : b.createdAt.compareTo(a.createdAt);
      });
    } else {
      items.sort((a, b) {
        if (a.isFeatured != b.isFeatured) {
          return a.isFeatured ? -1 : 1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
    }

    final all = await Services.repo.listOpportunities(includeExpired: true);
    final expiredCount = all.where((item) => item.isExpired).length;
    return _HomeData(
      items: items,
      savedIds: saved,
      activeCount: all.where((item) => !item.isExpired).length,
      expiredCount: expiredCount,
    );
  }

  void _refresh() {
    setState(() => _refreshKey++);
  }

  Future<void> _vote(String id) async {
    final allowed = await ensureSignedIn(
      context,
      message: 'Inicia sesión para votar oportunidades.',
    );
    if (!allowed || !mounted) {
      return;
    }
    try {
      await Services.repo.toggleVote(id);
      _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(publicErrorMessage(error))),
      );
    }
  }

  Future<void> _save(String id) async {
    final allowed = await ensureSignedIn(
      context,
      message: 'Inicia sesión para guardar oportunidades.',
    );
    if (!allowed || !mounted) {
      return;
    }
    try {
      await Services.repo.toggleSaved(id);
      _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(publicErrorMessage(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loadKey = _refreshKey;
    final compactHeader = MediaQuery.sizeOf(context).width < 560;

    return Scaffold(
      appBar: AppBar(
        title: const GratisCashLogo(),
        actions: [
          IconButton(
            tooltip: 'Buscar',
            onPressed: () => context.go('/explore'),
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            tooltip: 'Novedades',
            onPressed: () => context.push('/notifications'),
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          if (!compactHeader)
            IconButton(
              tooltip: 'Terminadas',
              onPressed: () => context.go('/finished'),
              icon: const Icon(Icons.history_rounded),
            ),
          if (!compactHeader)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: IconButton.filled(
                tooltip: 'Publicar',
                onPressed: () => context.go('/submit'),
                icon: const Icon(Icons.add_rounded),
              ),
            )
          else
            const SizedBox(width: 6),
        ],
      ),
      body: FutureBuilder<_HomeData>(
        key: ValueKey(loadKey),
        future: _load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'No hemos podido cargar el feed',
              body: publicErrorMessage(snapshot.error),
              action: FilledButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            );
          }

          final data = snapshot.data ??
              const _HomeData(
                items: <Opportunity>[],
                savedIds: <String>{},
                activeCount: 0,
                expiredCount: 0,
              );

          return LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 1040;
              final feed = _Feed(
                data: data,
                category: _category,
                sort: _sort,
                onCategory: (value) => setState(() => _category = value),
                onSort: (value) => setState(() => _sort = value),
                onRefresh: () async => _refresh(),
                onVote: _vote,
                onSave: _save,
              );

              if (!desktop) {
                return feed;
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: feed),
                  const SizedBox(width: 18),
                  SizedBox(
                    width: 276,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 12, 100),
                      child: _DesktopAside(data: data),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _Feed extends StatelessWidget {
  const _Feed({
    required this.data,
    required this.category,
    required this.sort,
    required this.onCategory,
    required this.onSort,
    required this.onRefresh,
    required this.onVote,
    required this.onSave,
  });

  final _HomeData data;
  final OpportunityCategory? category;
  final String sort;
  final ValueChanged<OpportunityCategory?> onCategory;
  final ValueChanged<String> onSort;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String id) onVote;
  final Future<void> Function(String id) onSave;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: _TodayStrip(
                activeCount: data.activeCount,
                expiredCount: data.expiredCount,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
              child: _SortBar(value: sort, onChanged: onSort),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 54,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  _CategoryChoice(
                    label: 'Todos',
                    selected: category == null,
                    onTap: () => onCategory(null),
                  ),
                  for (final item in OpportunityCategory.values)
                    _CategoryChoice(
                      label: item.label,
                      selected: category == item,
                      onTap: () => onCategory(item),
                    ),
                ],
              ),
            ),
          ),
          if (data.items.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.inbox_outlined,
                title: 'No hay oportunidades activas',
                body: 'Prueba otra categoría o vuelve más tarde.',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
              sliver: SliverList.builder(
                itemCount: data.items.length,
                itemBuilder: (context, index) {
                  final item = data.items[index];
                  return OpportunityCard(
                    item: item,
                    saved: data.savedIds.contains(item.id),
                    onTap: () => context.go('/opportunity/${item.id}'),
                    onVote: () => onVote(item.id),
                    onSave: () => onSave(item.id),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}


class _TodayStrip extends StatelessWidget {
  const _TodayStrip({required this.activeCount, required this.expiredCount});

  final int activeCount;
  final int expiredCount;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 560;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: narrow ? 14 : 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF8F2), Color(0xFFF8FCFA)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD8EEE5)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.bolt_rounded, color: GratisCashTheme.green),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$activeCount oportunidades activas',
                  style: TextStyle(
                    fontSize: narrow ? 16 : 17,
                    fontWeight: FontWeight.w900,
                    color: GratisCashTheme.dark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  narrow
                      ? 'Revisadas y ordenadas para descubrir algo útil hoy.'
                      : 'Descubre estudios, pruebas, cashback, bonus y misiones sin perder tiempo.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: GratisCashTheme.muted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          if (!narrow) ...[
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: () => context.go('/finished'),
              icon: const Icon(Icons.history_rounded, size: 18),
              label: Text('$expiredCount terminadas'),
            ),
            const SizedBox(width: 4),
            OutlinedButton(
              onPressed: () => context.push('/legal/how'),
              child: const Text('Cómo funciona'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DesktopAside extends StatelessWidget {
  const _DesktopAside({required this.data});

  final _HomeData data;

  @override
  Widget build(BuildContext context) {
    final soon = data.items
        .where((item) => item.expiresAt != null)
        .toList()
      ..sort((a, b) => a.expiresAt!.compareTo(b.expiresAt!));

    return Column(
      children: [
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ahora en GratisCash',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              _AsideStat(
                icon: Icons.bolt_rounded,
                value: '${data.activeCount}',
                label: 'oportunidades activas',
              ),
              const SizedBox(height: 12),
              _AsideStat(
                icon: Icons.history_rounded,
                value: '${data.expiredCount}',
                label: 'en el histórico',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Terminan pronto',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/explore'),
                    child: const Text('Ver todo'),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (final item in soon.take(3))
                InkWell(
                  onTap: () => context.go('/opportunity/${item.id}'),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${item.expiresAt!.day}/${item.expiresAt!.month}',
                          style: const TextStyle(
                            color: GratisCashTheme.muted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Has encontrado algo?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              const Text(
                'Compártelo con la comunidad. Antes de publicarse pasará por revisión.',
                style: TextStyle(color: GratisCashTheme.muted, height: 1.4),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.go('/submit'),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Publicar oportunidad'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AsideStat extends StatelessWidget {
  const _AsideStat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            color: Color(0xFFE7F7F1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: GratisCashTheme.green, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: [
                TextSpan(
                  text: '$value ',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                TextSpan(
                  text: label,
                  style: const TextStyle(color: GratisCashTheme.muted),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SortBar extends StatelessWidget {
  const _SortBar({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const values = <String>[
    'Destacados',
    'Más votados',
    'Subiendo',
    'Nuevos',
    'Terminan pronto',
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: values.length,
        separatorBuilder: (context, index) => const SizedBox(width: 20),
        itemBuilder: (context, index) {
          final item = values[index];
          final selected = item == value;
          return InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onChanged(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 11),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item,
                    style: TextStyle(
                      color: selected ? GratisCashTheme.greenDark : GratisCashTheme.muted,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 7),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: selected ? 42 : 0,
                    height: 2.5,
                    decoration: BoxDecoration(
                      color: GratisCashTheme.green,
                      borderRadius: BorderRadius.circular(999),
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

class _CategoryChoice extends StatelessWidget {
  const _CategoryChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _HomeData {
  const _HomeData({
    required this.items,
    required this.savedIds,
    required this.activeCount,
    required this.expiredCount,
  });

  final List<Opportunity> items;
  final Set<String> savedIds;
  final int activeCount;
  final int expiredCount;
}
