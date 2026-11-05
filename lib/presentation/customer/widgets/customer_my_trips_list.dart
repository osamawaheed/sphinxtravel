import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/customer_bootstrap_model.dart';
import '../../../services/api_client.dart';
import '../../../services/customer_auth_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/auth_network_image.dart';
import './customer_trip_details_widget.dart';

/// Customer "My Trip" tab: ONE list with every booking (past, current and
/// future). No tabs or filters. Completed trips stay visible permanently and
/// show their real Odoo status. Tapping a trip opens its full itinerary.
class CustomerMyTripsList extends StatefulWidget {
  final CustomerHomeTrip? fallbackTrip;
  final AppLocalizations l10n;

  const CustomerMyTripsList({
    super.key,
    required this.fallbackTrip,
    required this.l10n,
  });

  @override
  State<CustomerMyTripsList> createState() => _CustomerMyTripsListState();
}

class _CustomerMyTripsListState extends State<CustomerMyTripsList> {
  List<CustomerTripListItem> _trips = const [];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await CustomerAuthService(ApiClient()).loadTrips();
      if (!mounted) return;
      setState(() {
        _trips = _sorted(list);
        _failed = false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  /// Newest departure first so current/future trips lead and history follows.
  List<CustomerTripListItem> _sorted(List<CustomerTripListItem> list) {
    final out = [...list];
    out.sort((a, b) {
      final da = DateTime.tryParse(a.arrivalDate);
      final db = DateTime.tryParse(b.arrivalDate);
      if (da == null || db == null) return b.id.compareTo(a.id);
      return db.compareTo(da);
    });
    return out;
  }

  void _open(int tripId, String title) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _CustomerTripDetailPage(
          tripId: tripId,
          title: title,
          l10n: widget.l10n,
          fallback: widget.fallbackTrip?.id == tripId
              ? widget.fallbackTrip
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppTheme.brandNavy,
          strokeWidth: 2,
        ),
      );
    }

