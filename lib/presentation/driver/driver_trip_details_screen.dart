import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../../routes/app_routes.dart';
import '../../services/localization_service.dart';
import '../../services/api_client.dart';
import '../../models/transportation_segment_model.dart';
import '../../models/extra_service_model.dart';

// ─── Trip Status Enum ──────────────────────────────────────────────────────────

enum TripStatus {
  assigned,
  onTheWay,
  arrived,
  passengerPickedUp,
  inProgress,
  completed;

  static TripStatus fromString(String s) {
    switch (s.toLowerCase()) {
      case 'on_the_way':
      case 'on_way':
        return TripStatus.onTheWay;
      case 'arrived':
        return TripStatus.arrived;
      case 'passenger_picked_up':
      case 'picked_up':
        return TripStatus.passengerPickedUp;
      case 'in_progress':
      case 'active':
        return TripStatus.inProgress;
      case 'completed':
      case 'done':
        return TripStatus.completed;
      default:
        return TripStatus.assigned;
    }
  }

  String toApiString() {
    switch (this) {
      case TripStatus.assigned:
        return 'assigned';
      case TripStatus.onTheWay:
        return 'on_the_way';
      case TripStatus.arrived:
        return 'arrived';
      case TripStatus.passengerPickedUp:
        return 'passenger_picked_up';
      case TripStatus.inProgress:
        return 'in_progress';
      case TripStatus.completed:
        return 'completed';
    }
  }

  TripStatus? get next {
    switch (this) {
      case TripStatus.assigned:
        return TripStatus.onTheWay;
      case TripStatus.onTheWay:
        return TripStatus.arrived;
      case TripStatus.arrived:
        return TripStatus.passengerPickedUp;
      case TripStatus.passengerPickedUp:
        return TripStatus.inProgress;
      case TripStatus.inProgress:
        return TripStatus.completed;
      case TripStatus.completed:
        return null;
    }
  }

  bool get isCompleted => this == TripStatus.completed;
}

// ─── Segment Detail Model (extended) ──────────────────────────────────────────

class SegmentDetail {
  final TransportationSegmentModel segment;
  final List<ExtraServiceModel> extraServices;
  final int? passengerCount;
  final String? arrivalTime;

  const SegmentDetail({
    required this.segment,
    required this.extraServices,
    this.passengerCount,
    this.arrivalTime,
  });

  factory SegmentDetail.fromJson(Map<String, dynamic> json) {
    final seg = TransportationSegmentModel.fromJson(json);
    final rawExtras = json['extra_services'];
    final extras = <ExtraServiceModel>[];
    if (rawExtras is List) {
      for (var i = 0; i < rawExtras.length; i++) {
        final e = rawExtras[i];
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        final name = (m['name'] ?? m['title'] ?? '').toString();
        if (name.isEmpty) continue;
        final qty = m['quantity'];
        extras.add(
          ExtraServiceModel(
            id: m['id'] is num ? (m['id'] as num).toInt() : i,
            name: name,
            serviceType: (m['service_type'] ?? m['type'] ?? '').toString(),
            description: (m['description'] ?? m['subtitle'])?.toString(),
            quantity: qty is num ? qty.toInt() : 1,
            status: m['status']?.toString(),
            deliveryDate: m['delivery_date']?.toString(),
            notes: m['notes']?.toString(),
          ),
        );
      }
    }
    final flight = json['flight'];
    final flightArrival = flight is Map ? flight['arrival_time'] : null;
    final arrival =
        (json['arrival_time'] ?? json['flight_arrival_time'] ?? flightArrival)
            ?.toString();
    return SegmentDetail(
      segment: seg,
      extraServices: extras,
      passengerCount: seg.passengers ?? json['passenger_count'] as int?,
      arrivalTime: (arrival == null || arrival.isEmpty) ? null : arrival,
    );
  }
}

// ─── Driver Trip Details Screen ────────────────────────────────────────────────

class DriverTripDetailsScreen extends StatefulWidget {
  final int segmentId;
  final TransportationSegmentModel? initialSegment;

  const DriverTripDetailsScreen({
    super.key,
    required this.segmentId,
    this.initialSegment,
  });

  @override
  State<DriverTripDetailsScreen> createState() =>
      _DriverTripDetailsScreenState();
}

