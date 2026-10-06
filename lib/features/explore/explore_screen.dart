import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_error.dart';
import '../../core/services.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _query = TextEditingController();
  OpportunityCategory? _category;
  bool _endingSoon = false;
  int _refreshKey = 0;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<List<Opportunity>> _load() async {
    final items = await Services.repo.listOpportunities(
      category: _category,
      query: _query.text,
    );
    if (_endingSoon) {
      items.removeWhere((item) => item.expiresAt == null);
      items.sort((a, b) => a.expiresAt!.compareTo(b.expiresAt!));
    }
    return items;
  }

  void _search() {
    _debounce?.cancel();
    setState(() => _refreshKey++);
  }

  void _onQueryChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _search();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explorar'),
        actions: [
          TextButton.icon(
            onPressed: () => context.go('/finished'),
            icon: const Icon(Icons.history_rounded),
            label: const Text('Terminadas'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: TextField(
              controller: _query,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              onChanged: _onQueryChanged,
              decoration: InputDecoration(
                hintText: 'Buscar oportunidades, marcas o recompensas…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Borrar',
                        onPressed: () {
                          _query.clear();
                          _search();
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                _chip(null, 'Todo'),
                for (final item in OpportunityCategory.values)
                  _chip(item, item.label),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
                  child: FilterChip(
                    avatar: const Icon(Icons.timer_outlined, size: 17),
                    label: const Text('Terminan pronto'),
                    selected: _endingSoon,
                    onSelected: (value) {
                      setState(() {
                        _endingSoon = value;
                        _refreshKey++;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Opportunity>>(
              key: ValueKey(_refreshKey),
              future: _load(),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return EmptyState(
                    icon: Icons.cloud_off_outlined,
                    title: 'No podemos buscar ahora',
                    body: publicErrorMessage(snapshot.error),
                    action: FilledButton.icon(
                      onPressed: _search,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Reintentar'),
                    ),
                  );
                }

                final items = snapshot.data ?? <Opportunity>[];
                if (items.isEmpty) {
                  return EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Sin resultados',
                    body: _query.text.trim().isEmpty
                        ? 'No hay oportunidades para estos filtros.'
                        : 'Prueba con otra búsqueda o elimina algún filtro.',
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                      child: Row(
                        children: [
                          Text(
                            '${items.length} ${items.length == 1 ? 'resultado' : 'resultados'}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: GratisCashTheme.dark,
                            ),
                          ),
                          const Spacer(),
                          if (_query.text.trim().isNotEmpty || _category != null || _endingSoon)
                            TextButton(
                              onPressed: () {
                                _query.clear();
                                setState(() {
                                  _category = null;
                                  _endingSoon = false;
                                  _refreshKey++;
                                });
                              },
                              child: const Text('Limpiar filtros'),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return OpportunityCard(
                            item: item,
                            onTap: () => context.go('/opportunity/${item.id}'),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(OpportunityCategory? category, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      child: ChoiceChip(
        label: Text(label),
        selected: _category == category,
        onSelected: (_) {
          setState(() {
            _category = category;
            _refreshKey++;
          });
        },
      ),
    );
  }
}
