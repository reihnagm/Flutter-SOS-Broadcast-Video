import 'package:flutter/cupertino.dart';

/// Global variables
/// * [GlobalKey<NavigatorState>]
class GlobalVariable {
  
  /// This global key is used in material app for navigation through firebase notifications.
  /// [navState] usage can be found in [notification_notifier.dart] file.
  static final GlobalKey<NavigatorState> navState = GlobalKey<NavigatorState>();

  static int createUniqueId() => DateTime.now().millisecondsSinceEpoch.remainder(100000);
}