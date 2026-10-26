import '../core/exceptions/app_exception.dart';
import '../l10n/generated/app_localizations.dart';

/// Plain-language text for a failed explicit network action (sign in, create account). Field
/// errors are shown on their fields; this covers the rest.
String formErrorText(AppLocalizations l10n, Object error) {
  if (error is! AppException) return l10n.errorGeneric;
  if (error.kind == AppErrorKind.network || error.kind == AppErrorKind.timeout) {
    return l10n.errorNetwork;
  }
  if (error.statusCode == 429) return l10n.errorRateLimited;
  // A58: suspended by Khay Studios; the app's own words, not the server's.
  if (error.code == 'account_suspended') return l10n.errorAccountSuspended;
  if (error.kind == AppErrorKind.api && error.fields.isEmpty) return error.message;
  return l10n.errorGeneric;
}
