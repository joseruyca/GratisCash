import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/models.dart';

class GratisCashLogo extends StatelessWidget {
  const GratisCashLogo({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 30,
          height: 30,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.translate(
                offset: const Offset(-5, -3),
                child: Transform.rotate(
                  angle: -0.55,
                  child: const Icon(
                    Icons.eco_rounded,
                    color: Color(0xFF39C27F),
                    size: 22,
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(6, 1),
                child: Transform.rotate(
                  angle: 0.65,
                  child: const Icon(
                    Icons.eco_rounded,
                    color: GratisCashTheme.green,
                    size: 19,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!compact) ...[
          const SizedBox(width: 6),
          const Text(
            'GratisCash',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              color: GratisCashTheme.dark,
              letterSpacing: -0.8,
            ),
          ),
        ],
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(
    this.text, {
    super.key,
    this.active = true,
    this.icon,
  });

  final String text;
  final bool active;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final foreground = active ? const Color(0xFF087653) : const Color(0xFF647180);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE2F8EF) : const Color(0xFFF0F2F4),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: foreground,
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF7F2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: GratisCashTheme.green),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                  color: GratisCashTheme.dark,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(color: GratisCashTheme.muted, height: 1.45),
              ),
              if (action != null) ...[
                const SizedBox(height: 18),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class OpportunityCard extends StatelessWidget {
  const OpportunityCard({
    super.key,
    required this.item,
    required this.onTap,
    this.onVote,
    this.onSave,
    this.saved = false,
    this.showStatus = false,
  });

  final Opportunity item;
  final VoidCallback onTap;
  final VoidCallback? onVote;
  final VoidCallback? onSave;
  final bool saved;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final expired = item.isExpired;
    final endLabel = _endLabel(item.expiresAt, expired);
    final canOpen = !showStatus ||
        item.status == OpportunityStatus.active ||
        item.status == OpportunityStatus.expired ||
        expired;
    final actionLabel = expired
        ? 'Historial'
        : switch (item.status) {
            OpportunityStatus.pending => 'En revisión',
            OpportunityStatus.rejected => 'Rechazada',
            OpportunityStatus.draft => 'Borrador',
            OpportunityStatus.active => 'Ver',
            OpportunityStatus.expired => 'Historial',
          };

    return Card(
      color: item.isFeatured && !expired ? const Color(0xFFFCFFFD) : Colors.white,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: canOpen ? onTap : null,
        borderRadius: BorderRadius.circular(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 620;
            final imageWidth = compact ? 104.0 : 150.0;
            final imageHeight = compact ? 132.0 : 128.0;

            return Padding(
              padding: EdgeInsets.all(compact ? 10 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OpportunityImage(
                    item: item,
                    width: imageWidth,
                    height: imageHeight,
                  ),
                  SizedBox(width: compact ? 11 : 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (showStatus &&
                                item.status != OpportunityStatus.active &&
                                !expired)
                              CategoryPill(category: item.category)
                            else
                              _VoteChip(
                                count: item.upvotes,
                                onTap: onVote,
                                expired: expired,
                              ),
                            const Spacer(),
                            if (showStatus || expired) ...[
                              StatusPill(
                                expired ? 'Terminada' : _statusLabel(item.status),
                                active: !expired && item.status == OpportunityStatus.active,
                                icon: expired ? Icons.schedule_rounded : null,
                              ),
                            ] else ...[
                              if (item.endsSoon && item.urgencyLabel != null)
                                _UrgencyChip(label: item.urgencyLabel!),
                              if (!item.endsSoon && item.estimatedMinutes != null)
                                _TinyMeta(
                                  icon: Icons.schedule_rounded,
                                  label: '${item.estimatedMinutes} min',
                                ),
                              if (!item.endsSoon && item.estimatedMinutes != null && endLabel != null)
                                const SizedBox(width: 8),
                              if (!item.endsSoon && endLabel != null)
                                _TinyMeta(
                                  icon: Icons.event_outlined,
                                  label: endLabel,
                                ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (item.isSponsored && !expired) ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.campaign_outlined,
                                size: 13,
                                color: GratisCashTheme.amber,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  item.sponsorName?.trim().isNotEmpty == true
                                      ? 'PATROCINADA · ${item.sponsorName}'
                                      : 'PATROCINADA',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: GratisCashTheme.amber,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.55,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                        ] else if (item.isFeatured && !expired) ...[
                          const Text(
                            'DESTACADA',
                            style: TextStyle(
                              color: GratisCashTheme.violet,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.7,
                            ),
                          ),
                          const SizedBox(height: 3),
                        ],
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: compact ? 16 : 17,
                            fontWeight: FontWeight.w900,
                            color: GratisCashTheme.dark,
                            height: 1.17,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 7,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              item.rewardText,
                              style: TextStyle(
                                fontSize: compact ? 19 : 20,
                                fontWeight: FontWeight.w900,
                                color: expired ? Colors.grey : categoryAccent(item.category),
                                letterSpacing: -0.3,
                              ),
                            ),
                            CategoryPill(category: item.category),
                          ],
                        ),
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            const Icon(
                              Icons.storefront_outlined,
                              size: 15,
                              color: GratisCashTheme.muted,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                item.sourceName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: GratisCashTheme.muted,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!compact && item.description.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Text(
                            item.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: GratisCashTheme.muted,
                              fontSize: 12.3,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.person_outline_rounded,
                              size: 15,
                              color: Color(0xFF81909D),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                item.authorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: GratisCashTheme.muted,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                            if (item.comments > 0) ...[
                              const SizedBox(width: 10),
                              const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 15,
                                color: GratisCashTheme.muted,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${item.comments}',
                                style: const TextStyle(
                                  color: GratisCashTheme.muted,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                            const Spacer(),
                            if (onSave != null)
                              IconButton(
                                tooltip: saved ? 'Quitar de guardadas' : 'Guardar',
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                ),
                                padding: const EdgeInsets.all(6),
                                onPressed: onSave,
                                icon: Icon(
                                  saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                  size: 20,
                                  color: saved ? GratisCashTheme.green : GratisCashTheme.muted,
                                ),
                              ),
                            FilledButton(
                              onPressed: canOpen ? onTap : null,
                              style: FilledButton.styleFrom(
                                minimumSize: Size.zero,
                                padding: EdgeInsets.symmetric(
                                  horizontal: compact ? 13 : 16,
                                  vertical: compact ? 9 : 10,
                                ),
                                backgroundColor: expired
                                    ? const Color(0xFFE8ECEF)
                                    : GratisCashTheme.green,
                                foregroundColor:
                                    expired ? GratisCashTheme.muted : Colors.white,
                              ),
                              child: Text(
                                compact
                                    ? actionLabel
                                    : (expired
                                        ? 'Ver historial'
                                        : canOpen
                                            ? 'Ver oportunidad'
                                            : actionLabel),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String? _endLabel(DateTime? date, bool expired) {
    if (date == null) {
      return null;
    }
    final day = date.day.toString();
    final month = date.month.toString().padLeft(2, '0');
    return expired ? 'Terminó $day/$month' : 'hasta $day/$month';
  }

  String _statusLabel(OpportunityStatus status) {
    switch (status) {
      case OpportunityStatus.draft:
        return 'Borrador';
      case OpportunityStatus.pending:
        return 'En revisión';
      case OpportunityStatus.active:
        return 'Activa';
      case OpportunityStatus.expired:
        return 'Terminada';
      case OpportunityStatus.rejected:
        return 'Rechazada';
    }
  }
}

class OpportunityImage extends StatelessWidget {
  const OpportunityImage({
    super.key,
    required this.item,
    required this.width,
    required this.height,
    this.borderRadius = 16,
  });

  final Opportunity item;
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final placeholder = _PlaceholderImage(item: item);
    if (!item.hasPhoto) {
      return SizedBox(width: width, height: height, child: placeholder);
    }

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(borderRadius),
            child: ColorFiltered(
              colorFilter: item.isExpired
                  ? const ColorFilter.mode(Color(0x55FFFFFF), BlendMode.srcATop)
                  : const ColorFilter.mode(Colors.transparent, BlendMode.srcATop),
              child: Image.network(
                item.imageUrl!,
                width: width,
                height: height,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (context, error, stackTrace) => placeholder,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    width: width,
                    height: height,
                    color: const Color(0xFFEAF6F1),
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderImage extends StatelessWidget {
  const _PlaceholderImage({required this.item});

  final Opportunity item;

  @override
  Widget build(BuildContext context) {
    final icon = switch (item.category) {
      OpportunityCategory.money => Icons.euro_rounded,
      OpportunityCategory.freeProduct => Icons.card_giftcard_rounded,
      OpportunityCategory.cashback => Icons.savings_outlined,
      OpportunityCategory.bonus => Icons.star_outline_rounded,
      OpportunityCategory.mission => Icons.track_changes_rounded,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: item.isExpired
              ? const [Color(0xFFE5E7E9), Color(0xFFF5F5F5)]
              : [
                  categoryColor(item.category),
                  categoryColor(item.category).withValues(alpha: 0.35),
                ],
        ),
      ),
      child: Center(
        child: Icon(
          icon,
          size: 38,
          color: item.isExpired ? Colors.grey : categoryAccent(item.category),
        ),
      ),
    );
  }
}

class CategoryPill extends StatelessWidget {
  const CategoryPill({super.key, required this.category});

  final OpportunityCategory category;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: categoryColor(category),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        category.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: categoryAccent(category),
        ),
      ),
    );
  }
}

Color categoryColor(OpportunityCategory category) {
  switch (category) {
    case OpportunityCategory.money:
      return const Color(0xFFEAF0FF);
    case OpportunityCategory.freeProduct:
      return const Color(0xFFFFECEF);
    case OpportunityCategory.cashback:
      return const Color(0xFFFFF3D9);
    case OpportunityCategory.bonus:
      return const Color(0xFFF0ECFF);
    case OpportunityCategory.mission:
      return const Color(0xFFE5F6F5);
  }
}

Color categoryAccent(OpportunityCategory category) {
  switch (category) {
    case OpportunityCategory.money:
      return GratisCashTheme.blue;
    case OpportunityCategory.freeProduct:
      return GratisCashTheme.coral;
    case OpportunityCategory.cashback:
      return GratisCashTheme.amber;
    case OpportunityCategory.bonus:
      return GratisCashTheme.violet;
    case OpportunityCategory.mission:
      return GratisCashTheme.teal;
  }
}

class _VoteChip extends StatelessWidget {
  const _VoteChip({
    required this.count,
    required this.onTap,
    required this.expired,
  });

  final int count;
  final VoidCallback? onTap;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final foreground = expired ? GratisCashTheme.muted : GratisCashTheme.greenDark;
    return Material(
      color: expired ? const Color(0xFFF0F2F4) : const Color(0xFFE4F7EF),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_upward_rounded, size: 14, color: foreground),
              const SizedBox(width: 3),
              Text(
                count == 0 ? 'Nuevo' : '$count',
                style: TextStyle(
                  color: foreground,
                  fontWeight: FontWeight.w900,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _UrgencyChip extends StatelessWidget {
  const _UrgencyChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0E8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt_rounded, size: 13, color: Color(0xFFC75522)),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(fontSize: 10.8, fontWeight: FontWeight.w800, color: Color(0xFF9A431D))),
        ],
      ),
    );
  }
}

class _TinyMeta extends StatelessWidget {
  const _TinyMeta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: GratisCashTheme.muted),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: GratisCashTheme.muted),
        ),
      ],
    );
  }
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GratisCashTheme.border),
      ),
      child: child,
    );
  }
}
