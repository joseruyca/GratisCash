import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_error.dart';
import '../../core/services.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  bool _loading = true;
  bool _saving = false;
  Set<OpportunityCategory> _categories = <OpportunityCategory>{};
  bool _includeNew = true;
  bool _includeSavedDeadlines = true;
  bool _includeSubmissionUpdates = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await Services.repo.notificationPreferences();
      if (!mounted) return;
      setState(() {
        _categories = {...prefs.categories};
        _includeNew = prefs.includeNew;
        _includeSavedDeadlines = prefs.includeSavedDeadlines;
        _includeSubmissionUpdates = prefs.includeSubmissionUpdates;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(publicErrorMessage(error))),
      );
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await Services.repo.saveNotificationPreferences(
        NotificationPreferences(
          categories: _categories,
          includeNew: _includeNew,
          includeSavedDeadlines: _includeSavedDeadlines,
          includeSubmissionUpdates: _includeSubmissionUpdates,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferencias guardadas.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(publicErrorMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Services.signedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Qué quieres seguir')),
        body: EmptyState(
          icon: Icons.notifications_none_rounded,
          title: 'Inicia sesión para personalizar',
          body: 'Tus categorías y avisos se guardan en tu cuenta para mantenerlos entre web y app.',
          action: FilledButton(
            onPressed: () => context.push('/auth'),
            child: const Text('Iniciar sesión'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Qué quieres seguir')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
                  children: [
                    const SurfaceCard(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.auto_awesome_outlined,
                            color: GratisCashTheme.violet,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Personaliza Novedades para ver primero lo que realmente te interesa. Si no eliges categorías, seguiremos todas.',
                              style: TextStyle(
                                color: GratisCashTheme.muted,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Categorías',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final category in OpportunityCategory.values)
                          FilterChip(
                            label: Text(category.label),
                            selected: _categories.contains(category),
                            selectedColor: categoryColor(category),
                            checkmarkColor: categoryAccent(category),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _categories.add(category);
                                } else {
                                  _categories.remove(category);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Ninguna seleccionada = todas las categorías.',
                      style: TextStyle(
                        color: GratisCashTheme.muted,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SurfaceCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          SwitchListTile(
                            value: _includeNew,
                            onChanged: (value) =>
                                setState(() => _includeNew = value),
                            title: const Text(
                              'Nuevas oportunidades',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: const Text(
                              'Muestra novedades de las categorías que sigues.',
                            ),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            value: _includeSavedDeadlines,
                            onChanged: (value) => setState(
                              () => _includeSavedDeadlines = value,
                            ),
                            title: const Text(
                              'Guardadas que terminan pronto',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: const Text(
                              'Prioriza lo que guardaste antes de que caduque.',
                            ),
                          ),
                          const Divider(height: 1),
                          SwitchListTile(
                            value: _includeSubmissionUpdates,
                            onChanged: (value) => setState(
                              () => _includeSubmissionUpdates = value,
                            ),
                            title: const Text(
                              'Estado de tus publicaciones',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle: const Text(
                              'Aprobadas, en revisión o rechazadas.',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(_saving ? 'Guardando…' : 'Guardar preferencias'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
