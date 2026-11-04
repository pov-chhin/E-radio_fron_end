/// Hides most of an email address for display: `jane@gmail.com` becomes
/// `j••••@gmail.com` — the first letter, four dots (however long the name
/// really is, so its length isn't given away), then the domain.
String maskEmail(String email) {
  final at = email.indexOf('@');
  if (at <= 0) return email;
  return '${email[0]}••••${email.substring(at)}';
}