class _DriverTripDetailsScreenState extends State<DriverTripDetailsScreen> {
  SegmentDetail? _detail;
  bool _isLoading = true;
  bool _isUpdatingStatus = false;
  String? _errorMessage;
  String? _statusError;
  late ApiClient _apiClient;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient();
    _loadSegment();
    LocalizationService.instance.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    LocalizationService.instance.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() => setState(() {});

  /// 403 FORBIDDEN → segment was reassigned to another driver.
  /// Go back to driver home (which reloads its data on arrival).
  void _handleReassigned() {
    if (!mounted) return;
    context.go(AppRoutes.driverHome);
  }

  bool _isForbidden(Object e) =>
      e is ApiException &&
      (e.statusCode == 403 || e.code == ApiException.forbidden);

  Future<void> _loadSegment() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final response = await _apiClient.get(
        '/api/v1/driver/segments/${widget.segmentId}',
      );
      final data = response.data as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _detail = SegmentDetail.fromJson(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (_isForbidden(e)) {
        _handleReassigned();
        return;
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = ApiException.messageOf(e) ?? e.toString();
          // If we have initial segment, show it even on error
          if (widget.initialSegment != null && _detail == null) {
            _detail = SegmentDetail(
              segment: widget.initialSegment!,
              extraServices: [],
            );
          }
        });
      }
    }
  }

  Future<void> _updateStatus(TripStatus newStatus) async {
    if (_isUpdatingStatus) return;
    setState(() {
      _isUpdatingStatus = true;
      _statusError = null;
    });
    try {
      await _apiClient.post(
        '/api/v1/driver/segments/${widget.segmentId}/status',
        data: {'status': newStatus.toApiString()},
      );
      // Refresh from server after success
      await _loadSegment();
    } catch (e) {
      if (_isForbidden(e)) {
        _handleReassigned();
        return;
      }
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        setState(() {
          _statusError = ApiException.messageOf(e) ?? l10n.somethingWentWrong;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
  }

  Future<void> _callCustomer(String phone) async {
    try {
      final uri = Uri.parse(
        'tel:${phone.replaceAll(RegExp(r'[\s\-\(\)]'), '')}',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Future<void> _whatsAppCustomer(String phone) async {
    try {
      final normalized = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
      final digits = normalized.startsWith('+')
          ? normalized.substring(1)
          : normalized;
      final uri = Uri.parse('https://wa.me/$digits');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  TripStatus get _currentStatus {
    if (_detail == null) return TripStatus.assigned;
    return TripStatus.fromString(_detail!.segment.status);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppTheme.darkBackground
          : AppTheme.mainBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(l10n, isDark),
            Expanded(
              child: _isLoading && _detail == null
                  ? Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.brandNavy,
                        strokeWidth: 2,
                      ),
                    )
                  : _errorMessage != null && _detail == null
                  ? _buildErrorState(l10n, isDark)
                  : _buildContent(l10n, isDark),
            ),
            if (_detail != null) _buildStatusBar(l10n, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(AppLocalizations l10n, bool isDark) {
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: border)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkBackground
                    : AppTheme.mainBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: border),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 16,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Trip Details',
                  style: AppTheme.appFont(
                    context,
                    color: textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_detail?.segment.tripReference != null)
                  Text(
                    _detail!.segment.tripReference!,
                    style: GoogleFonts.inter(
                      color: AppTheme.luxuryAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          if (_isLoading && _detail != null)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: AppTheme.brandNavy,
                strokeWidth: 2,
              ),
            ),
          _buildStatusBadge(l10n, isDark),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(AppLocalizations l10n, bool isDark) {
    final status = _currentStatus;
    Color badgeColor;
    Color textColor;
    switch (status) {
      case TripStatus.assigned:
        badgeColor = AppTheme.brandNavy.withAlpha(26);
        textColor = AppTheme.brandNavy;
        break;
      case TripStatus.onTheWay:
        badgeColor = const Color(0xFF1565C0).withAlpha(26);
        textColor = const Color(0xFF1565C0);
        break;
      case TripStatus.arrived:
        badgeColor = AppTheme.luxuryAccent.withAlpha(38);
        textColor = AppTheme.luxuryAccent;
        break;
      case TripStatus.passengerPickedUp:
        badgeColor = const Color(0xFF7B1FA2).withAlpha(26);
        textColor = const Color(0xFF7B1FA2);
        break;
      case TripStatus.inProgress:
        badgeColor = AppTheme.successGreen.withAlpha(38);
        textColor = AppTheme.successGreen;
        break;
      case TripStatus.completed:
        badgeColor = AppTheme.secondaryText.withAlpha(38);
        textColor = AppTheme.secondaryText;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _statusLabel(l10n, status),
        style: GoogleFonts.inter(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _statusLabel(AppLocalizations l10n, TripStatus status) {
    switch (status) {
      case TripStatus.assigned:
        return 'Assigned';
      case TripStatus.onTheWay:
        return 'On The Way';
      case TripStatus.arrived:
        return 'Arrived';
      case TripStatus.passengerPickedUp:
        return 'Passenger Picked Up';
      case TripStatus.inProgress:
        return 'In Progress';
      case TripStatus.completed:
        return 'Completed';
    }
  }

  Widget _buildContent(AppLocalizations l10n, bool isDark) {
    final detail = _detail!;
    return RefreshIndicator(
      color: AppTheme.brandNavy,
      onRefresh: _loadSegment,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Status Timeline ──────────────────────────────────────────
            _buildStatusTimeline(l10n, isDark),
            const SizedBox(height: 20),

            // ── Trip Info Card ───────────────────────────────────────────
            _buildSectionTitle('Trip Information', isDark),
            const SizedBox(height: 10),
            _buildInfoCard(isDark, [
              if (detail.segment.tripReference != null)
                _DetailRow(
                  icon: Icons.tag_rounded,
                  label: l10n.reference,
                  value: detail.segment.tripReference!,
                  isDark: isDark,
                ),
              if (detail.segment.customerName != null)
                _DetailRow(
                  icon: Icons.person_outline_rounded,
                  label: l10n.customer,
                  value: detail.segment.customerName!,
                  isDark: isDark,
                ),
              if (detail.segment.customerPhone != null)
                _DetailRow(
                  icon: Icons.phone_outlined,
                  label: 'Phone',
                  value: detail.segment.customerPhone!,
                  isDark: isDark,
                ),
              if (detail.passengerCount != null)
                _DetailRow(
                  icon: Icons.group_outlined,
                  label: 'Passengers',
                  value: detail.passengerCount.toString(),
                  isDark: isDark,
                ),
              if (detail.segment.date.isNotEmpty)
                _DetailRow(
                  icon: Icons.calendar_today_rounded,
                  label: 'Date',
                  value: detail.segment.date,
                  isDark: isDark,
                ),
              if (detail.segment.pickupTime.isNotEmpty)
                _DetailRow(
                  icon: Icons.access_time_rounded,
                  label: l10n.pickup,
                  value: detail.segment.pickupTime,
                  isDark: isDark,
                ),
            ]),
            if (detail.segment.customerPhone != null) ...[
              const SizedBox(height: 12),
              _buildContactButtons(detail.segment.customerPhone!),
            ],
            const SizedBox(height: 16),

            // ── Route Card ───────────────────────────────────────────────
            if (detail.segment.pickupLocation.isNotEmpty ||
                detail.segment.dropoffLocation.isNotEmpty) ...[
              _buildSectionTitle(l10n.route, isDark),
              const SizedBox(height: 10),
              _buildRouteCard(detail, l10n, isDark),
              const SizedBox(height: 16),
            ],

            // ── Flight Info ──────────────────────────────────────────────
            if (detail.segment.flightNumber != null ||
                detail.arrivalTime != null) ...[
              _buildSectionTitle('Flight Info', isDark),
              const SizedBox(height: 10),
              _buildInfoCard(isDark, [
                if (detail.segment.flightAirline != null)
                  _DetailRow(
                    icon: Icons.airlines_rounded,
                    label: l10n.airline,
                    value: detail.segment.flightAirline!,
                    isDark: isDark,
                  ),
                if (detail.segment.flightNumber != null)
                  _DetailRow(
                    icon: Icons.flight_rounded,
                    label: 'Flight Number',
                    value: detail.segment.flightNumber!,
                    isDark: isDark,
                  ),
                if (detail.arrivalTime != null)
                  _DetailRow(
                    icon: Icons.flight_land_rounded,
                    label: l10n.arrival,
                    value: detail.arrivalTime!,
                    isDark: isDark,
                  ),
              ]),
              const SizedBox(height: 16),
            ],

            // ── Vehicle ──────────────────────────────────────────────────
            if (detail.segment.vehicleDisplayName != null ||
                detail.segment.vehiclePlate != null) ...[
              _buildSectionTitle(l10n.vehicle, isDark),
              const SizedBox(height: 10),
              _buildInfoCard(isDark, [
                if (detail.segment.vehicleDisplayName != null)
                  _DetailRow(
                    icon: Icons.directions_car_rounded,
                    label: l10n.vehicle,
                    value: detail.segment.vehicleDisplayName!,
                    isDark: isDark,
                  ),
                if (detail.segment.vehiclePlate != null)
                  _DetailRow(
                    icon: Icons.pin_rounded,
                    label: l10n.plate,
                    value: detail.segment.vehiclePlate!,
                    isDark: isDark,
                  ),
              ]),
              const SizedBox(height: 16),
            ],

            // ── Notes ────────────────────────────────────────────────────
            if (detail.segment.notes != null &&
                detail.segment.notes!.isNotEmpty) ...[
              _buildSectionTitle('Notes', isDark),
              const SizedBox(height: 10),
              _buildNotesCard(detail.segment.notes!, isDark),
              const SizedBox(height: 16),
            ],

            // ── Extra Services ───────────────────────────────────────────
            if (detail.extraServices.isNotEmpty) ...[
              _buildSectionTitle(l10n.extraServices, isDark),
              const SizedBox(height: 10),
              _buildExtraServicesCard(detail.extraServices, l10n, isDark),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTimeline(AppLocalizations l10n, bool isDark) {
    final statuses = [
      TripStatus.assigned,
      TripStatus.onTheWay,
      TripStatus.arrived,
      TripStatus.passengerPickedUp,
      TripStatus.inProgress,
      TripStatus.completed,
    ];
    final current = _currentStatus;
    final currentIndex = statuses.indexOf(current);
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trip Progress',
            style: GoogleFonts.inter(
              color: isDark
                  ? AppTheme.darkSecondaryText
                  : AppTheme.secondaryText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: statuses.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              final isDone = i < currentIndex;
              final isCurrent = i == currentIndex;
              final isLast = i == statuses.length - 1;

              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: isDone || isCurrent
                                  ? (isCurrent
                                        ? AppTheme.luxuryAccent
                                        : AppTheme.successGreen)
                                  : (isDark
                                        ? AppTheme.darkBackground
                                        : AppTheme.mainBackground),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDone || isCurrent
                                    ? (isCurrent
                                          ? AppTheme.luxuryAccent
                                          : AppTheme.successGreen)
                                    : border,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: isDone
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    )
                                  : isCurrent
                                  ? Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _shortStatusLabel(l10n, s),
                            style: GoogleFonts.inter(
                              color: isCurrent
                                  ? AppTheme.luxuryAccent
                                  : isDone
                                  ? AppTheme.successGreen
                                  : (isDark
                                        ? AppTheme.darkSecondaryText
                                        : AppTheme.secondaryText),
                              fontSize: 8.5,
                              fontWeight: isCurrent
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          height: 2,
                          margin: const EdgeInsets.only(bottom: 22),
                          color: i < currentIndex
                              ? AppTheme.successGreen
                              : border,
                        ),
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _shortStatusLabel(AppLocalizations l10n, TripStatus s) {
    switch (s) {
      case TripStatus.assigned:
        return 'Assigned';
      case TripStatus.onTheWay:
        return 'On The Way';
      case TripStatus.arrived:
        return 'Arrived';
      case TripStatus.passengerPickedUp:
        return 'Picked Up';
      case TripStatus.inProgress:
        return 'In Progress';
      case TripStatus.completed:
        return 'Completed';
    }
  }

  Widget _buildRouteCard(
    SegmentDetail detail,
    AppLocalizations l10n,
    bool isDark,
  ) {
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Pickup
          if (detail.segment.pickupLocation.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen.withAlpha(26),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.radio_button_checked_rounded,
                        size: 16,
                        color: AppTheme.successGreen,
                      ),
                    ),
                    if (detail.segment.dropoffLocation.isNotEmpty)
                      Container(width: 2, height: 32, color: border),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.pickup,
                        style: GoogleFonts.inter(
                          color: subColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        detail.segment.pickupLocation,
                        style: GoogleFonts.inter(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          // Destination
          if (detail.segment.dropoffLocation.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.luxuryAccent.withAlpha(26),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    size: 16,
                    color: AppTheme.luxuryAccent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.destination,
                        style: GoogleFonts.inter(
                          color: subColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        detail.segment.dropoffLocation,
                        style: GoogleFonts.inter(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(bool isDark, List<Widget> rows) {
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    if (rows.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: rows.asMap().entries.map((e) {
          final isLast = e.key == rows.length - 1;
          return Column(
            children: [
              e.value,
              if (!isLast) Divider(color: border, height: 16),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNotesCard(String notes, bool isDark) {
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notes_rounded, size: 16, color: AppTheme.luxuryAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              notes,
              style: GoogleFonts.inter(
                color: textColor,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExtraServicesCard(
    List<ExtraServiceModel> services,
    AppLocalizations l10n,
    bool isDark,
  ) {
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: services.asMap().entries.map((entry) {
          final i = entry.key;
          final svc = entry.value;
          final isLast = i == services.length - 1;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppTheme.softGoldBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.star_outline_rounded,
                        size: 18,
                        color: AppTheme.luxuryAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            svc.name,
                            style: GoogleFonts.inter(
                              color: textColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (svc.description != null &&
                              svc.description!.isNotEmpty)
                            Text(
                              svc.description!,
                              style: GoogleFonts.inter(
                                color: subColor,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.softGoldBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'x${svc.quantity}',
                        style: GoogleFonts.inter(
                          color: AppTheme.luxuryAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast) Divider(color: border, height: 1),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildContactButtons(String phone) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _callCustomer(phone),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.brandNavy,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.phone, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Call',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => _whatsAppCustomer(phone),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFF25D366), width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.chat_rounded,
                    color: Color(0xFF25D366),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'WhatsApp',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF25D366),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.inter(
        color: isDark ? AppTheme.darkSecondaryText : AppTheme.secondaryText,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildStatusBar(AppLocalizations l10n, bool isDark) {
    final status = _currentStatus;
    final nextStatus = status.next;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(top: BorderSide(color: border)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_statusError != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withAlpha(26),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.errorRed.withAlpha(77)),
              ),
              child: Text(
                _statusError!,
                style: GoogleFonts.inter(
                  color: AppTheme.errorRed,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
          if (status.isCompleted)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withAlpha(26),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.successGreen.withAlpha(77)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.successGreen,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Trip Completed!',
                    style: GoogleFonts.inter(
                      color: AppTheme.successGreen,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            )
          else if (nextStatus != null)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUpdatingStatus
                    ? null
                    : () => _updateStatus(nextStatus),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandNavy,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.brandNavy.withAlpha(128),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _isUpdatingStatus
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _actionButtonLabel(l10n, status),
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
              ),
            ),
        ],
      ),
    );
  }

  String _actionButtonLabel(AppLocalizations l10n, TripStatus status) {
    switch (status) {
      case TripStatus.assigned:
        return 'Start Driving';
      case TripStatus.onTheWay:
        return 'Arrived';
      case TripStatus.arrived:
        return 'Passenger On Board';
      case TripStatus.passengerPickedUp:
        return l10n.startTrip;
      case TripStatus.inProgress:
        return 'Complete Trip';
      case TripStatus.completed:
        return 'Completed';
    }
  }

  Widget _buildErrorState(AppLocalizations l10n, bool isDark) {
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded, color: subColor, size: 48),
            const SizedBox(height: 16),
            Text(
              l10n.somethingWentWrong,
              style: GoogleFonts.inter(
                color: textColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadSegment,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.brandNavy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                l10n.retry,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Detail Row Widget ─────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isDark;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.luxuryAccent),
        const SizedBox(width: 10),
        Text(label, style: GoogleFonts.inter(color: subColor, fontSize: 13)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: GoogleFonts.inter(
              color: textColor,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}
