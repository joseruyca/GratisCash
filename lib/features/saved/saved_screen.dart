import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_error.dart';
import '../../core/services.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  int _refreshKey = 0;

  Future<List<Opportunity>> _load() => Services.repo.savedOpportunities();

  Future<void> _remove(String id) async {
    try {
      await Services.repo.toggleSaved(id);
      if (mounted) setState(() => _refreshKey++);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(publicErrorMessage(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Services.signedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Guardadas')),
        body: EmptyState(
          icon: Icons.bookmark_border_rounded,
          title: 'Guarda oportunidades para volver luego',
          body: 'Inicia sesión para sincronizar tus guardadas de forma segura entre web y app.',
          action: FilledButton(onPressed: () => context.push('/auth'), child: const Text('Iniciar sesión')),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Guardadas')),
      body: FutureBuilder<List<Opportunity>>(
        key: ValueKey(_refreshKey),
        future: _load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'No podemos cargar tus guardadas',
              body: publicErrorMessage(snapshot.error),
              action: FilledButton.icon(
                onPressed: () => setState(() => _refreshKey++),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            );
          }
          final items = snapshot.data ?? <Opportunity>[];
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.bookmark_border_rounded,
              title: 'Todavía no has guardado nada',
              body: 'Pulsa el marcador de cualquier oportunidad y aparecerá aquí.',
              action: OutlinedButton(onPressed: () => context.go('/'), child: const Text('Explorar oportunidades')),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 100),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return OpportunityCard(
                item: item,
                saved: true,
                showStatus: item.isExpired,
                onTap: () => context.go('/opportunity/${item.id}'),
                onSave: () => _remove(item.id),
              );
            },
          );
        },
      ),
    );
  }
}
