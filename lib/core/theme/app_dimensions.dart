import 'package:flutter/material.dart';

class AppDimensions {
  /// Height of the mini player
  static const double miniPlayerHeight = 64.0;
  
  /// Height of the bottom navigation bar
  static const double bottomNavHeight = 80.0;
  
  /// Standard bottom padding required to clear the mini player and bottom nav bar
  static const double bottomClearance = 0.0;

  /// Returns the standard padding for a screen with a scrolling body, 
  /// ensuring content clears the mini-player and bottom navigation bar.
  static EdgeInsets getBottomNavPadding(BuildContext context) {
    return EdgeInsets.only(
      left: 16,
      top: 16,
      right: 16,
      bottom: bottomClearance + MediaQuery.of(context).viewPadding.bottom,
    );
  }
}
