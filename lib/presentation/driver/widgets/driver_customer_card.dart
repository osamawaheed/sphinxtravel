import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/customer_bootstrap_model.dart';
import '../../../services/api_client.dart';
import '../../../services/driver_api_service.dart';
import '../../../services/pdf_file_helper_stub.dart'
    if (dart.library.io) '../../../services/pdf_file_helper_io.dart'
    if (dart.library.js_interop) '../../../services/pdf_file_helper_web.dart'
    as pdf_helper;
import '../../../theme/app_theme.dart';

class DriverCustomerCard extends StatefulWidget {
  final HomeCustomer customer;
  final AppLocalizations l10n;

  /// Booking (Sales Order) id used to fetch the Customer Name PDF report.
  /// When null/0 the "Print Customer Name" button is hidden.
  final int? bookingId;

  /// Booking reference, used for the PDF file name and share text.
  final String bookingReference;

  const DriverCustomerCard({
    super.key,
    required this.customer,
    required this.l10n,
    this.bookingId,
    this.bookingReference = '',
  });

  @override
  State<DriverCustomerCard> createState() => _DriverCustomerCardState();
}

class _DriverCustomerCardState extends State<DriverCustomerCard> {
  bool _loadingPdf = false;

  HomeCustomer get customer => widget.customer;
  AppLocalizations get l10n => widget.l10n;

  Future<void> _open(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _call(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleaned.isEmpty) {
      _toast(l10n.customerPhoneUnavailable);
      return;
    }
    var launched = false;
    try {
      launched = await launchUrl(
        Uri(scheme: 'tel', path: cleaned),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      launched = false;
    }
    if (!launched) _toast(l10n.callFailed);
  }

  void _toast(String message) {
    if (!mounted || message.isEmpty) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String get _fileName {
    final ref = widget.bookingReference.trim().replaceAll(
      RegExp(r'[^A-Za-z0-9._-]'),
      '_',
    );
    return 'customer_name_${ref.isNotEmpty ? ref : widget.bookingId}.pdf';
  }

  Future<void> _onPrintCustomerName() async {
    final id = widget.bookingId ?? 0;
    if (id <= 0 || _loadingPdf) return;
    setState(() => _loadingPdf = true);
    try {
      final bytes = await DriverApiService(
        ApiClient(),
      ).fetchCustomerNameReport(id);
      if (!mounted) return;
      setState(() => _loadingPdf = false);
      await _showPdfActions(bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingPdf = false);
      if (e is ApiException && e.statusCode == 403) {
        _toast(l10n.reportAccessDenied);
      } else {
        _toast(
          (e is ApiException && e.statusCode != 404 && e.message.isNotEmpty)
              ? e.message
              : l10n.reportNotAvailable,
        );
      }
    }
  }

  Future<void> _runPdfAction(Future<bool> Function() action) async {
    try {
      await action();
    } catch (_) {
      _toast(l10n.reportNotAvailable);
    }
  }

  Future<void> _showPdfActions(Uint8List bytes) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final name = customer.name.trim();
    final shareText = name.isNotEmpty
        ? '${l10n.customerNameReport} - $name'
        : l10n.customerNameReport;

    Widget tile(IconData icon, String label, Color color, VoidCallback onTap) {
      return ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          label,
          style: GoogleFonts.inter(
            color: textColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        onTap: () {
          Navigator.of(context).pop();
          onTap();
        },
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l10n.customerNameReport,
                    style: GoogleFonts.inter(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              tile(
                Icons.picture_as_pdf_rounded,
                l10n.openPdf,
                AppTheme.brandNavy,
                () => _runPdfAction(() => pdf_helper.openPdf(bytes, _fileName)),
              ),
              tile(
                Icons.chat_rounded,
                l10n.shareViaWhatsapp,
                const Color(0xFF25D366),
                () => _runPdfAction(
                  () => pdf_helper.sharePdf(bytes, _fileName, shareText),
                ),
              ),
              tile(
                Icons.download_rounded,
                l10n.downloadPdf,
                AppTheme.brandNavy,
                () => _runPdfAction(
                  () => pdf_helper.downloadPdf(bytes, _fileName),
                ),
              ),
              tile(
                Icons.print_rounded,
                l10n.printPdf,
                AppTheme.brandNavy,
                () =>
                    _runPdfAction(() => pdf_helper.printPdf(bytes, _fileName)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;
    final name = customer.name.trim();
    final phone = customer.phone.trim();
    final whatsapp = customer.whatsapp.trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandNavy.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppTheme.brandNavy,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : 'C',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.customer.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: AppTheme.luxuryAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        phone,
                        style: GoogleFonts.inter(color: subColor, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (phone.isNotEmpty || whatsapp.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (phone.isNotEmpty)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _call(phone),
                      icon: const Icon(Icons.call_rounded, size: 18),
                      label: Text(
                        l10n.call,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.brandNavy,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                if (phone.isNotEmpty && whatsapp.isNotEmpty)
                  const SizedBox(width: 10),
                if (whatsapp.isNotEmpty)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _open(
                        Uri.parse(
                          'https://wa.me/${whatsapp.replaceAll(RegExp(r'[^0-9]'), '')}',
                        ),
                      ),
                      icon: const Icon(Icons.chat_rounded, size: 18),
                      label: Text(
                        l10n.whatsapp,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if ((widget.bookingId ?? 0) > 0) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loadingPdf ? null : _onPrintCustomerName,
                icon: _loadingPdf
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.brandNavy,
                        ),
                      )
                    : const Icon(Icons.print_rounded, size: 18),
                label: Text(
                  l10n.printCustomerName,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : AppTheme.brandNavy,
                  side: BorderSide(
                    color: isDark ? Colors.white54 : AppTheme.brandNavy,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
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
}
