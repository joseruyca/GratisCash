import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_guard.dart';
import '../../core/config.dart';
import '../../core/safe_url.dart';
import '../../core/app_error.dart';
import '../../core/services.dart';
import '../../core/theme.dart';
import '../../data/models.dart';
import '../../widgets/common.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({
    super.key,
    required this.id,
  });

  final String id;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final TextEditingController _commentController = TextEditingController();
  int _refreshKey = 0;
  bool _saved = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<_DetailData> _load() async {
    final item = await Services.repo.getOpportunity(widget.id);
    if (item == null) {
      return const _DetailData(item: null, comments: [], saved: false);
    }
    final comments = await Services.repo.comments(widget.id);
    final saved = (await Services.repo.savedIds()).contains(widget.id);
    _saved = saved;
    return _DetailData(item: item, comments: comments, saved: saved);
  }

  void _refresh() => setState(() => _refreshKey++);

  Future<void> _openOpportunity(Opportunity item) async {
    if (item.isExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta oportunidad ya ha terminado.')),
      );
      return;
    }
    try {
      await Services.repo.registerOutboundClick(item.id);
      await launchExternal(item.outboundUrl);
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(publicErrorMessage(error))),
      );
    }
  }

  Future<void> _openSource(Opportunity item) async {
    try {
      await launchExternal(item.sourceUrl);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(publicErrorMessage(error))),
      );
    }
  }

  Future<void> _vote(Opportunity item) async {
    final allowed = await ensureSignedIn(
      context,
      message: 'Inicia sesión para votar oportunidades.',
    );
    if (!allowed || !mounted) {
      return;
    }
    try {
      await Services.repo.toggleVote(item.id);
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

  Future<void> _save(Opportunity item) async {
    final allowed = await ensureSignedIn(
      context,
      message: 'Inicia sesión para guardar oportunidades.',
    );
    if (!allowed || !mounted) {
      return;
    }
    try {
      await Services.repo.toggleSaved(item.id);
      if (!mounted) {
        return;
      }
      setState(() => _saved = !_saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_saved ? 'Guardada.' : 'Quitada de guardadas.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(publicErrorMessage(error))),
      );
    }
  }

  Future<void> _sendComment(Opportunity item) async {
    final allowed = await ensureCommunityAccess(context);
    if (!allowed || !mounted) {
      return;
    }
    final text = _commentController.text.trim();
    if (text.isEmpty) {
      return;
    }
    try {
      await Services.repo.addComment(item.id, text);
      if (!mounted) {
        return;
      }
      _commentController.clear();
      _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      final raw = error.toString().toLowerCase();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            raw.contains('links are not allowed')
                ? 'Por seguridad, los comentarios no pueden incluir enlaces.'
                : 'No se pudo publicar el comentario.',
          ),
        ),
      );
    }
  }

  Future<void> _share(Opportunity item) async {
    final link = '${AppConfig.websiteUrl}/opportunity/${item.id}';
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Enlace copiado.')),
    );
  }

  Future<void> _reportComment(AppComment comment) async {
    final allowed = await ensureSignedIn(
      context,
      message: 'Inicia sesión para denunciar contenido.',
    );
    if (!allowed || !mounted) return;

    final report = await _askForReport(
      title: 'Denunciar comentario',
      options: const [
        ('spam', 'Spam'),
        ('harassment', 'Acoso o amenazas'),
        ('hate', 'Odio o discriminación'),
        ('personal_data', 'Datos personales'),
        ('illegal', 'Contenido ilegal'),
        ('other', 'Otro problema'),
      ],
    );
    if (report == null || !mounted) return;

    try {
      await Services.repo.report(
        targetType: 'comment',
        targetId: comment.id,
        reason: report.detail,
        reasonCode: report.code,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Denuncia enviada a moderación.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pudimos enviar la denuncia. Puede que ya exista una abierta.'),
          ),
        );
      }
    }
  }

  Future<void> _reportCommentAuthor(AppComment comment) async {
    final authorId = comment.authorId;
    if (authorId == null || authorId.isEmpty) return;
    final allowed = await ensureSignedIn(
      context,
      message: 'Inicia sesión para denunciar usuarios.',
    );
    if (!allowed || !mounted) return;

    final report = await _askForReport(
      title: 'Denunciar usuario',
      options: const [
        ('spam', 'Spam o autopromoción abusiva'),
        ('harassment', 'Acoso o amenazas'),
        ('hate', 'Odio o discriminación'),
        ('personal_data', 'Publica datos personales'),
        ('scam', 'Posible estafa'),
        ('illegal', 'Actividad ilegal'),
        ('other', 'Otro problema'),
      ],
    );
    if (report == null || !mounted) return;

    try {
      await Services.repo.report(
        targetType: 'user',
        targetId: authorId,
        reason: report.detail,
        reasonCode: report.code,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario enviado a moderación.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No pudimos enviar la denuncia. Puede que ya exista una abierta.'),
          ),
        );
      }
    }
  }

  Future<void> _blockCommentAuthor(AppComment comment) async {
    final authorId = comment.authorId;
    if (authorId == null || authorId.isEmpty) return;
    final allowed = await ensureSignedIn(
      context,
      message: 'Inicia sesión para bloquear usuarios.',
    );
    if (!allowed || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('¿Bloquear a ${comment.authorName}?'),
        content: const Text('Dejarás de ver sus comentarios. Puedes solicitar soporte si necesitas revertir un bloqueo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Bloquear')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await Services.repo.blockUser(authorId);
      _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Usuario bloqueado.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(publicErrorMessage(error))));
    }
  }

  Future<_ReportDraft?> _askForReport({
    required String title,
    required List<(String, String)> options,
  }) async {
    final controller = TextEditingController();
    var selected = options.first.$1;
    final result = await showDialog<_ReportDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  decoration: const InputDecoration(labelText: 'Tipo de problema'),
                  items: [
                    for (final option in options)
                      DropdownMenuItem(value: option.$1, child: Text(option.$2)),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selected = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLength: 500,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Detalles',
                    hintText: 'Explica brevemente qué ocurre…',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                final detail = controller.text.trim();
                if (detail.length >= 2) {
                  Navigator.pop(
                    dialogContext,
                    _ReportDraft(code: selected, detail: detail),
                  );
                }
              },
              child: const Text('Enviar a moderación'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _report(Opportunity item) async {
    final allowed = await ensureSignedIn(
      context,
      message: 'Inicia sesión para enviar una denuncia.',
    );
    if (!allowed || !mounted) return;

    final report = await _askForReport(
      title: 'Informar de un problema',
      options: const [
        ('ended', 'Ya ha terminado'),
        ('broken_link', 'El enlace no funciona'),
        ('misleading', 'Información engañosa o incorrecta'),
        ('scam', 'Posible estafa'),
        ('duplicate', 'Está duplicada'),
        ('illegal', 'Contenido ilegal'),
        ('other', 'Otro problema'),
      ],
    );
    if (report == null || !mounted) return;

    try {
      await Services.repo.report(
        targetType: 'opportunity',
        targetId: item.id,
        reason: report.detail,
        reasonCode: report.code,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gracias. La denuncia ha entrado en moderación.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pudimos enviar la denuncia. Puede que ya exista una abierta.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const GratisCashLogo(),
        actions: [
          IconButton(
            tooltip: 'Compartir',
            onPressed: () async {
              final item = (await Services.repo.getOpportunity(widget.id));
              if (item != null && mounted) {
                await _share(item);
              }
            },
            icon: const Icon(Icons.ios_share_rounded),
          ),
          IconButton(
            tooltip: _saved ? 'Quitar de guardadas' : 'Guardar',
            onPressed: () async {
              final item = await Services.repo.getOpportunity(widget.id);
              if (item != null && mounted) {
                await _save(item);
              }
            },
            icon: Icon(
              _saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: _saved ? GratisCashTheme.green : null,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: FutureBuilder<_DetailData>(
        key: ValueKey(_refreshKey),
        future: _load(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'No podemos abrir esta oportunidad',
              body: publicErrorMessage(snapshot.error),
              action: FilledButton.icon(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reintentar'),
              ),
            );
          }

          final data = snapshot.data;
          final item = data?.item;
          if (item == null) {
            return const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Oportunidad no encontrada',
              body: 'Puede haberse retirado o el enlace ya no ser válido.',
            );
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final desktop = constraints.maxWidth >= 940;
              final main = _DetailContent(
                item: item,
                comments: data!.comments,
                commentController: _commentController,
                onOpen: () => _openOpportunity(item),
                onOpenSource: () => _openSource(item),
                onVote: () => _vote(item),
                onSave: () => _save(item),
                onComment: () => _sendComment(item),
                onReport: () => _report(item),
                onReportComment: _reportComment,
                onReportUser: _reportCommentAuthor,
                onBlockCommentAuthor: _blockCommentAuthor,
                saved: data.saved || _saved,
              );

              if (!desktop) {
                return main;
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: main),
                  const SizedBox(width: 18),
                  SizedBox(
                    width: 270,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(0, 8, 12, 80),
                      child: _DetailAside(
                        item: item,
                        saved: data.saved || _saved,
                        onOpen: () => _openOpportunity(item),
                        onSave: () => _save(item),
                        onReport: () => _report(item),
                      ),
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

class _DetailContent extends StatelessWidget {
  const _DetailContent({
    required this.item,
    required this.comments,
    required this.commentController,
    required this.onOpen,
    required this.onOpenSource,
    required this.onVote,
    required this.onSave,
    required this.onComment,
    required this.onReport,
    required this.onReportComment,
    required this.onReportUser,
    required this.onBlockCommentAuthor,
    required this.saved,
  });

  final Opportunity item;
  final List<AppComment> comments;
  final TextEditingController commentController;
  final VoidCallback onOpen;
  final VoidCallback onOpenSource;
  final VoidCallback onVote;
  final VoidCallback onSave;
  final VoidCallback onComment;
  final VoidCallback onReport;
  final ValueChanged<AppComment> onReportComment;
  final ValueChanged<AppComment> onReportUser;
  final ValueChanged<AppComment> onBlockCommentAuthor;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    final expired = item.isExpired;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 100),
      children: [
        SurfaceCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 560;
                  if (narrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OpportunityImage(
                          item: item,
                          width: double.infinity,
                          height: 210,
                          borderRadius: 17,
                        ),
                        const SizedBox(height: 15),
                        _HeroText(item: item, onVote: onVote),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OpportunityImage(
                        item: item,
                        width: 250,
                        height: 220,
                        borderRadius: 17,
                      ),
                      const SizedBox(width: 18),
                      Expanded(child: _HeroText(item: item, onVote: onVote)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: expired ? null : onOpen,
                      icon: Icon(expired ? Icons.schedule_rounded : Icons.open_in_new_rounded),
                      label: Text(expired ? 'Oportunidad terminada' : 'Ir a la oportunidad'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    tooltip: saved ? 'Quitar de guardadas' : 'Guardar',
                    onPressed: onSave,
                    icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
                  ),
                ],
              ),
              if (item.isAffiliate && !expired) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: GratisCashTheme.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: GratisCashTheme.muted,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Este botón puede usar un enlace de afiliación. GratisCash puede recibir una comisión sin coste adicional para ti.',
                          style: TextStyle(
                            color: GratisCashTheme.muted,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      TextButton(
                        onPressed: () => context.push('/legal/affiliate'),
                        child: const Text('Info'),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onOpenSource,
                    icon: const Icon(Icons.source_outlined, size: 18),
                    label: const Text('Abrir fuente oficial'),
                  ),
                ),
              ],
              if (item.photoCredit != null) ...[
                const SizedBox(height: 8),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Imagen ilustrativa · ${item.photoCredit}',
                      style: const TextStyle(
                        color: GratisCashTheme.muted,
                        fontSize: 10.5,
                      ),
                    ),
                    if (item.photoSourceUrl != null)
                      TextButton(
                        onPressed: () async {
                          try {
                            await launchExternal(item.photoSourceUrl!);
                          } catch (_) {}
                        },
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                        ),
                        child: const Text('Fuente', style: TextStyle(fontSize: 10.5)),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Descripción',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 9),
              Text(item.description, style: const TextStyle(height: 1.5)),
              if (item.requirements != null && item.requirements!.trim().isNotEmpty) ...[
                const SizedBox(height: 18),
                const Text(
                  'Requisitos',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 7),
                Text(
                  item.requirements!,
                  style: const TextStyle(color: GratisCashTheme.muted, height: 1.45),
                ),
              ],
            ],
          ),
        ),
        if (item.steps.isNotEmpty) ...[
          const SizedBox(height: 12),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cómo participar',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                for (var index = 0; index < item.steps.length; index++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: index == item.steps.length - 1 ? 0 : 12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE4F7EF),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: GratisCashTheme.greenDark,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(item.steps[index]),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Comentarios',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                    ),
                  ),
                  Text(
                    '${comments.length}',
                    style: const TextStyle(
                      color: GratisCashTheme.muted,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: commentController,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1200,
                      decoration: const InputDecoration(
                        hintText: '¿Te ha funcionado? Comparte tu experiencia…',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Enviar comentario',
                    onPressed: onComment,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
              if (comments.isEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'Todavía no hay comentarios. Sé la primera persona en contar si la oportunidad funciona.',
                  style: TextStyle(color: GratisCashTheme.muted, height: 1.4),
                ),
              ] else ...[
                const SizedBox(height: 10),
                for (final comment in comments)
                  _CommentRow(
                    comment: comment,
                    onReport: () => onReportComment(comment),
                    onReportUser: comment.authorId == null ? null : () => onReportUser(comment),
                    onBlock: comment.authorId == null ? null : () => onBlockCommentAuthor(comment),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F4F6),
            borderRadius: BorderRadius.circular(17),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: GratisCashTheme.muted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  expired
                      ? 'Esta oportunidad está archivada. Conservamos la ficha para transparencia e histórico, pero ya no enviamos al usuario a participar.'
                      : 'Comprueba siempre las condiciones finales en la fuente oficial. Si esta oportunidad termina, seguirá visible en el histórico de GratisCash.',
                  style: const TextStyle(color: GratisCashTheme.muted, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: onReport,
          icon: const Icon(Icons.flag_outlined),
          label: const Text('Informar de un problema con esta oportunidad'),
        ),
      ],
    );
  }
}

class _HeroText extends StatelessWidget {
  const _HeroText({required this.item, required this.onVote});

  final Opportunity item;
  final VoidCallback onVote;

  @override
  Widget build(BuildContext context) {
    final expired = item.isExpired;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Material(
              color: expired ? const Color(0xFFF0F2F4) : const Color(0xFFE4F7EF),
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: expired ? null : onVote,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_upward_rounded,
                        size: 16,
                        color: expired ? GratisCashTheme.muted : GratisCashTheme.greenDark,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.upvotes == 0 ? 'Nuevo' : '${item.upvotes}',
                        style: TextStyle(
                          color: expired ? GratisCashTheme.muted : GratisCashTheme.greenDark,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),
            StatusPill(
              expired ? 'Terminada' : 'Activa',
              active: !expired,
              icon: expired ? Icons.schedule_rounded : Icons.circle,
            ),
          ],
        ),
        if (item.isSponsored && !expired) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3D9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.campaign_outlined,
                  size: 14,
                  color: GratisCashTheme.amber,
                ),
                const SizedBox(width: 5),
                Text(
                  item.sponsorName?.trim().isNotEmpty == true
                      ? 'Patrocinada por ${item.sponsorName}'
                      : 'Contenido patrocinado',
                  style: const TextStyle(
                    color: GratisCashTheme.amber,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 13),
        Text(
          item.title,
          style: const TextStyle(
            fontSize: 28,
            height: 1.08,
            fontWeight: FontWeight.w900,
            color: GratisCashTheme.dark,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            const Icon(Icons.storefront_outlined, size: 18, color: GratisCashTheme.muted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                item.sourceName,
                style: const TextStyle(
                  color: GratisCashTheme.muted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              item.rewardText,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: expired ? Colors.grey : categoryAccent(item.category),
                letterSpacing: -0.8,
              ),
            ),
            CategoryPill(category: item.category),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 9,
          children: [
            if (item.estimatedMinutes != null)
              _MetaBox(
                icon: Icons.schedule_rounded,
                title: '${item.estimatedMinutes} min',
                label: 'Tiempo estimado',
              ),
            if (item.expiresAt != null)
              _MetaBox(
                icon: Icons.event_outlined,
                title: '${item.expiresAt!.day}/${item.expiresAt!.month}/${item.expiresAt!.year}',
                label: expired ? 'Terminó' : 'Fecha límite',
              ),
            _MetaBox(
              icon: Icons.local_offer_outlined,
              title: item.category.label,
              label: 'Categoría',
            ),
          ],
        ),
      ],
    );
  }
}

class _MetaBox extends StatelessWidget {
  const _MetaBox({required this.icon, required this.title, required this.label});

  final IconData icon;
  final String title;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8F9),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: GratisCashTheme.muted),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontSize: 12.3, fontWeight: FontWeight.w800),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 10.5, color: GratisCashTheme.muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CommentRow extends StatelessWidget {
  const _CommentRow({
    required this.comment,
    required this.onReport,
    this.onReportUser,
    this.onBlock,
  });

  final AppComment comment;
  final VoidCallback onReport;
  final VoidCallback? onReportUser;
  final VoidCallback? onBlock;

  @override
  Widget build(BuildContext context) {
    final age = DateTime.now().difference(comment.createdAt);
    final when = age.inDays > 0 ? 'hace ${age.inDays} d' : 'hace ${age.inHours.clamp(0, 23)} h';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFFE4F7EF),
            child: Text(
              comment.authorName.isEmpty ? '?' : comment.authorName.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: GratisCashTheme.greenDark,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.authorName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      when,
                      style: const TextStyle(color: GratisCashTheme.muted, fontSize: 11),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Opciones del comentario',
                      icon: const Icon(Icons.more_horiz_rounded, size: 20, color: GratisCashTheme.muted),
                      onSelected: (value) {
                        if (value == 'report') onReport();
                        if (value == 'report_user') onReportUser?.call();
                        if (value == 'block') onBlock?.call();
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'report', child: Text('Denunciar comentario')),
                        if (onReportUser != null)
                          const PopupMenuItem(value: 'report_user', child: Text('Denunciar usuario')),
                        if (onBlock != null) const PopupMenuItem(value: 'block', child: Text('Bloquear usuario')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment.body, style: const TextStyle(height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailAside extends StatelessWidget {
  const _DetailAside({
    required this.item,
    required this.saved,
    required this.onOpen,
    required this.onSave,
    required this.onReport,
  });

  final Opportunity item;
  final bool saved;
  final VoidCallback onOpen;
  final VoidCallback onSave;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: GratisCashTheme.blue),
                  SizedBox(width: 8),
                  Text(
                    'Antes de participar',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              const _CheckLine(text: 'Revisa requisitos y fecha límite', ok: true),
              const _CheckLine(text: 'Consulta la fuente oficial', ok: true),
              const SizedBox(height: 12),
              const Text(
                'GratisCash resume la oportunidad para que sea fácil de entender. Las condiciones definitivas son siempre las publicadas por la fuente oficial.',
                style: TextStyle(color: GratisCashTheme.muted, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: item.isExpired ? null : onOpen,
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(item.isExpired ? 'Terminada' : 'Ir a la oportunidad'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onSave,
                icon: Icon(saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
                label: Text(saved ? 'Guardada' : 'Guardar'),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: onReport,
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Informar de un problema'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CheckLine extends StatelessWidget {
  const _CheckLine({required this.text, required this.ok});

  final String text;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            size: 18,
            color: ok ? GratisCashTheme.green : GratisCashTheme.muted,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}

class _DetailData {
  const _DetailData({
    required this.item,
    required this.comments,
    required this.saved,
  });

  final Opportunity? item;
  final List<AppComment> comments;
  final bool saved;
}

class _ReportDraft {
  const _ReportDraft({required this.code, required this.detail});
  final String code;
  final String detail;
}
