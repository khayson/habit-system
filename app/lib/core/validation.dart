/// Client-side checks that mirror the API's rules. The server still validates everything.
abstract final class Validation {
  /// Something@something: no TLD length limit and no character whitelist beyond that; the server
  /// decides what is deliverable.
  static final RegExp _email = RegExp(r'^[^\s@]+@[^\s@]+$');

  static const int passwordMinLength = 12;
  static const int nameMaxLength = 80;
  static const int habitNameMaxLength = 100;

  static bool isEmail(String value) => _email.hasMatch(value.trim());
  static bool isPassword(String value) => value.length >= passwordMinLength;
}
