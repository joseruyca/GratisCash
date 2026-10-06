import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_error.dart';
import '../../core/services.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

class FinishedScreen extends StatefulWidget {
  const FinishedScreen({super.key});

  @override
  State<FinishedScreen> createState() => _FinishedScreenState();
}

class _FinishedScreenState extends State<FinishedScreen> {
  OpportunityCategory? _category;
  String _filter = 'Todas';

  Future<List<Opportunity>> _load() async {
    final all = await Services.repo.listOpportunities(includeExpired: true);
    var items = all.where((item) => item.isExpired).toList();
    if (_category != null) {
      items = items.where((item) => item.category == _category).toList();
    }
    if (_filter == 'Últimos 30 días') {
      final cutoff = DateTime.now().subtract(const Duration(days: 30));
      items = items.where((item) => item.expiresAt?.isAfter(cutoff) ?? false).toList();
    } else if (_filter == 'Más votadas') {
      items.sort((a, b) => b.upvotes.compareTo(a.upvotes));
    } else {
      items.sort((a, b) {
        final da = a.expiresAt ?? a.createdAt;
        final db = b.expiresAt ?? b.createdAt;
        return db.compareTo(da);
      });
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terminadas')),
      body: FutureBuilder<List<Opportunity>>(
        future: _load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyState(icon: Icons.cloud_off_outlined, title: 'No se puede cargar el histórico', body: publicErrorMessage(snapshot.error));
          }
          final items = snapshot.data ?? <Opportunity>[];
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Lo que terminó no desaparece', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                      const SizedBox(height: 6),
                      const Text('Conservamos las oportunidades cerradas para que puedas consultar condiciones, fechas y lo que te perdiste.', style: TextStyle(color: GratisCashTheme.muted, height: 1.4)),
                      const SizedBox(height: 14),
                      SurfaceCard(
                        child: Row(
                          children: [
                            Container(width: 44, height: 44, decoration: const BoxDecoration(color: Color(0xFFE5F7F0), shape: BoxShape.circle), child: const Icon(Icons.history_rounded, color: GratisCashTheme.green)),
                            const SizedBox(width: 12),
                            Expanded(child: Text('${items.length} ${items.length == 1 ? 'oportunidad terminada' : 'oportunidades terminadas'}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final label in const ['Todas', 'Últimos 30 días', 'Más votadas'])
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(label: Text(label), selected: _filter == label, onSelected: (_) => setState(() => _filter = label)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(label: const Text('Todas las categorías'), selected: _category == null, onSelected: (_) => setState(() => _category = null)),
                            ),
                            for (final category in OpportunityCategory.values)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(label: Text(category.label), selected: _category == category, onSelected: (_) => setState(() => _category = category)),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (items.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(icon: Icons.history_toggle_off_rounded, title: 'Nada por aquí', body: 'No hay oportunidades terminadas con estos filtros.'),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                  sliver: SliverList.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) => OpportunityCard(
                      item: items[index],
                      showStatus: true,
                      onTap: () => context.go('/opportunity/${items[index].id}'),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
