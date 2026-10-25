import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../l10n/app_localizations.dart';
import '../../models/transportation_segment_model.dart';
import '../../routes/app_routes.dart';
import '../../services/api_client.dart';
import '../../services/localization_service.dart';
import '../../theme/app_theme.dart';
import './models/segment_detail.dart';
import './models/trip_status.dart';
import './widgets/trip_action_bar.dart';
import './widgets/trip_error_state.dart';
import './widgets/trip_progress_timeline.dart';
import './widgets/trip_status_badge.dart';

export 'models/trip_status.dart';
export 'models/segment_detail.dart';

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
    // Only allow the single valid next transition from the status last
    // loaded from Odoo (prevents duplicate / skipped transitions).
    if (_currentStatus.next != newStatus) return;
    final previousStatus = _currentStatus;
    setState(() {
      _isUpdatingStatus = true;
      _statusError = null;
    });
    try {
      await _apiClient.post(
        '/api/v1/driver/segments/${widget.segmentId}/status',
        data: {'status': newStatus.toApiString()},
      );
      // Re-read the authoritative status from Odoo; badge, progress and
      // action button all derive from this single value.
      final response = await _apiClient.get(
        '/api/v1/driver/segments/${widget.segmentId}',
      );
      final data = response.data as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _detail = SegmentDetail.fromJson(data);
          _isLoading = false;
          _errorMessage = null;
        });
      }
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
        // If the server may have already applied the change (e.g. duplicate
        // tap / stale screen), resync from Odoo without altering UI otherwise.
        if (previousStatus == _currentStatus) {
          await _loadSegment();
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingStatus = false;
        });
      }
    }
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
                  ? TripErrorState(
                      l10n: l10n,
                      isDark: isDark,
                      onRetry: _loadSegment,
                    )
                  : _buildContent(l10n, isDark),
            ),
            if (_detail != null)
              TripActionBar(
                status: _currentStatus,
                isDark: isDark,
                isUpdating: _isUpdatingStatus,
                statusError: _statusError,
                l10n: l10n,
                onAdvance: _updateStatus,
              ),
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
                  l10n.driverTaskTitle,
                  style: AppTheme.appFont(
                    context,
                    color: textColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_detail?.segment.tripReference != null)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.brandNavy,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _detail!.segment.tripReference!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
          TripStatusBadge(status: _currentStatus),
        ],
      ),
    );
  }

  Widget _buildContent(AppLocalizations l10n, bool isDark) {
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
            TripProgressTimeline(currentStatus: _currentStatus, isDark: isDark),
          ],
        ),
      ),
    );
  }
}
