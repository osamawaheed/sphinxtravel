import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../theme/app_theme.dart';
import '../../../models/trip_model.dart';
import '../../../l10n/app_localizations.dart';

class TodayTimelineWidget extends StatelessWidget {
  final List<ItineraryItem> items;
  final AppLocalizations l10n;

  const TodayTimelineWidget({
    super.key,
    required this.items,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            l10n.todaysPlan,
            style: GoogleFonts.inter(
              color: AppTheme.primaryText,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 20),
        ...items.asMap().entries.map((entry) {
          final i = entry.key;
          final item = entry.value;
          final isLast = i == items.length - 1;
          return _TimelineRow(item: item, isLast: isLast, l10n: l10n);
        }),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final ItineraryItem item;
  final bool isLast;
  final AppLocalizations l10n;

  const _TimelineRow({
    required this.item,
    required this.isLast,
    required this.l10n,
  });

  // Whether this item should show as a large image card (main tour activity)
  bool get _isMainActivity => item.type == 'tour' && item.isCurrent;

  IconData get _typeIcon {
    switch (item.type) {
      case 'hotel':
        return Icons.hotel_rounded;
      case 'transport':
        return Icons.directions_car_rounded;
      case 'meal':
        return Icons.restaurant_rounded;
      case 'guide':
        return Icons.person_pin_rounded;
      case 'activity':
        return Icons.local_activity_rounded;
      default:
        return Icons.place_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left: time label
            SizedBox(
              width: 72,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: item.time.isEmpty
                    ? const SizedBox.shrink()
                    : Text(
                        item.time,
                        style: GoogleFonts.inter(
                          color: item.isCurrent
                              ? AppTheme.luxuryAccent
                              : AppTheme.secondaryText,
                          fontSize: 13,
                          fontWeight: item.isCurrent
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                        textAlign: TextAlign.right,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Center: dot + line
            SizedBox(
              width: 20,
              child: Column(
                children: [
                  const SizedBox(height: 4),
                  _buildDot(),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 1.5,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: item.isCompleted
                            ? AppTheme.successGreen.withAlpha(100)
                            : AppTheme.borderColor,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Right: content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: _isMainActivity
                    ? _buildMainActivityCard(context)
                    : _buildSimpleCard(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot() {
    if (item.isCompleted) {
      return Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.successGreen,
        ),
        child: const Icon(Icons.check, color: Colors.white, size: 12),
      );
    }
    if (item.isCurrent) {
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.luxuryAccent,
          boxShadow: [
            BoxShadow(
              color: AppTheme.luxuryAccent.withAlpha(100),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: const Center(
          child: Icon(Icons.circle, color: Colors.white, size: 8),
        ),
      );
    }
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.transparent,
        border: Border.all(color: AppTheme.borderColor, width: 1.5),
      ),
    );
  }

  Widget _buildSimpleCard() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1, right: 10),
          child: Icon(_typeIcon, size: 18, color: AppTheme.luxuryAccent),
        ),
        Expanded(child: _buildSimpleCardText()),
      ],
    );
  }

  Widget _buildSimpleCardText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item.title,
          style: GoogleFonts.inter(
            color: item.isCompleted
                ? AppTheme.secondaryText
                : AppTheme.primaryText,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            decoration: item.isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        if (item.location != null && item.location!.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            item.location!,
            style: GoogleFonts.inter(
              color: AppTheme.secondaryText,
              fontSize: 13,
            ),
          ),
        ],
        if (item.description != null &&
            item.description!.isNotEmpty &&
            (item.isCurrent || item.location == null)) ...[
          const SizedBox(height: 3),
          Text(
            item.description!,
            style: GoogleFonts.inter(
              color: AppTheme.secondaryText,
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildMainActivityCard(BuildContext context) {
    // Extract location chips from description or use defaults
    final chips = _extractChips();

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandNavy.withAlpha(15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: SizedBox(
              height: 160,
              width: double.infinity,
              child: CachedNetworkImage(
                imageUrl:
                    'https://images.pexels.com/photos/1624438/pexels-photo-1624438.jpeg?w=800',
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    Container(color: AppTheme.brandNavy.withAlpha(40)),
                errorWidget: (_, __, ___) => Container(
                  color: AppTheme.brandNavy.withAlpha(40),
                  child: const Icon(
                    Icons.landscape_outlined,
                    color: Colors.white54,
                    size: 40,
                  ),
                ),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: GoogleFonts.inter(
                    color: AppTheme.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (item.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.description!,
                    style: GoogleFonts.inter(
                      color: AppTheme.secondaryText,
                      fontSize: 14,
                    ),
                  ),
                ],
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: chips
                        .map((chip) => _LocationChip(label: chip))
                        .toList(),
                  ),
                ],
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () {},
                  child: Row(
                    children: [
                      Text(
                        l10n.viewDetails,
                        style: GoogleFonts.inter(
                          color: AppTheme.primaryText,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 16,
                        color: AppTheme.primaryText,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<String> _extractChips() {
    // For Kazbegi/Gudauri type tours, return known stops
    final title = item.title.toLowerCase();
    if (title.contains('kazbegi') ||
        title.contains('gudauri') ||
        title.contains('казбеги') ||
        title.contains('ყაზბეგი')) {
      return ['Ananuri', 'Gudauri', 'Kazbegi'];
    }
    if (title.contains('kakheti') ||
        title.contains('кахетия') ||
        title.contains('კახეთი')) {
      return ['Sighnaghi', 'Telavi', 'Kvareli'];
    }
    if (item.location != null && item.location!.isNotEmpty) {
      return [item.location!];
    }
    return [];
  }
}

class _LocationChip extends StatelessWidget {
  final String label;
  const _LocationChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.softGoldBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.luxuryAccent.withAlpha(80)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: const Color(0xFF8B6914),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
