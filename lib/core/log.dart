import 'package:flutter/foundation.dart';

/// Diagnostic logging that is compiled out of release builds, so nothing
/// (not even error text) reaches logcat in production.
void logDebug(String message) {
  if (kDebugMode) debugPrint(message);
}
