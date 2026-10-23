import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../models/customer_bootstrap_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/api_client.dart';
import '../../../widgets/first_letter_capitalize_formatter.dart';

/// Bottom sheet with 5 stars + optional comment.
/// [onSubmit] performs the API call; throws on failure.
/// Returns true when the rating was submitted successfully.
class RatingSheet extends StatefulWidget {
  final String title;
  final String subjectName;
  final HomeMyRating? initial;
  final AppLocalizations l10n;
  final Future<void> Function(int rating, String comment) onSubmit;

  const RatingSheet({
    super.key,
    required this.title,
    required this.subjectName,
    required this.initial,
    required this.l10n,
    required this.onSubmit,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String subjectName,
    required HomeMyRating? initial,
    required AppLocalizations l10n,
    required Future<void> Function(int rating, String comment) onSubmit,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RatingSheet(
        title: title,
        subjectName: subjectName,
        initial: initial,
        l10n: l10n,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<RatingSheet> {
  late int _rating;
  late final TextEditingController _commentCtrl;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _rating = widget.initial?.rating ?? 0;
    _commentCtrl = TextEditingController(text: widget.initial?.comment ?? '');
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating < 1 || _rating > 5) {
      setState(() => _error = widget.l10n.ratingRequired);
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
    final isUpdate = widget.initial != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.borderColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: AppTheme.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (widget.subjectName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    widget.subjectName,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppTheme.secondaryText,
                      fontSize: 14,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final filled = i < _rating;
                    return GestureDetector(
                      onTap: _submitting
                          ? null
                          : () => setState(() {
                              _rating = i + 1;
                              _error = null;
                            }),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          filled
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 40,
                          color: filled
                              ? AppTheme.luxuryAccent
                              : AppTheme.secondaryText,
                        ),
                      ),
                    );
                  }),
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
                  style: GoogleFonts.inter(
                    color: AppTheme.primaryText,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: l10n.ratingCommentHint,
                    hintStyle: GoogleFonts.inter(
                      color: AppTheme.secondaryText,
                      fontSize: 14,
                    ),
                    filled: true,
                    fillColor: AppTheme.softGoldBg,
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppTheme.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: AppTheme.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppTheme.luxuryAccent,
                      ),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: AppTheme.errorRed,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brandNavy,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppTheme.brandNavy.withAlpha(
                        150,
                      ),
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
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            isUpdate ? l10n.updateRating : l10n.submitRating,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
