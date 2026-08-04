import 'package:flutter/material.dart';
import 'package:it_feels_music/core/theme/theme_ext.dart';
import 'package:it_feels_music/core/theme/app_dimensions.dart';

class AppScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final Color? backgroundColor;
  final bool requiresBottomNavClearance;
  final Widget? bottomNavigationBar;
  final bool safeAreaTop;
  final bool safeAreaBottom;

  const AppScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.backgroundColor,
    this.requiresBottomNavClearance = false,
    this.bottomNavigationBar,
    this.safeAreaTop = true,
    this.safeAreaBottom = true,
  });

  @override
  Widget build(BuildContext context) {
    // If the body is a CustomScrollView or ListView, injecting padding here doesn't help scrolling.
    // However, if it's a fixed screen, we can wrap the body in padding.
    // For lists, developers should use AppDimensions.getBottomNavPadding(context) inside their builders.
    
    Widget content = body;
    
    if (requiresBottomNavClearance) {
      content = Padding(
        padding: EdgeInsets.only(bottom: AppDimensions.bottomClearance + MediaQuery.of(context).viewPadding.bottom),
        child: content,
      );
    }

    content = SafeArea(
      top: safeAreaTop,
      bottom: safeAreaBottom,
      child: content,
    );

    return Scaffold(
      backgroundColor: backgroundColor ?? context.themeBackgroundColor,
      appBar: appBar,
      body: content,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
