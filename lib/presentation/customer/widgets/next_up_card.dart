import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../theme/app_theme.dart';
import '../../../models/customer_bootstrap_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/auth_network_image.dart';

const String _whatsappSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="#25D366" d="M17.472 14.382c-.297-.149-1.758-.867-2.03-.967-.273-.099-.471-.148-.67.15-.197.297-.767.966-.94 1.164-.173.199-.347.223-.644.075-.297-.15-1.255-.463-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.298-.347.446-.52.149-.174.198-.298.298-.497.099-.198.05-.371-.025-.52-.075-.149-.669-1.612-.916-2.207-.242-.579-.487-.5-.669-.51-.173-.008-.371-.01-.57-.01-.198 0-.52.074-.792.372-.272.297-1.04 1.016-1.04 2.479 0 1.462 1.065 2.875 1.213 3.074.149.198 2.096 3.2 5.077 4.487.709.306 1.262.489 1.694.625.712.227 1.36.195 1.871.118.571-.085 1.758-.719 2.006-1.413.248-.694.248-1.289.173-1.413-.074-.124-.272-.198-.57-.347m-5.421 7.403h-.004a9.87 9.87 0 01-5.031-1.378l-.361-.214-3.741.982.998-3.648-.235-.374a9.86 9.86 0 01-1.51-5.26c.001-5.45 4.436-9.884 9.888-9.884 2.64 0 5.122 1.03 6.988 2.898a9.825 9.825 0 012.893 6.994c-.003 5.45-4.437 9.884-9.885 9.884m8.413-18.297A11.815 11.815 0 0012.05 0C5.495 0 .16 5.335.157 11.892c0 2.096.547 4.142 1.588 5.945L.057 24l6.305-1.654a11.882 11.882 0 005.683 1.448h.005c6.554 0 11.89-5.335 11.893-11.893a11.821 11.821 0 00-3.48-8.413z"/></svg>';

enum _Progress { assigned, onTheWay, pickedUp, inTour, completed }

class NextUpCard extends StatefulWidget {
  final HomeNextPickup pickup;
  final AppLocalizations l10n;
  final void Function(HomeDriver driver)? onRateDriver;

  const NextUpCard({
    super.key,
    required this.pickup,
    required this.l10n,
    this.onRateDriver,
  });

  @override
  State<NextUpCard> createState() => _NextUpCardState();
}

class _NextUpCardState extends State<NextUpCard> {
  static const String _mapsKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
  static const Duration _etaRefresh = Duration(seconds: 30);

  Timer? _timer;
  int? _etaMinutes;
  bool _fetching = false;

  AppLocalizations get l10n => widget.l10n;
  HomeNextPickup get pickup => widget.pickup;

  _Progress get _progress {
    final key = pickup.progressStatus.trim().toLowerCase().replaceAll(
      RegExp(r'[\s\-]+'),
      '_',
    );
    switch (key) {
      case 'on_the_way':
      case 'on_way':
      case 'ontheway':
      case 'arrived':
        return _Progress.onTheWay;
      case 'picked_up':
      case 'passenger_picked_up':
      case 'pickedup':
      case 'passenger_on_board':
        return _Progress.pickedUp;
      case 'in_tour':
      case 'in_progress':
      case 'active':
        return _Progress.inTour;
      case 'completed':
      case 'done':
        return _Progress.completed;
      default:
        return _Progress.assigned;
    }
  }

  @override
  void initState() {
    super.initState();
    _syncEtaTimer();
  }

