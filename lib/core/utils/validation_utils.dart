class ValidationUtils {
  static final RegExp _emailRegex = RegExp(
    r'^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,64}$',
  );

  static bool isValidEmail(String value) => _emailRegex.hasMatch(value.trim());
}
