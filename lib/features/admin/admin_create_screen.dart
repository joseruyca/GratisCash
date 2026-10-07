import 'package:flutter/material.dart';

import '../../core/app_error.dart';
import '../../core/services.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

class AdminCreateScreen extends StatefulWidget {
  const AdminCreateScreen({super.key, this.opportunityId});

  final String? opportunityId;

  @override
  State<AdminCreateScreen> createState() => _AdminCreateScreenState();
}

class _AdminCreateScreenState extends State<AdminCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _source = TextEditingController();
  final _sourceUrl = TextEditingController();
  final _affiliateUrl = TextEditingController();
  final _reward = TextEditingController();
  final _requirements = TextEditingController();
  final _minutes = TextEditingController();
  final _imageUrl = TextEditingController();
  final _photoCredit = TextEditingController();
  final _photoSourceUrl = TextEditingController();
  final _sponsorName = TextEditingController();

  OpportunityCategory _category = OpportunityCategory.freeProduct;
  DateTime? _expiresAt;
  DateTime? _sponsoredFrom;
  DateTime? _sponsoredUntil;
  bool _featured = false;
  bool _sponsored = false;
  bool _busy = false;
  bool _loading = false;

  bool get _editing => widget.opportunityId != null;

  @override
  void initState() {
    super.initState();
    if (_editing) _loadExisting();
  }

  Future<void> _loadExisting() async {
    setState(() => _loading = true);
    try {
      final rows = await Services.repo.adminPublished();
      Opportunity? item;
      for (final row in rows) {
        if (row.id == widget.opportunityId) {
          item = row;
          break;
        }
      }
      if (item == null) throw StateError('No se encuentra la oportunidad.');
      _title.text = item.title;
      _description.text = item.description;
      _source.text = item.sourceName;
      _sourceUrl.text = item.sourceUrl;
      _affiliateUrl.text = item.affiliateUrl ?? '';
      _reward.text = item.rewardText;
      _requirements.text = item.requirements ?? '';
      _minutes.text = item.estimatedMinutes?.toString() ?? '';
      _imageUrl.text = item.imageUrl ?? '';
      _photoCredit.text = item.photoCredit ?? '';
      _photoSourceUrl.text = item.photoSourceUrl ?? '';
      _category = item.category;
      _expiresAt = item.expiresAt;
      _featured = item.isFeatured;
      _sponsored = item.isSponsored;
      _sponsorName.text = item.sponsorName ?? '';
      _sponsoredFrom = item.sponsoredFrom;
      _sponsoredUntil = item.sponsoredUntil;
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(publicErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    for (final controller in [_title, _description, _source, _sourceUrl, _affiliateUrl, _reward, _requirements, _minutes, _imageUrl, _photoCredit, _photoSourceUrl, _sponsorName]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'Obligatorio' : null;

  bool _validHttps(String value, {bool optional = false}) {
    final text = value.trim();
    if (optional && text.isEmpty) return true;
    final uri = Uri.tryParse(text);
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  Future<DateTime?> _pickCampaignDate(DateTime? current) async {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 3650)),
      lastDate: now.add(const Duration(days: 3650)),
      initialDate: current ?? now,
    );
  }

  String _dateLabel(DateTime? value, String empty) {
    if (value == null) return empty;
    return '${value.day}/${value.month}/${value.year}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final value = await showDatePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 3650)),
      lastDate: now.add(const Duration(days: 3650)),
      initialDate: _expiresAt ?? now.add(const Duration(days: 14)),
    );
    if (mounted && value != null) setState(() => _expiresAt = value);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_validHttps(_sourceUrl.text)) {
      _urlError('La URL oficial debe ser HTTPS.');
      return;
    }
    if (!_validHttps(_affiliateUrl.text, optional: true)) {
      _urlError('La URL de afiliado debe ser HTTPS.');
      return;
    }
    if (!_validHttps(_imageUrl.text, optional: true)) {
      _urlError('La URL de imagen debe ser HTTPS.');
      return;
    }
    if (!_validHttps(_photoSourceUrl.text, optional: true)) {
      _urlError('La fuente de la imagen debe ser HTTPS.');
      return;
    }

    if (_imageUrl.text.trim().isNotEmpty && _photoCredit.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Indica el crédito/licencia de la imagen.')));
      return;
    }

    if (_sponsored && _sponsorName.text.trim().isEmpty) {
      _urlError('Indica el nombre de la marca o patrocinador.');
      return;
    }
    if (_sponsored &&
        _sponsoredFrom != null &&
        _sponsoredUntil != null &&
        !_sponsoredUntil!.isAfter(_sponsoredFrom!)) {
      _urlError('El final de la campaña debe ser posterior al inicio.');
      return;
    }

    final data = <String, dynamic>{
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'source_name': _source.text.trim(),
      'source_url': _sourceUrl.text.trim(),
      'affiliate_url': _affiliateUrl.text.trim().isEmpty ? null : _affiliateUrl.text.trim(),
      'reward_text': _reward.text.trim(),
      'category': _category.name,
      'expires_at': _expiresAt?.toUtc().toIso8601String(),
      'estimated_minutes': int.tryParse(_minutes.text.trim()),
      'requirements': _requirements.text.trim().isEmpty ? null : _requirements.text.trim(),
      'image_url': _imageUrl.text.trim().isEmpty ? null : _imageUrl.text.trim(),
      'photo_credit': _photoCredit.text.trim().isEmpty ? null : _photoCredit.text.trim(),
      'photo_source_url': _photoSourceUrl.text.trim().isEmpty ? null : _photoSourceUrl.text.trim(),
      'is_featured': _featured,
      'is_sponsored': _sponsored,
      'sponsor_name': _sponsored ? _sponsorName.text.trim() : null,
      'sponsored_from':
          _sponsored ? _sponsoredFrom?.toUtc().toIso8601String() : null,
      'sponsored_until':
          _sponsored ? _sponsoredUntil?.toUtc().toIso8601String() : null,
    };

    setState(() => _busy = true);
    try {
      if (_editing) {
        await Services.repo.adminUpdateOpportunity(widget.opportunityId!, data);
      } else {
        await Services.repo.adminCreateOpportunity(data);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_editing ? 'Oportunidad actualizada.' : 'Oportunidad publicada.')));
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(publicErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _urlError(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Editar oportunidad' : 'Nueva oportunidad · Admin')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 70),
              children: [
                Text(_editing ? 'Edición y verificación' : 'Publicación directa', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                const Text('Solo el equipo de GratisCash puede aprobar contenido, añadir enlaces de afiliación y decidir qué imágenes se muestran.', style: TextStyle(color: GratisCashTheme.muted, height: 1.4)),
                const SizedBox(height: 18),
                SurfaceCard(
                  child: Column(
                    children: [
                      TextFormField(controller: _title, validator: _required, maxLength: 120, decoration: const InputDecoration(labelText: 'Título')),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<OpportunityCategory>(initialValue: _category, decoration: const InputDecoration(labelText: 'Categoría'), items: [for (final item in OpportunityCategory.values) DropdownMenuItem(value: item, child: Text(item.label))], onChanged: (value) { if (value != null) setState(() => _category = value); }),
                      const SizedBox(height: 12),
                      TextFormField(controller: _reward, validator: _required, maxLength: 80, decoration: const InputDecoration(labelText: 'Beneficio / recompensa')),
                      const SizedBox(height: 12),
                      TextFormField(controller: _source, validator: _required, maxLength: 120, decoration: const InputDecoration(labelText: 'Fuente / marca')),
                      const SizedBox(height: 12),
                      TextFormField(controller: _sourceUrl, validator: _required, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'URL oficial HTTPS')),
                      const SizedBox(height: 12),
                      TextFormField(controller: _affiliateUrl, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'URL afiliada (opcional)', helperText: 'Nunca se expone como editable a usuarios.')),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Contenido', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 12),
                      TextFormField(controller: _minutes, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tiempo estimado en minutos (opcional)')),
                      const SizedBox(height: 12),
                      InkWell(onTap: _pickDate, borderRadius: BorderRadius.circular(15), child: InputDecorator(decoration: const InputDecoration(labelText: 'Fecha de finalización', prefixIcon: Icon(Icons.event_outlined)), child: Text(_expiresAt == null ? 'Sin fecha' : '${_expiresAt!.day}/${_expiresAt!.month}/${_expiresAt!.year}'))),
                      const SizedBox(height: 12),
                      TextFormField(controller: _description, validator: _required, maxLength: 3000, maxLines: 6, decoration: const InputDecoration(labelText: 'Descripción')),
                      const SizedBox(height: 12),
                      TextFormField(controller: _requirements, maxLength: 2000, maxLines: 4, decoration: const InputDecoration(labelText: 'Requisitos (opcional)')),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Imagen y derechos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      const Text('Usa únicamente una imagen propia, autorizada o con licencia compatible. Para imágenes ilustrativas, identifica el crédito y la fuente.', style: TextStyle(color: GratisCashTheme.muted, height: 1.4)),
                      const SizedBox(height: 12),
                      TextFormField(controller: _imageUrl, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'URL de imagen HTTPS')),
                      const SizedBox(height: 12),
                      TextFormField(controller: _photoCredit, decoration: const InputDecoration(labelText: 'Crédito / licencia')),
                      const SizedBox(height: 12),
                      TextFormField(controller: _photoSourceUrl, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'Página fuente de la imagen')),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SurfaceCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Visibilidad y monetización',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        value: _featured,
                        onChanged: (value) =>
                            setState(() => _featured = value),
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Destacada',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: const Text(
                          'Selección editorial de GratisCash. No implica pago.',
                        ),
                      ),
                      const Divider(),
                      SwitchListTile(
                        value: _sponsored,
                        onChanged: (value) => setState(() {
                          _sponsored = value;
                          if (!value) {
                            _sponsorName.clear();
                            _sponsoredFrom = null;
                            _sponsoredUntil = null;
                          }
                        }),
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Patrocinada',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: const Text(
                          'Campaña pagada. Se mostrará claramente al usuario como contenido patrocinado.',
                        ),
                      ),
                      if (_sponsored) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _sponsorName,
                          maxLength: 100,
                          decoration: const InputDecoration(
                            labelText: 'Marca / patrocinador',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final value =
                                      await _pickCampaignDate(_sponsoredFrom);
                                  if (value != null && mounted) {
                                    setState(() => _sponsoredFrom = value);
                                  }
                                },
                                icon: const Icon(Icons.play_circle_outline),
                                label: Text(
                                  _dateLabel(
                                    _sponsoredFrom,
                                    'Inicio opcional',
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  final value =
                                      await _pickCampaignDate(_sponsoredUntil);
                                  if (value != null && mounted) {
                                    setState(() => _sponsoredUntil = value);
                                  }
                                },
                                icon: const Icon(Icons.event_busy_outlined),
                                label: Text(
                                  _dateLabel(
                                    _sponsoredUntil,
                                    'Fin opcional',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Guardando…' : (_editing ? 'Guardar cambios' : 'Publicar ahora')))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
