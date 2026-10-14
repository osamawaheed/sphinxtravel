import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../data/mock_api_data_source.dart';
import '../../services/api_client.dart';
import '../../services/customer_auth_service.dart';
import '../../models/customer_bootstrap_model.dart';
import '../../theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/localization_service.dart';
import './widgets/today_timeline_widget.dart';
import './widgets/tomorrow_preview_card.dart';
import './widgets/trip_hero_card.dart';
import './widgets/next_up_card.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _selectedTab = 0;
  CustomerBootstrapModel? _bootstrap;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
    LocalizationService.instance.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    LocalizationService.instance.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final CustomerBootstrapModel data = MockApiDataSource.useMock
          ? await MockApiDataSource.getCustomerBootstrap()
          : await CustomerAuthService(ApiClient()).loadBootstrap();
      if (mounted) {
        setState(() {
          _bootstrap = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error =
              ApiException.messageOf(e) ??
              AppLocalizations.of(context).failedToLoad;
          _isLoading = false;
        });
      }
    }
  }

  String _formattedDate(AppLocalizations l10n) {
    final now = DateTime.now();
    final isAr = LocalizationService.instance.isArabic;
    if (isAr) {
      const arMonths = [
        'يناير',
        'فبراير',
        'مارس',
        'أبريل',
        'مايو',
        'يونيو',
        'يوليو',
        'أغسطس',
        'سبتمبر',
        'أكتوبر',
        'نوفمبر',
        'ديسمبر',
      ];
      const arDays = [
        'الاثنين',
        'الثلاثاء',
        'الأربعاء',
        'الخميس',
        'الجمعة',
        'السبت',
        'الأحد',
      ];
      return '${arDays[now.weekday - 1]}، ${now.day} ${arMonths[now.month - 1]}';
    }
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRTL = LocalizationService.instance.isRTL;

    return Scaffold(
      backgroundColor: AppTheme.mainBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(l10n),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.brandNavy,
                        strokeWidth: 2,
                      ),
                    )
                  : _error != null
                  ? _buildError(l10n)
                  : _buildTabContent(l10n),
            ),
            _buildBottomNav(l10n, isRTL),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    final fullName = (_bootstrap?.customerName ?? '').trim();
    final name = fullName.isNotEmpty ? fullName : 'Traveler';
    final avatarUrl = (_bootstrap?.avatarUrl?.isNotEmpty ?? false)
        ? _bootstrap?.avatarUrl
        : null;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'T';

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      color: AppTheme.mainBackground,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l10n.greeting()}, $name',
                  style: GoogleFonts.inter(
                    color: AppTheme.primaryText,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formattedDate(l10n),
                  style: GoogleFonts.inter(
                    color: AppTheme.secondaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Notification button
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.cardWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderColor, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.shadowColor,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(
                      Icons.notifications_outlined,
                      color: AppTheme.primaryText,
                      size: 22,
                    ),
                  ),
                  Positioned(
                    top: 9,
                    right: 9,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.luxuryAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Profile avatar
          GestureDetector(
            onTap: () => setState(() => _selectedTab = 4),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.luxuryAccent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.brandNavy.withAlpha(40),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: avatarUrl != null
                    ? CachedNetworkImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _avatarFallback(initial),
                      )
                    : _avatarFallback(initial),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(String initial) {
    return Container(
      color: AppTheme.brandNavy,
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildTabContent(AppLocalizations l10n) {
    switch (_selectedTab) {
      case 0:
        return _buildTodayTab(l10n);
      case 1:
        return _buildMyTripTab(l10n);
      case 2:
        return _buildServicesTab(l10n);
      case 3:
        return _buildSupportTab(l10n);
      case 4:
        return _buildProfileTab(l10n);
      default:
        return _buildTodayTab(l10n);
    }
  }

  Widget _buildTodayTab(AppLocalizations l10n) {
    final trip = _bootstrap?.activeTrip;

    if (trip == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.flight_takeoff_rounded,
                color: AppTheme.secondaryText,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.noActiveTrips,
                style: GoogleFonts.inter(
                  color: AppTheme.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.upcomingTripsHere,
                style: GoogleFonts.inter(
                  color: AppTheme.secondaryText,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.brandNavy,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            // Trip hero card
            TripHeroCard(trip: trip, l10n: l10n),
            const SizedBox(height: 20),
            // Next up card
            if (trip.nextSegment != null) ...[
              NextUpCard(segment: trip.nextSegment!, l10n: l10n),
              const SizedBox(height: 28),
            ],
            // Today's Plan section
            TodayTimelineWidget(items: trip.todayItinerary, l10n: l10n),
            const SizedBox(height: 28),
            // Tomorrow card
            if (trip.tomorrowItinerary.isNotEmpty) ...[
              TomorrowPreviewCard(
                items: trip.tomorrowItinerary,
                tomorrowDate: _tomorrowDateString(),
                l10n: l10n,
              ),
              const SizedBox(height: 28),
            ],
          ],
        ),
      ),
    );
  }

  String _tomorrowDateString() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${days[tomorrow.weekday - 1]}, ${tomorrow.day} ${months[tomorrow.month - 1]}';
  }

  Widget _buildMyTripTab(AppLocalizations l10n) {
    final trip = _bootstrap?.activeTrip;
    if (trip == null) {
      return _buildEmptyState(l10n.noActiveTrips);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: l10n.tripOverview),
          const SizedBox(height: 12),
          _InfoCard(
            children: [
              _InfoRow(label: l10n.reference, value: trip.reference),
              _InfoRow(label: l10n.destinationLabel, value: trip.destination),
              _InfoRow(label: l10n.checkIn, value: trip.startDate),
              _InfoRow(label: l10n.checkOut, value: trip.endDate),
              _InfoRow(
                label: l10n.duration,
                value: '${trip.totalDays} ${l10n.daysLabel}',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionTitle(title: '${l10n.flightsLabel} (${trip.flights.length})'),
          const SizedBox(height: 12),
          ...trip.flights.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _InfoCard(
                children: [
                  _InfoRow(label: l10n.flightLabel, value: f.flightNumber),
                  _InfoRow(label: l10n.airline, value: f.airline),
                  _InfoRow(
                    label: l10n.route,
                    value: '${f.origin} → ${f.destination}',
                  ),
                  _InfoRow(
                    label: l10n.departure,
                    value: '${f.departureDate} ${f.departureTime}',
                  ),
                  _InfoRow(label: l10n.arrival, value: f.arrivalTime),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle(title: '${l10n.hotelsLabel} (${trip.hotels.length})'),
          const SizedBox(height: 12),
          ...trip.hotels.map(
            (h) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _InfoCard(
                children: [
                  _InfoRow(label: l10n.hotel, value: h.name),
                  _InfoRow(label: l10n.location, value: h.location),
                  _InfoRow(label: l10n.checkIn, value: h.checkIn),
                  _InfoRow(label: l10n.checkOut, value: h.checkOut),
                  _InfoRow(label: l10n.nights, value: '${h.nights}'),
                  if (h.roomType != null)
                    _InfoRow(label: l10n.room, value: h.roomType!),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildServicesTab(AppLocalizations l10n) {
    final trip = _bootstrap?.activeTrip;
    final services = trip?.extraServices ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: l10n.extraServices),
          const SizedBox(height: 12),
          if (services.isEmpty)
            _buildEmptyState(l10n.noExtraServices)
          else
            ...services.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.cardWhite,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppTheme.softGoldBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          s.isSimCard
                              ? Icons.sim_card_outlined
                              : Icons.star_outline_rounded,
                          color: AppTheme.luxuryAccent,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.name,
                              style: GoogleFonts.inter(
                                color: AppTheme.primaryText,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (s.description != null)
                              Text(
                                s.description!,
                                style: GoogleFonts.inter(
                                  color: AppTheme.secondaryText,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: s.status == 'active'
                              ? AppTheme.successGreen.withAlpha(26)
                              : AppTheme.mainBackground,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          s.status == 'active' ? l10n.active : l10n.pending,
                          style: GoogleFonts.inter(
                            color: s.status == 'active'
                                ? AppTheme.successGreen
                                : AppTheme.secondaryText,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSupportTab(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: l10n.supportTitle),
          const SizedBox(height: 16),
          _SupportItem(
            icon: Icons.phone_outlined,
            title: l10n.callUs,
            subtitle: '+971 4 123 4567',
            onTap: () {},
          ),
          const SizedBox(height: 12),
          _SupportItem(
            icon: Icons.chat_bubble_outline_rounded,
            title: l10n.whatsapp,
            subtitle: l10n.chatWithTeam,
            onTap: () {},
          ),
          const SizedBox(height: 12),
          _SupportItem(
            icon: Icons.email_outlined,
            title: l10n.email,
            subtitle: 'support@sphinxtravel.com',
            onTap: () {},
          ),
          const SizedBox(height: 12),
          _SupportItem(
            icon: Icons.help_outline_rounded,
            title: l10n.faq,
            subtitle: l10n.faqSubtitle,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab(AppLocalizations l10n) {
    final customer = _bootstrap;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppTheme.brandNavy,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.luxuryAccent, width: 2),
            ),
            child: Center(
              child: Text(
                customer?.firstName.isNotEmpty == true
                    ? customer!.firstName[0].toUpperCase()
                    : 'T',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            (customer?.customerName.isNotEmpty ?? false)
                ? customer!.customerName
                : 'Traveler',
            style: GoogleFonts.inter(
              color: AppTheme.primaryText,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (customer?.customerPhone?.isNotEmpty ?? false)
            Directionality(
              textDirection: TextDirection.ltr,
              child: Text(
                customer!.customerPhone!,
                style: GoogleFonts.inter(
                  color: AppTheme.secondaryText,
                  fontSize: 14,
                ),
              ),
            ),
          if (customer?.customerEmail?.isNotEmpty ?? false)
            Text(
              customer!.customerEmail!,
              style: GoogleFonts.inter(
                color: AppTheme.secondaryText,
                fontSize: 14,
              ),
            ),
          const SizedBox(height: 32),
          _SupportItem(
            icon: Icons.language_outlined,
            title: l10n.selectLanguage,
            subtitle: l10n.selectLanguageSubtitle,
            onTap: () {},
          ),
          const SizedBox(height: 12),
          _SupportItem(
            icon: Icons.logout_rounded,
            title: l10n.signOut,
            subtitle: '',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildError(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 48),
          const SizedBox(height: 16),
          Text(
            _error ?? l10n.failedToLoad,
            style: GoogleFonts.inter(color: AppTheme.primaryText, fontSize: 16),
          ),
          const SizedBox(height: 16),
          TextButton(onPressed: _loadData, child: Text(l10n.retry)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          style: GoogleFonts.inter(color: AppTheme.secondaryText, fontSize: 15),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildBottomNav(AppLocalizations l10n, bool isRTL) {
    final items = [
      _NavItem(
        icon: Icons.today_outlined,
        activeIcon: Icons.today_rounded,
        label: l10n.today,
      ),
      _NavItem(
        icon: Icons.luggage_outlined,
        activeIcon: Icons.luggage_rounded,
        label: l10n.myTrip,
      ),
      _NavItem(
        icon: Icons.room_service_outlined,
        activeIcon: Icons.room_service_rounded,
        label: l10n.services,
      ),
      _NavItem(
        icon: Icons.headset_mic_outlined,
        activeIcon: Icons.headset_mic_rounded,
        label: l10n.support,
      ),
      _NavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: l10n.profile,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        border: Border(top: BorderSide(color: AppTheme.borderColor, width: 1)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandNavy.withAlpha(15),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final isActive = _selectedTab == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTab = i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isActive ? item.activeIcon : item.icon,
                        size: 24,
                        color: isActive
                            ? AppTheme.luxuryAccent
                            : AppTheme.secondaryText,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isActive
                              ? AppTheme.luxuryAccent
                              : AppTheme.secondaryText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: isActive ? 20 : 0,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppTheme.luxuryAccent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

// ─── Shared helper widgets ────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.inter(
        color: AppTheme.primaryText,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: AppTheme.secondaryText,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: AppTheme.primaryText,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _SupportItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.mainBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppTheme.brandNavy, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: AppTheme.primaryText,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: AppTheme.secondaryText,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.secondaryText,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
