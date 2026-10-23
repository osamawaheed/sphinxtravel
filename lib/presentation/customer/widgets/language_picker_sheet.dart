import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/localization_service.dart';
import '../../../theme/app_theme.dart';

/// Bottom sheet that lets the user pick the app language for their role.
/// Uses the existing [LocalizationService] — applies instantly and persists.
class LanguagePickerSheet extends StatelessWidget {
  final String role;
  final bool isDark;

  const LanguagePickerSheet({
    super.key,
    required this.role,
    this.isDark = false,
  });

  static Future<void> show(
    BuildContext context, {
    required String role,
    bool isDark = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LanguagePickerSheet(role: role, isDark: isDark),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = LocalizationService.instance;
    final l10n = AppLocalizations.of(context);
    final languages = LocalizationService.languagesForRole(role);
    final sheetBg = isDark ? AppTheme.darkCard : AppTheme.cardWhite;
    final border = isDark ? AppTheme.darkBorderColor : AppTheme.borderColor;
    final textColor = isDark ? AppTheme.darkPrimaryText : AppTheme.primaryText;
    final subColor = isDark
        ? AppTheme.darkSecondaryText
        : AppTheme.secondaryText;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
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
                    color: border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.chooseYourLanguage,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              ...languages.map((lang) {
                final selected = service.currentLanguage == lang['code'];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () async {
                      await service.setLanguage(lang['code']!, role: role);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.softGoldBg : sheetBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected ? AppTheme.luxuryAccent : border,
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            lang['flag']!,
                            style: const TextStyle(fontSize: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang['label']!,
                                  style: GoogleFonts.inter(
                                    color: selected
                                        ? AppTheme.brandNavy
                                        : textColor,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  lang['sublabel']!,
                                  style: GoogleFonts.inter(
                                    color: subColor,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          selected
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppTheme.luxuryAccent,
                                  size: 22,
                                )
                              : Icon(
                                  Icons.circle_outlined,
                                  color: subColor,
                                  size: 22,
                                ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
