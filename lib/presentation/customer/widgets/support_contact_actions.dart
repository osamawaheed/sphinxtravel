import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/app_localizations.dart';

/// Shared Support contact actions used by both Customer and Driver apps.
class SupportContactActions {
  SupportContactActions._();

  static const String callNumber = '+994508098606';
  static const String whatsappNumber = '+995555559153';

  static void _notify(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static Future<bool> _tryLaunch(Uri uri, {LaunchMode? mode}) async {
    try {
      return await launchUrl(uri, mode: mode ?? LaunchMode.platformDefault);
    } catch (_) {
      return false;
    }
  }

  /// Opens the phone dialer with the number prefilled.
  static Future<void> call(BuildContext context) async {
    final failMessage = AppLocalizations.of(context).hotelActionFailed;
    final ok = await _tryLaunch(
      Uri(scheme: 'tel', path: callNumber),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) _notify(context, failMessage);
  }

  /// Opens a direct WhatsApp chat (app if available, browser fallback).
  /// No message text is prefilled or sent.
  static Future<void> whatsapp(BuildContext context) async {
    final failMessage = AppLocalizations.of(context).hotelActionFailed;
    final digits = whatsappNumber.replaceAll(RegExp(r'[^0-9]'), '');

    // 1) Native WhatsApp app
    var ok = await _tryLaunch(
      Uri.parse('whatsapp://send?phone=$digits'),
      mode: LaunchMode.externalApplication,
    );
    // 2) Fallback: wa.me (WhatsApp app if installed, otherwise browser)
    if (!ok) {
      ok = await _tryLaunch(
        Uri.parse('https://wa.me/$digits'),
        mode: LaunchMode.externalApplication,
      );
    }
    // 3) Last resort: in-app browser view
    if (!ok) {
      ok = await _tryLaunch(
        Uri.parse('https://wa.me/$digits'),
        mode: LaunchMode.platformDefault,
      );
    }
    if (!ok) _notify(context, failMessage);
  }

  /// Opens the default email app addressed to [email]. Nothing is sent.
  static Future<void> email(BuildContext context, String? email) async {
    final failMessage = AppLocalizations.of(context).hotelActionFailed;
    final address = (email ?? '').trim();
    if (address.isEmpty) {
      _notify(context, failMessage);
      return;
    }
    final ok = await _tryLaunch(
      Uri(scheme: 'mailto', path: address),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) _notify(context, failMessage);
  }
}
