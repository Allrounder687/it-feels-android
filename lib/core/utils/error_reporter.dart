import 'package:flutter/material.dart';

/// `ErrorReporter` is a utility class for displaying user-friendly error messages
/// (e.g., via SnackBar or Dialog) throughout the application.
///
/// This centralizes error presentation, ensuring consistency and better user feedback
/// than just logging to the console.
class ErrorReporter {
  /// Displays a SnackBar with a given [message] to the user.
  ///
  /// Requires a [BuildContext] to find the nearest [ScaffoldMessenger].
  ///
  /// Usage:
  /// `ErrorReporter.showError(context, 'Failed to load songs. Please check your internet connection.');`
  static void showError(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // TODO: Potentially add more sophisticated error reporting, e.g.,
  // static void showDialogError(BuildContext context, String title, String message) { ... }
}