    // Endpoint unavailable: keep the previous behaviour (current trip only).
    if ((_failed || _trips.isEmpty) && widget.fallbackTrip != null) {
      final t = widget.fallbackTrip!;
      return RefreshIndicator(
        color: AppTheme.brandNavy,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 4, bottom: 32),
          children: [
            _TripCard(
              reference: t.reference,
              place: [
                t.city,
                t.destination,
              ].where((e) => e.trim().isNotEmpty).join(', '),
              imageUrl: t.imageUrl,
              arrival: t.arrivalDate,
              departure: t.departureDate,
              days: t.totalDays,
              guests: t.passengers,
              status: t.tripStatus,
              l10n: l10n,
              onTap: () => _open(t.id, t.reference),
            ),
          ],
        ),
      );
    }

    if (_trips.isEmpty) {
      return RefreshIndicator(
        color: AppTheme.brandNavy,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            Center(
              child: Text(
                l10n.noActiveTrips,
                style: GoogleFonts.inter(
                  color: AppTheme.secondaryText,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.brandNavy,
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 4, bottom: 32),
        itemCount: _trips.length,
        itemBuilder: (context, i) {
          final t = _trips[i];
          return _TripCard(
            reference: t.reference,
            place: [
              t.city,
              t.destination,
            ].where((e) => e.trim().isNotEmpty).join(', '),
            imageUrl: t.imageUrl,
            arrival: t.arrivalDate,
            departure: t.departureDate,
            days: t.totalDays,
            guests: t.passengers,
            status: t.status,
            l10n: l10n,
            onTap: () => _open(t.id, t.reference),
          );
        },
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final String reference;
  final String place;
  final String imageUrl;
  final String arrival;
  final String departure;
  final int days;
  final int guests;
  final String status;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  const _TripCard({
    required this.reference,
    required this.place,
    required this.imageUrl,
    required this.arrival,
    required this.departure,
    required this.days,
    required this.guests,
    required this.status,
    required this.l10n,
    required this.onTap,
  });

  String _statusLabel() {
    final s = status.trim().toLowerCase();
    if (s.isEmpty) return '';
    if (s == 'completed' || s == 'done') return l10n.tripStatusCompleted;
    if (s == 'in_progress' || s == 'active' || s == 'in_tour') {
      return l10n.tripStatusInTour;
    }
    final pretty = status.trim().replaceAll('_', ' ');
    return pretty[0].toUpperCase() + pretty.substring(1);
  }

  @override
  Widget build(BuildContext context) {
    final label = _statusLabel();
    final isDraft = status.trim().toLowerCase() == 'draft';
    final done =
        status.trim().toLowerCase() == 'completed' ||
        status.trim().toLowerCase() == 'done';
    final dates = [
      arrival,
      departure,
    ].where((e) => e.trim().isNotEmpty).join('  →  ');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppTheme.brandNavy.withAlpha(51),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              LayoutBuilder(
                builder: (context, c) => AuthNetworkImage(
                  photoUrl: imageUrl,
                  width: c.maxWidth,
                  height: c.maxHeight,
                  fit: BoxFit.cover,
                  fallback: Container(color: AppTheme.brandNavy),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppTheme.brandNavy.withAlpha(150),
                      AppTheme.brandNavy.withAlpha(235),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            reference,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (label.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: done
                                  ? const Color(0xFF1565C0)
                                  : isDraft
                                  ? Colors.transparent
                                  : AppTheme.luxuryAccent.withAlpha(64),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: done
                                    ? const Color(0xFF1565C0)
                                    : isDraft
                                    ? const Color(0xFFFFFFFF)
                                    : AppTheme.luxuryAccent.withAlpha(128),
                              ),
                            ),
                            child: Text(
                              label,
                              style: GoogleFonts.inter(
                                color: done || isDraft
                                    ? Colors.white
                                    : AppTheme.luxuryAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    if (place.isNotEmpty)
                      Text(
                        place,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    if (dates.isNotEmpty)
                      Text(
                        dates,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (days > 0) ...[
                          const Icon(
                            Icons.calendar_today_rounded,
                            color: Colors.white70,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$days ${l10n.daysLabel}',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 14),
                        ],
                        if (guests > 0) ...[
                          const Icon(
                            Icons.people_alt_outlined,
                            color: Colors.white70,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$guests ${l10n.guestsLabel}',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full itinerary (Day 1 → final day) for one booking, past or future.
class _CustomerTripDetailPage extends StatefulWidget {
  final int tripId;
  final String title;
  final AppLocalizations l10n;
  final CustomerHomeTrip? fallback;

  const _CustomerTripDetailPage({
    required this.tripId,
    required this.title,
    required this.l10n,
    this.fallback,
  });

  @override
  State<_CustomerTripDetailPage> createState() =>
      _CustomerTripDetailPageState();
}

class _CustomerTripDetailPageState extends State<_CustomerTripDetailPage> {
  CustomerHomeTrip? _trip;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await CustomerAuthService(
        ApiClient(),
      ).loadTripDetail(widget.tripId);
      if (!mounted) return;
      setState(() {
        _trip = t;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _trip = widget.fallback;
        _error = widget.fallback == null
            ? (ApiException.messageOf(e) ?? widget.l10n.failedToLoad)
            : null;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.mainBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.mainBackground,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.primaryText),
        title: Text(
          widget.title,
          style: GoogleFonts.inter(
            color: AppTheme.primaryText,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.brandNavy,
                strokeWidth: 2,
              ),
            )
          : _trip == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  _error ?? widget.l10n.failedToLoad,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: AppTheme.secondaryText),
                ),
              ),
            )
          : RefreshIndicator(
              color: AppTheme.brandNavy,
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: CustomerTripDetailsWidget(
                  trip: _trip!,
                  l10n: widget.l10n,
                ),
              ),
            ),
    );
  }
}
