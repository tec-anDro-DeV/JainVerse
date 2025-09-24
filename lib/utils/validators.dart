class Validators {
  // Email validation
  static bool isValidEmail(String email) {
    final RegExp emailRegExp = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegExp.hasMatch(email);
  }

  // Phone number validation (10-digit format)
  static bool isValidPhoneNumber(String phone) {
    // Match exactly 10 digits (can be preceded by a plus sign)
    final RegExp phoneRegExp = RegExp(r'^(\+)?[0-9]{10}$');
    return phoneRegExp.hasMatch(phone);
  }

  // Name validation (allow alphabets, spaces and some special characters)
  static bool isValidName(String name) {
    final RegExp nameRegExp = RegExp(r"^[a-zA-Z\s.\'-]{1,50}$");
    return nameRegExp.hasMatch(name);
  }

  // Password validation
  static bool isValidPassword(String password) {
    return password.length >= 6;
  }

  // Validate password contains at least one uppercase, one lowercase, one number and one special character
  static bool isStrongPassword(String password) {
    if (password.length < 8) return false;

    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasLowercase = password.contains(RegExp(r'[a-z]'));
    bool hasDigit = password.contains(RegExp(r'[0-9]'));
    bool hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    return hasUppercase && hasLowercase && hasDigit && hasSpecialChar;
  }

  // Function to check if password and confirm password match
  static bool doPasswordsMatch(String password, String confirmPassword) {
    return password == confirmPassword;
  }

  // Function to get validation error message for email
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'Email is required';
    }
    if (!isValidEmail(email)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  // Function to get validation error message for name
  static String? validateName(
    String? name, {
    int minLength = 1,
    int maxLength = 50,
    String fieldName = 'Name',
  }) {
    if (name == null || name.isEmpty) {
      return '$fieldName is required';
    }
    if (name.length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }
    if (name.length > maxLength) {
      return '$fieldName cannot exceed $maxLength characters';
    }
    if (!isValidName(name)) {
      return '$fieldName can only contain letters, spaces, and some special characters';
    }
    return null;
  }

  // Function to get validation error message for phone
  static String? validatePhone(String? phone) {
    if (phone == null || phone.isEmpty) {
      return null; // Phone is optional
    }
    if (!isValidPhoneNumber(phone)) {
      return 'Please enter a valid 10-digit phone number';
    }
    return null;
  }

  // Function to get validation error message for password
  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  // Function to check password strength and provide feedback
  static String? validatePasswordStrength(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }
    if (password.length < 8) {
      return 'Password should be at least 8 characters';
    }

    bool hasUppercase = password.contains(RegExp(r'[A-Z]'));
    bool hasLowercase = password.contains(RegExp(r'[a-z]'));
    bool hasDigit = password.contains(RegExp(r'[0-9]'));
    bool hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));

    List<String> missing = [];
    if (!hasUppercase) missing.add('uppercase letter');
    if (!hasLowercase) missing.add('lowercase letter');
    if (!hasDigit) missing.add('number');
    if (!hasSpecialChar) missing.add('special character');

    if (missing.isNotEmpty) {
      return 'Password should include at least one ${missing.join(', ')}';
    }

    return null;
  }

  // Function to get validation error message for confirm password
  static String? validateConfirmPassword(
    String? password,
    String? confirmPassword,
  ) {
    if (confirmPassword == null || confirmPassword.isEmpty) {
      return 'Please confirm your password';
    }
    if (password != confirmPassword) {
      return 'Passwords do not match';
    }
    return null;
  }
}
