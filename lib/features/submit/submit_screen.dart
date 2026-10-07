import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/auth_guard.dart';
import '../../core/services.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

class SubmitScreen extends StatefulWidget {
  const SubmitScreen({super.key});

  @override
  State<SubmitScreen> createState() => _SubmitScreenState();
}

class _SubmitScreenState extends State<SubmitScreen> {
  final _formKey = GlobalKey<FormState>();
  final _url = TextEditingController();
  final _title = TextEditingController();
  final _reward = TextEditingController();
  final _description = TextEditingController();
  final _source = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  OpportunityCategory _category = OpportunityCategory.freeProduct;
  XFile? _image;
  Uint8List? _imageBytes;
  DateTime? _expiresAt;
  bool _checked = false;
  bool _busy = false;
  bool _checkingDuplicates = false;
  int _step = 0;
  List<DuplicateCandidate> _duplicates = const [];

  @override
  void dispose() {
    _url.dispose();
    _title.dispose();
    _reward.dispose();
    _description.dispose();
    _source.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) return 'Obligatorio';
    return null;
  }

  bool _isHttps(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 730)),
      initialDate: _expiresAt ?? now.add(const Duration(days: 14)),
    );
    if (!mounted || date == null) return;
    setState(() => _expiresAt = date);
  }

  Future<void> _pickImage() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 88,
      );
      if (file == null) return;

      final extension = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase()
          : '';
      const allowed = <String>{'jpg', 'jpeg', 'png', 'webp'};
      if (!allowed.contains(extension)) {
        _message('Usa una imagen JPG, PNG o WebP.');
        return;
      }

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.lengthInBytes > 8 * 1024 * 1024) {
        _message('La imagen debe pesar menos de 8 MB.');
        return;
      }

      if (!mounted) return;
      setState(() {
        _image = file;
        _imageBytes = bytes;
      });
    } catch (_) {
      _message('No hemos podido abrir esa imagen. Prueba con otra.');
    }
  }

  void _removeImage() {
    setState(() {
      _image = null;
      _imageBytes = null;
    });
  }

  String? get _imageExtension {
    final name = _image?.name ?? '';
    if (!name.contains('.')) return null;
    return name.split('.').last.toLowerCase();
  }

  String? get _imageContentType {
    final explicit = _image?.mimeType?.toLowerCase();
    if (explicit == 'image/jpeg' ||
        explicit == 'image/png' ||
        explicit == 'image/webp') {
      return explicit;
    }
    return switch (_imageExtension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => null,
    };
  }

  Future<List<DuplicateCandidate>> _findDuplicates() async {
    setState(() => _checkingDuplicates = true);
    try {
      final rows = await Services.repo.findDuplicates(
        sourceUrl: _url.text.trim(),
        title: _title.text.trim(),
        sourceName: _source.text.trim(),
      );
      if (mounted) {
        setState(() => _duplicates = rows);
      }
      return rows;
    } finally {
      if (mounted) {
        setState(() => _checkingDuplicates = false);
      }
    }
  }

  Future<void> _next() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (_step == 0) {
      if (!_isHttps(_url.text)) {
        _message('Pega un enlace oficial HTTPS válido.');
        return;
      }

      // No bloqueamos solo por URL en este punto: algunas fuentes reutilizan
      // una misma página para campañas distintas. La comparación completa se
      // hace cuando ya conocemos título y marca.
      if (mounted) setState(() => _step = 1);
      return;
    }

    if (_step == 1) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
      try {
        final rows = await _findDuplicates();
        final strong = rows.where((item) => item.isStrongMatch).toList();
        if (strong.isNotEmpty && mounted) {
          await _showExactDuplicate(strong.first);
          return;
        }
      } catch (_) {
        _message('No pudimos comprobar duplicados. Inténtalo de nuevo.');
        return;
      }
      if (mounted) setState(() => _step = 2);
    }
  }

  Future<void> _showExactDuplicate(DuplicateCandidate item) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.content_copy_rounded, color: GratisCashTheme.green),
        title: const Text('Esta oportunidad ya existe'),
        content: Text(
          'Hemos encontrado una coincidencia muy fuerte con “${item.title}”. Para evitar duplicados no hace falta volver a enviarla.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.go('/opportunity/${item.id}');
            },
            child: const Text('Ver existente'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_isHttps(_url.text)) {
      _message('El enlace debe ser HTTPS.');
      return;
    }
    if (!_checked) {
      _message('Confirma que has comprobado la oportunidad.');
      return;
    }
    if (!await ensureCommunityAccess(context)) {
      return;
    }

    setState(() => _busy = true);
    try {
      final rows = await Services.repo.findDuplicates(
        sourceUrl: _url.text.trim(),
        title: _title.text.trim(),
        sourceName: _source.text.trim(),
      );
      final strong = rows.where((item) => item.isStrongMatch).toList();
      if (strong.isNotEmpty) {
        if (mounted) await _showExactDuplicate(strong.first);
        return;
      }

      final opportunityId = await Services.repo.submitOpportunity({
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'source_name': _source.text.trim(),
        'source_url': _url.text.trim(),
        'reward_text': _reward.text.trim(),
        'category': _category.name,
        'expires_at': _expiresAt?.toUtc().toIso8601String(),
      });

      var imageFailed = false;
      final bytes = _imageBytes;
      final extension = _imageExtension;
      final contentType = _imageContentType;
      if (bytes != null && extension != null && contentType != null) {
        try {
          await Services.repo.attachSubmissionImage(
            opportunityId: opportunityId,
            bytes: bytes,
            extension: extension,
            contentType: contentType,
          );
        } catch (_) {
          imageFailed = true;
        }
      }

      if (!mounted) return;
      _message(
        imageFailed
            ? 'Enviada a revisión. La imagen no pudo adjuntarse, pero tu propuesta se ha guardado.'
            : 'Enviada a revisión. Podrás seguir el estado desde tu perfil.',
      );
      context.go('/profile');
    } catch (error) {
      if (!mounted) return;
      final raw = error.toString();
      if (raw.contains('OPPORTUNITY_DUPLICATE')) {
        _message('Esa fuente ya está publicada o pendiente de revisión.');
      } else if (raw.toLowerCase().contains('too many')) {
        _message('Has enviado demasiadas propuestas en poco tiempo. Prueba más tarde.');
      } else {
        _message('No pudimos enviar la oportunidad. Revisa los datos e inténtalo de nuevo.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Opportunity get _preview => Opportunity(
        id: 'preview',
        title: _title.text.trim().isEmpty
            ? 'Título de la oportunidad'
            : _title.text.trim(),
        description: _description.text.trim(),
        sourceName: _source.text.trim().isEmpty ? 'Fuente' : _source.text.trim(),
        sourceUrl: _url.text.trim().isEmpty
            ? ''
            : _url.text.trim(),
        rewardText: _reward.text.trim().isEmpty
            ? 'Beneficio'
            : _reward.text.trim(),
        category: _category,
        status: OpportunityStatus.pending,
        createdAt: DateTime.now(),
        expiresAt: _expiresAt,
        authorName: 'Tú',
      );

  @override
  Widget build(BuildContext context) {
    if (!Services.signedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('Publicar')),
        body: EmptyState(
          icon: Icons.add_circle_outline_rounded,
          title: 'Inicia sesión para publicar',
          body:
              'Las propuestas pasan por moderación antes de aparecer en GratisCash.',
          action: FilledButton(
            onPressed: () => context.push('/auth'),
            child: const Text('Iniciar sesión o crear cuenta'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Publicar oportunidad')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                const Text(
                  'Comparte algo que merezca la pena',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tú propones. GratisCash comprueba duplicados y un moderador revisa la información antes de publicarla.',
                  style: TextStyle(color: GratisCashTheme.muted, height: 1.4),
                ),
                const SizedBox(height: 20),
                _StepHeader(step: _step),
                const SizedBox(height: 18),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: switch (_step) {
                    0 => _LinkStep(
                        key: const ValueKey('link'),
                        controller: _url,
                        checking: _checkingDuplicates,
                        onNext: _next,
                      ),
                    1 => _DataStep(
                        key: const ValueKey('data'),
                        title: _title,
                        reward: _reward,
                        source: _source,
                        description: _description,
                        category: _category,
                        expiresAt: _expiresAt,
                        checking: _checkingDuplicates,
                        imageBytes: _imageBytes,
                        imageName: _image?.name,
                        onCategory: (value) => setState(() => _category = value),
                        onPickDate: _pickDate,
                        onPickImage: _pickImage,
                        onRemoveImage: _removeImage,
                        onBack: () => setState(() => _step = 0),
                        onNext: _next,
                        requiredValidator: _required,
                      ),
                    _ => _ReviewStep(
                        key: const ValueKey('review'),
                        preview: _preview,
                        previewImage: _imageBytes,
                        duplicates: _duplicates,
                        checked: _checked,
                        busy: _busy,
                        onChecked: (value) => setState(() => _checked = value),
                        onBack: () => setState(() => _step = 1),
                        onSubmit: _submit,
                      ),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});
  final int step;

  @override
  Widget build(BuildContext context) {
    const labels = ['Enlace', 'Datos', 'Revisar'];
    return Row(
      children: List.generate(labels.length, (index) {
        final active = index <= step;
        return Expanded(
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? GratisCashTheme.green : const Color(0xFFEFF2F4),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: active ? Colors.white : GratisCashTheme.muted,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  labels[index],
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: active ? GratisCashTheme.dark : GratisCashTheme.muted,
                  ),
                ),
              ),
              if (index < labels.length - 1)
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Divider(),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

class _LinkStep extends StatelessWidget {
  const _LinkStep({
    super.key,
    required this.controller,
    required this.checking,
    required this.onNext,
  });
  final TextEditingController controller;
  final bool checking;
  final Future<void> Function() onNext;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '1. Pega la fuente oficial',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          const Text(
            'La fuente es obligatoria. Antes de continuar comprobamos si ese enlace ya existe para reducir publicaciones repetidas.',
            style: TextStyle(color: GratisCashTheme.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.url,
            autofillHints: const [AutofillHints.url],
            decoration: const InputDecoration(
              labelText: 'Enlace oficial HTTPS',
              hintText: 'https://…',
              prefixIcon: Icon(Icons.link_rounded),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: checking ? null : onNext,
              icon: checking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search_rounded),
              label: Text(checking ? 'Comprobando…' : 'Comprobar y continuar'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DataStep extends StatelessWidget {
  const _DataStep({
    super.key,
    required this.title,
    required this.reward,
    required this.source,
    required this.description,
    required this.category,
    required this.expiresAt,
    required this.checking,
    required this.imageBytes,
    required this.imageName,
    required this.onCategory,
    required this.onPickDate,
    required this.onPickImage,
    required this.onRemoveImage,
    required this.onBack,
    required this.onNext,
    required this.requiredValidator,
  });

  final TextEditingController title;
  final TextEditingController reward;
  final TextEditingController source;
  final TextEditingController description;
  final OpportunityCategory category;
  final DateTime? expiresAt;
  final bool checking;
  final Uint8List? imageBytes;
  final String? imageName;
  final ValueChanged<OpportunityCategory> onCategory;
  final VoidCallback onPickDate;
  final Future<void> Function() onPickImage;
  final VoidCallback onRemoveImage;
  final VoidCallback onBack;
  final Future<void> Function() onNext;
  final String? Function(String?) requiredValidator;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '2. Cuéntanos lo esencial',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: title,
            validator: requiredValidator,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Título claro'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<OpportunityCategory>(
            initialValue: category,
            decoration: const InputDecoration(labelText: 'Categoría'),
            items: [
              for (final item in OpportunityCategory.values)
                DropdownMenuItem(value: item, child: Text(item.label)),
            ],
            onChanged: (value) {
              if (value != null) onCategory(value);
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: reward,
            validator: requiredValidator,
            maxLength: 80,
            decoration: const InputDecoration(
              labelText: 'Qué consigue',
              hintText: 'Ej. Gratis, 10 €, puntos…',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: source,
            validator: requiredValidator,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Empresa / fuente'),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: onPickDate,
            borderRadius: BorderRadius.circular(15),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Fecha de finalización',
                prefixIcon: Icon(Icons.event_outlined),
              ),
              child: Text(
                expiresAt == null
                    ? 'No la sé'
                    : '${expiresAt!.day}/${expiresAt!.month}/${expiresAt!.year}',
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: description,
            validator: requiredValidator,
            maxLength: 1000,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Descripción breve y objetiva',
              hintText: 'Qué es, qué hay que hacer y para quién es.',
            ),
          ),
          const SizedBox(height: 4),
          _ImagePickerCard(
            bytes: imageBytes,
            fileName: imageName,
            onPick: onPickImage,
            onRemove: onRemoveImage,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: checking ? null : onBack,
                  child: const Text('Atrás'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: checking ? null : onNext,
                  child: Text(checking ? 'Comprobando…' : 'Revisar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep({
    super.key,
    required this.preview,
    required this.previewImage,
    required this.duplicates,
    required this.checked,
    required this.busy,
    required this.onChecked,
    required this.onBack,
    required this.onSubmit,
  });

  final Opportunity preview;
  final Uint8List? previewImage;
  final List<DuplicateCandidate> duplicates;
  final bool checked;
  final bool busy;
  final ValueChanged<bool> onChecked;
  final VoidCallback onBack;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final similar = duplicates.where((item) => !item.isStrongMatch).take(3).toList();
    return Column(
      children: [
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '3. Así llegará a moderación',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              if (previewImage != null) ...[
                _SelectedImagePreview(bytes: previewImage!),
                const SizedBox(height: 12),
              ],
              OpportunityCard(item: preview, onTap: () {}, showStatus: true),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: checked,
                onChanged: onChecked,
                title: const Text(
                  'La he comprobado',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: const Text(
                  'Confirmo que la fuente existe y que no he inventado la información.',
                ),
              ),
            ],
          ),
        ),
        if (similar.isNotEmpty) ...[
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.copy_all_outlined, color: Color(0xFFC27A13)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Posibles publicaciones parecidas',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                const Text(
                  'No parecen idénticas, pero moderación verá esta comparación antes de aprobar.',
                  style: TextStyle(color: GratisCashTheme.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 10),
                for (final item in similar)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(item.sourceName),
                    trailing: Text('${(item.score * 100).round()}%'),
                    onTap: () => context.push('/opportunity/${item.id}'),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        SurfaceCard(
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, color: GratisCashTheme.green),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Prohibimos estafas, pagos para acceder a una “oportunidad”, enlaces maliciosos, spam, datos personales de terceros y contenido engañoso. Si rechazamos una propuesta, verás el motivo y podrás pedir una revisión.',
                  style: TextStyle(color: GratisCashTheme.muted, height: 1.42),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: busy ? null : onBack,
                child: const Text('Atrás'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                onPressed: busy ? null : onSubmit,
                child: Text(busy ? 'Enviando…' : 'Enviar a revisión'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}


class _ImagePickerCard extends StatelessWidget {
  const _ImagePickerCard({
    required this.bytes,
    required this.fileName,
    required this.onPick,
    required this.onRemove,
  });

  final Uint8List? bytes;
  final String? fileName;
  final Future<void> Function() onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final hasImage = bytes != null;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: hasImage ? const Color(0xFFF1FAF6) : const Color(0xFFF3F6F7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasImage ? const Color(0xFFCBEBDD) : GratisCashTheme.border,
        ),
      ),
      child: hasImage
          ? Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    bytes!,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: GratisCashTheme.green,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Imagen preparada',
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        fileName ?? 'Imagen seleccionada',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: GratisCashTheme.muted,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Moderación la revisará antes de publicar.',
                        style: TextStyle(
                          color: GratisCashTheme.muted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Quitar imagen',
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 22,
                  color: GratisCashTheme.green,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Añade una imagen',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Opcional · JPG, PNG o WebP · máximo 8 MB. Debes tener derecho a compartirla.',
                        style: TextStyle(
                          color: GratisCashTheme.muted,
                          height: 1.35,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: onPick,
                  child: const Text('Elegir'),
                ),
              ],
            ),
    );
  }
}

class _SelectedImagePreview extends StatelessWidget {
  const _SelectedImagePreview({required this.bytes});

  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.memory(
          bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      ),
    );
  }
}
