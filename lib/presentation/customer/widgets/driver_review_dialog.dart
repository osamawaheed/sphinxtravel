import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/api_client.dart';
import '../../../widgets/first_letter_capitalize_formatter.dart';
import '../../../models/customer_bootstrap_model.dart';

/// Modal dialog (shown over the current screen, dimmed background) used to
/// rate a driver: 1-10 selector, optional comment, Submit and Cancel.
/// [onSubmit] performs the Odoo call and must throw on failure; the dialog
/// only closes with `true` after it completes successfully.
class DriverReviewDialog extends StatefulWidget {
  final String driverName;
  final HomeMyRating? initial;
  final AppLocalizations l10n;
  final Future<void> Function(int rating, String comment) onSubmit;

  const DriverReviewDialog({
    super.key,
    required this.driverName,
    this.initial,
    required this.l10n,
    required this.onSubmit,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String driverName,
    HomeMyRating? initial,
    required AppLocalizations l10n,
    required Future<void> Function(int rating, String comment) onSubmit,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withAlpha(160),
      builder: (_) => DriverReviewDialog(
        driverName: driverName,
        initial: initial,
        l10n: l10n,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<DriverReviewDialog> createState() => _DriverReviewDialogState();
}

class _DriverReviewDialogState extends State<DriverReviewDialog> {
  late final TextEditingController _commentCtrl;
  late int _rating;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _rating = (widget.initial?.rating10 ?? 0).clamp(0, 10);
    _commentCtrl = TextEditingController(text: widget.initial?.comment ?? '');
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating < 1 || _rating > 10) {
      setState(() => _error = widget.l10n.driverRatingRequired);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.onSubmit(_rating, _commentCtrl.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = ApiException.messageOf(e) ?? widget.l10n.failedToLoad;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return Directionality(
      textDirection: l10n.isRtlLocale ? TextDirection.rtl : TextDirection.ltr,
      child: Dialog(
        backgroundColor: AppTheme.brandNavy,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.rateDriverTitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (widget.driverName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  widget.driverName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppTheme.luxuryAccent,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Column(
                children: [
                  for (final start in const [1, 6])
                    Padding(
                      padding: EdgeInsets.only(top: start == 6 ? 10 : 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (int n = start; n < start + 5; n++)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _submitting
                                    ? null
                                    : () => setState(() {
                                        _rating = n;
                                        _error = null;
                                      }),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _rating == n
                                        ? AppTheme.luxuryAccent
                                        : Colors.white.withAlpha(20),
                                    border: Border.all(
                                      color: _rating == n
                                          ? AppTheme.luxuryAccent
                                          : Colors.white.withAlpha(70),
                                    ),
                                  ),
                                  child: Text(
                                    '$n',
                                    style: GoogleFonts.inter(
                                      color: _rating == n
                                          ? AppTheme.brandNavy
                                          : Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _commentCtrl,
                enabled: !_submitting,
                minLines: 3,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: const [FirstLetterCapitalizeFormatter()],
                textInputAction: TextInputAction.newline,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                cursorColor: AppTheme.luxuryAccent,
                decoration: InputDecoration(
                  hintText: l10n.ratingCommentHint,
                  hintStyle: GoogleFonts.inter(
                    color: Colors.white.withAlpha(120),
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: Colors.white.withAlpha(20),
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withAlpha(40)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: Colors.white.withAlpha(40)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: AppTheme.luxuryAccent),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: const Color(0xFFFF8A80),
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.white.withAlpha(70)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          l10n.cancelAction,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.luxuryAccent,
                          foregroundColor: AppTheme.brandNavy,
                          disabledBackgroundColor: AppTheme.luxuryAccent
                              .withAlpha(120),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.brandNavy,
                                ),
                              )
                            : Text(
                                l10n.submitReview,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
