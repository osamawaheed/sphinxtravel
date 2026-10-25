import '../../models/chat_models.dart';

/// TEST ENVIRONMENT ONLY — never mixed with live Odoo data.
///
/// The Supabase project behind SUPABASE_URL is a TEST database. The explicit
/// test booking reference below is matched by `booking_reference`. The numeric
/// Odoo booking id is NEVER assumed from the reference.
class ChatTestConfig {
  ChatTestConfig._();

  static const String testBookingReference = 'RQ.TEST14596';

  /// Negative ids can never collide with real Odoo partner/user ids (> 0).
  /// They are only used when the app has no authenticated Odoo id for the
  /// sender AND the conversation is the explicit test booking.
  static const int testCustomerSenderId = -1;
  static const int testDriverSenderId = -2;

  static bool isTestReference(String? reference) =>
      (reference ?? '').trim().toUpperCase() == testBookingReference;

  static int testSenderIdFor(ChatRole role) =>
      role == ChatRole.customer ? testCustomerSenderId : testDriverSenderId;
}