  @override
  void didUpdateWidget(covariant NextUpCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncEtaTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _canComputeEta {
    final d = pickup.driver;
    return _mapsKey.isNotEmpty &&
        _progress == _Progress.onTheWay &&
        d != null &&
        d.latitude != null &&
        d.longitude != null &&
        pickup.pickupLat != null &&
        pickup.pickupLng != null;
  }

  void _syncEtaTimer() {
    if (!_canComputeEta) {
      _timer?.cancel();
      _timer = null;
      if (_etaMinutes != null) {
        _etaMinutes = null;
      }
      return;
    }
    if (_timer == null) {
      _fetchEta();
      _timer = Timer.periodic(_etaRefresh, (_) => _fetchEta());
    } else {
      _fetchEta();
    }
  }

  Future<void> _fetchEta() async {
    if (_fetching || !_canComputeEta) return;
    _fetching = true;
    try {
      final d = pickup.driver!;
      final res = await Dio().get(
        'https://maps.googleapis.com/maps/api/directions/json',
        queryParameters: {
          'origin': '${d.latitude},${d.longitude}',
          'destination': '${pickup.pickupLat},${pickup.pickupLng}',
          'mode': 'driving',
          'departure_time': 'now',
          'key': _mapsKey,
        },
      );
      final data = res.data;
      int? seconds;
      if (data is Map && data['status'] == 'OK') {
        final routes = data['routes'];
        if (routes is List && routes.isNotEmpty) {
          final legs = routes.first['legs'];
          if (legs is List && legs.isNotEmpty) {
            final leg = legs.first as Map;
            final dur = leg['duration_in_traffic'] ?? leg['duration'];
            if (dur is Map && dur['value'] is num) {
              seconds = (dur['value'] as num).toInt();
            }
          }
        }
      }
      if (mounted) {
        setState(() {
          _etaMinutes = seconds == null ? null : (seconds / 60).ceil();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _etaMinutes = null);
    } finally {
      _fetching = false;
    }
  }

  String _statusLabel() {
    switch (_progress) {
      case _Progress.assigned:
        return l10n.tripStatusAssigned;
      case _Progress.onTheWay:
        return l10n.tripStatusOnTheWay;
      case _Progress.pickedUp:
        return l10n.tripStatusPickedUp;
      case _Progress.inTour:
        return l10n.tripStatusInTour;
      case _Progress.completed:
        return l10n.tripStatusCompleted;
    }
  }

  String _subtitle(bool hasDriver) {
    if (!hasDriver) return l10n.driverWillBeAssignedSoon;
    if (_progress == _Progress.onTheWay) {
      final m = _etaMinutes;
      return m != null ? l10n.driverArrivesInMin(m) : l10n.driverIsOnTheWay;
    }
    return _statusLabel();
  }

  String? _cleanPhone(String? phone) {
    if (phone == null) return null;
    final cleaned = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    return cleaned.isEmpty ? null : cleaned;
  }

  Future<void> _open(Uri uri, {bool external = false}) async {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: external
              ? LaunchMode.externalApplication
              : LaunchMode.platformDefault,
        );
      }
    } catch (_) {}
  }

  Future<void> _call(String? phone) async {
    final p = _cleanPhone(phone);
    if (p == null) return;
    await _open(Uri.parse('tel:$p'));
  }

  Future<void> _sms(String? phone) async {
    final p = _cleanPhone(phone);
    if (p == null) return;
    await _open(Uri.parse('sms:$p'));
  }

  Future<void> _whatsapp(String? phone) async {
    final p = _cleanPhone(phone);
    if (p == null) return;
    final digits = p.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return;
    await _open(Uri.parse('https://wa.me/$digits'), external: true);
  }

