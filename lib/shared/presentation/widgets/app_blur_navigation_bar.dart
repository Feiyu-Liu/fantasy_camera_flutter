import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../theme/app_theme.dart';

class AppBlurNavigationBar extends StatelessWidget {
  const AppBlurNavigationBar({
    required this.topInset,
    required this.title,
    required this.onBackPressed,
    this.backButtonKey,
    super.key,
  });

  static const double contentHeight = 50;

  final double topInset;
  final String title;
  final VoidCallback onBackPressed;
  final Key? backButtonKey;

  double get height => topInset + contentHeight;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.navBlurBackground,
            border: Border(
              bottom: BorderSide(color: colors.border, width: 0.5),
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: Padding(
              padding: EdgeInsets.only(top: topInset),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Positioned(
                    left: 12,
                    child: CupertinoButton(
                      key: backButtonKey,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(44, 44),
                      onPressed: onBackPressed,
                      child: Icon(
                        LucideIcons.chevronLeft,
                        color: colors.textPrimary,
                        size: 20,
                      ),
                    ),
                  ),
                  Text(
                    title,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