  void _openGallery(List<String> urls, String label, int initialIndex) {
    final items = urls.map((u) => _GalleryItem(u, label)).toList();
    if (items.isEmpty) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha(204),
      builder: (_) => _GalleryDialog(
        items: items,
        title: label,
        isRtl: l10n.isRtlLocale,
        initialIndex: initialIndex.clamp(0, items.length - 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final driver = pickup.driver;
    final hasDriver = driver != null;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.brandNavy,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandNavy.withAlpha(77),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.luxuryAccent.withAlpha(38),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.luxuryAccent.withAlpha(102),
                    ),
                  ),
                  child: Text(
                    l10n.nextUp,
                    style: GoogleFonts.inter(
                      color: AppTheme.luxuryAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const Spacer(),
                if (pickup.time.isNotEmpty)
                  Text(
                    pickup.time,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(
              l10n.driverPickup,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: Text(
              _subtitle(hasDriver),
              style: GoogleFonts.inter(
                color: Colors.white.withAlpha(179),
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Divider(color: Colors.white.withAlpha(26), height: 1),
          if (hasDriver) _buildDriverRow(driver),
          if (!hasDriver) const SizedBox(height: 16),
          if (pickup.pickup.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _RouteRow(
                      icon: Icons.radio_button_checked,
                      iconColor: AppTheme.successGreen,
                      label: l10n.pickup,
                      value: pickup.pickup,
                    ),
                  ],
                ),
              ),
            ),
          if (hasDriver && driver.phone.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.phone_outlined,
                      label: l10n.call.toUpperCase(),
                      onTap: () => _call(driver.phone),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: l10n.message.toUpperCase(),
                      onTap: () => _sms(driver.phone),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      icon: Icons.chat_rounded,
                      label: l10n.whatsapp.toUpperCase(),
                      onTap: () => _whatsapp(driver.phone),
                      svg: _whatsappSvg,
                    ),
                  ),
                ],
              ),
            )
          else
            const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDriverRow(HomeDriver driver) {
    final driverPhotos = driver.driverPhotos.take(3).toList();
    final vehiclePhotos = driver.vehiclePhotos.take(5).toList();
    final showPhotos = driverPhotos.isNotEmpty || vehiclePhotos.isNotEmpty;
    final stats = _statsText(driver);
    final showRate =
        widget.onRateDriver != null && driver.id > 0 && pickup.canRate != false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver.name,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (stats.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (driver.rating != null) ...[
                            const Icon(
                              Icons.star_rounded,
                              color: AppTheme.luxuryAccent,
                              size: 15,
                            ),
                            const SizedBox(width: 3),
                          ],
                          Flexible(
                            child: Text(
                              stats,
                              style: GoogleFonts.inter(
                                color: Colors.white.withAlpha(179),
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (driver.vehicleModel.isNotEmpty)
                      Text(
                        driver.vehicleModel,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.end,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (driver.vehicleColor.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          driver.vehicleColor,
                          style: GoogleFonts.inter(
                            color: Colors.white.withAlpha(153),
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (driver.plateNumber.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B3F5C),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          driver.plateNumber.trim(),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (showPhotos) ...[
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, c) {
                const gap = 8.0;
                final unit = (c.maxWidth - gap) / 3;
                final h = (unit * 2 / 1.5).clamp(110.0, 220.0);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: h,
                        child: _PhotoGallery(
                          urls: driverPhotos,
                          icon: Icons.person_rounded,
                          onOpen: (i) => _openGallery(
                            driverPhotos,
                            l10n.driverPhotoLabel,
                            i,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: gap),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: h,
                        child: _PhotoGallery(
                          urls: vehiclePhotos,
                          icon: Icons.directions_car_rounded,
                          onOpen: (i) => _openGallery(
                            vehiclePhotos,
                            l10n.vehiclePhotoLabel,
                            i,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
          if (showRate) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () => widget.onRateDriver!(driver),
                icon: const Icon(
                  Icons.star_rounded,
                  color: AppTheme.luxuryAccent,
                  size: 20,
                ),
                label: Text(
                  l10n.rateDriverButton,
                  style: GoogleFonts.inter(
                    color: AppTheme.luxuryAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: AppTheme.luxuryAccent.withAlpha(140),
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _statsText(HomeDriver d) {
    if (!d.hasAppAccount) return '';
    final parts = <String>[];
    final rating = d.rating;
    if (rating != null) parts.add(rating.toStringAsFixed(1));
    final trips = d.tripCount;
    if (trips != null) parts.add('$trips ${l10n.trips}');
    return parts.join(' · ');
  }

  Widget _driverInitials(String name) {
    return Container(
      color: Colors.white.withAlpha(26),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'D',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _GalleryItem {
  final String url;
  final String label;
  const _GalleryItem(this.url, this.label);
}

class _GalleryDialog extends StatefulWidget {
  final List<_GalleryItem> items;
  final String title;
  final bool isRtl;
  final int initialIndex;

  const _GalleryDialog({
    required this.items,
    required this.title,
    required this.isRtl,
    this.initialIndex = 0,
  });

  @override
  State<_GalleryDialog> createState() => _GalleryDialogState();
}

class _GalleryDialogState extends State<_GalleryDialog> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final height = (size.height * 0.5).clamp(260.0, 420.0);
    return Directionality(
      textDirection: widget.isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Dialog(
        backgroundColor: AppTheme.brandNavy,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
              SizedBox(
                height: height,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: widget.items.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (_, i) {
                      final item = widget.items[i];
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(color: Colors.white.withAlpha(15)),
                          InteractiveViewer(
                            child: AuthNetworkImage(
                              photoUrl: item.url,
                              width: double.infinity,
                              height: height,
                              fit: BoxFit.contain,
                              fallback: const Center(
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Colors.white54,
                                  size: 40,
                                ),
                              ),
                            ),
                          ),
                          PositionedDirectional(
                            start: 12,
                            bottom: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withAlpha(140),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                item.label,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              if (widget.items.length > 1) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    widget.items.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _index ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _index
                            ? AppTheme.luxuryAccent
                            : Colors.white.withAlpha(77),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoGallery extends StatefulWidget {
  final List<String> urls;
  final IconData icon;
  final void Function(int index) onOpen;

  const _PhotoGallery({
    required this.urls,
    required this.icon,
    required this.onOpen,
  });

  @override
  State<_PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<_PhotoGallery> {
  final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    final placeholder = Container(
      color: Colors.white.withAlpha(20),
      child: Center(
        child: Icon(widget.icon, color: Colors.white.withAlpha(102), size: 36),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.luxuryAccent.withAlpha(140),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.5),
        child: urls.isEmpty
            ? placeholder
            : Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    controller: _controller,
                    physics: const ClampingScrollPhysics(),
                    itemCount: urls.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (_, i) => GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => widget.onOpen(i),
                      onHorizontalDragStart: (_) {},
                      child: LayoutBuilder(
                        builder: (_, c) => AuthNetworkImage(
                          photoUrl: urls[i],
                          width: c.maxWidth,
                          height: c.maxHeight,
                          fit: BoxFit.cover,
                          fallback: placeholder,
                        ),
                      ),
                    ),
                  ),
                  if (urls.length > 1)
                    PositionedDirectional(
                      end: 6,
                      bottom: 6,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(150),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_index + 1}/${urls.length}',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _RouteRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? accent = null;
  final String? svg;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.svg,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(26),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            svg != null
                ? SvgPicture.string(svg!, width: 18, height: 18)
                : Icon(icon, color: accent ?? Colors.white, size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
