import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_config.dart';
import '../../features/camera/presentation/camera_providers.dart';
import '../../features/camera/presentation/camera_screen.dart';
import '../../features/camera/presentation/camera_ui/camera_photo_ui.dart';
import '../../features/camera/presentation/camera_ui/camera_ui_tokens.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';
import '../domain/auth_session_state.dart';
import 'auth_page.dart';
import 'auth_providers.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(hasSupabaseConfigProvider)) {
      return const _ConfigErrorPage();
    }

    final AsyncValue<AuthSessionState> authState = ref.watch(
      authSessionProvider,
    );
    return authState.when(
      data: (AuthSessionState state) {
        if (state.isSignedIn) {
          return const _SignedInCameraEntry();
        }
        if (state.status == AuthSessionStatus.restoring) {
          return const AuthCameraLoadingPage();
        }
        return AuthPage(sessionMessage: state.message);
      },
      loading: () => const AuthCameraLoadingPage(),
      error: (_, _) =>
          AuthPage(sessionMessage: context.l10n.authSessionRestoreFailed),
    );
  }
}

class _SignedInCameraEntry extends ConsumerWidget {
  const _SignedInCameraEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final choices = ref.watch(signedInCameraChoicesProvider);
    return choices.when(
      data: (cameraChoices) {
        return ProviderScope(
          overrides: <Override>[
            cameraChoicesProvider.overrideWithValue(cameraChoices),
          ],
          child: const CameraScreen(),
        );
      },
      loading: () => const AuthCameraLoadingPage(),
      error: (_, _) =>
          AuthPage(sessionMessage: context.l10n.authCameraDevicesLoadFailed),
    );
  }
}

class AuthCameraLoadingPage extends StatelessWidget {
  const AuthCameraLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    final CameraUiTokens tokens = CameraUiTokens.forTheme(
      context,
      dividerWidth: AppConfig.cameraUiDividerWidth,
    );
    return CupertinoPageScaffold(
      backgroundColor: colors.cameraBackground,
      child: ColoredBox(
        color: tokens.backgroundColor,
        child: Column(
          children: <Widget>[
            _LoadingTopBar(tokens: tokens),
            Expanded(child: _LoadingCameraBody(tokens: tokens)),
          ],
        ),
      ),
    );
  }
}

class _LoadingTopBar extends StatelessWidget {
  const _LoadingTopBar({required this.tokens});

  final CameraUiTokens tokens;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: tokens.backgroundColor,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: tokens.topBarHeight,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: tokens.dividerColor,
                width: tokens.dividerWidth,
              ),
            ),
          ),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: tokens.topBarButtonSize,
                child: _LoadingTopBarPlaceholder(tokens: tokens),
              ),
              SizedBox(
                width: tokens.topBarButtonSize,
                child: _LoadingTopBarPlaceholder(tokens: tokens),
              ),
              const Spacer(flex: 5),
              SizedBox(
                width: tokens.topBarTrailingWidth,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(
                        color: tokens.dividerColor,
                        width: tokens.dividerWidth,
                      ),
                    ),
                  ),
                  child: _LoadingTopBarPlaceholder(tokens: tokens),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _loadingPanelBackground(
  CameraUiTokens tokens,
  CameraPhotoControlsPlacement placement,
) {
  return switch (placement) {
    CameraPhotoControlsPlacement.belowHero => tokens.backgroundColor,
    CameraPhotoControlsPlacement.heroOverlay =>
      tokens.backgroundColor.withValues(alpha: 0.86),
  };
}

class _LoadingCameraBody extends StatelessWidget {
  const _LoadingCameraBody({required this.tokens});

  final CameraUiTokens tokens;

  @override
  Widget build(BuildContext context) {
    return CameraPhotoBodyLayout(
      tokens: tokens,
      minimumBottomHeight: tokens.modeRowHeight + tokens.bottomControlsHeight,
      viewfinder: ColoredBox(color: tokens.viewfinderColor),
      controlsBuilder:
          (BuildContext context, CameraPhotoControlsPlacement placement) {
            final Color panelColor = _loadingPanelBackground(tokens, placement);
            if (placement == CameraPhotoControlsPlacement.heroOverlay) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _LoadingModeSelector(
                    tokens: tokens,
                    backgroundColor: panelColor,
                  ),
                  Transform.translate(
                    offset: Offset(
                      0,
                      -tokens.collapsedBottomControlsVisualLift,
                    ),
                    child: _LoadingBottomControls(
                      tokens: tokens,
                      backgroundColor: panelColor,
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: <Widget>[
                _LoadingModeSelector(
                  tokens: tokens,
                  backgroundColor: panelColor,
                ),
                Expanded(
                  child: Align(
                    alignment: const Alignment(0, -0.42),
                    child: _LoadingBottomControls(
                      tokens: tokens,
                      backgroundColor: panelColor,
                    ),
                  ),
                ),
              ],
            );
          },
    );
  }
}

class _LoadingModeSelector extends StatelessWidget {
  const _LoadingModeSelector({required this.tokens, this.backgroundColor});

  final CameraUiTokens tokens;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: backgroundColor ?? tokens.backgroundColor,
          border: Border(
            top: BorderSide(
              color: tokens.dividerColor,
              width: tokens.dividerWidth,
            ),
          ),
        ),
        child: SizedBox(
          height: tokens.modeRowHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: tokens.dividerColor,
                  width: tokens.dividerWidth,
                ),
              ),
            ),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double contentWidth = constraints.maxWidth;
                final double autoLeft =
                    (contentWidth - tokens.modeItemWidth * 2) / 2;
                return Stack(
                  children: <Widget>[
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          _LoadingModeLabel(
                            tokens: tokens,
                            label: context.l10n.promptCaptureModeGeneralTitle,
                            selected: true,
                          ),
                          _LoadingModeLabel(
                            tokens: tokens,
                            label: context.l10n.promptCaptureModePortraitTitle,
                            selected: false,
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left:
                          autoLeft +
                          (tokens.modeItemWidth - tokens.modeIndicatorWidth) /
                              2,
                      bottom: tokens.modeIndicatorBottomOffset,
                      width: tokens.modeIndicatorWidth,
                      height: tokens.modeIndicatorHeight,
                      child: ColoredBox(color: tokens.primaryTextColor),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingModeLabel extends StatelessWidget {
  const _LoadingModeLabel({
    required this.tokens,
    required this.label,
    required this.selected,
  });

  final CameraUiTokens tokens;
  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: tokens.modeItemWidth,
      height: double.infinity,
      child: Padding(
        padding: tokens.modeItemPadding,
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
              textScaler: TextScaler.noScaling,
              style:
                  (selected
                          ? tokens.modeSelectedTextStyle
                          : tokens.modeUnselectedTextStyle)
                      .copyWith(
                        color: selected
                            ? tokens.primaryTextColor
                            : tokens.inactiveColor,
                      ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingBottomControls extends StatelessWidget {
  const _LoadingBottomControls({required this.tokens, this.backgroundColor});

  final CameraUiTokens tokens;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor ?? tokens.backgroundColor,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: tokens.bottomControlsHeight,
          child: Padding(
            padding: tokens.bottomControlsPadding,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Align(
                  alignment: Alignment.centerLeft,
                  child: _LoadingSquareControl(tokens: tokens),
                ),
                _LoadingShutter(tokens: tokens),
                Align(
                  alignment: Alignment.centerRight,
                  child: _LoadingCircleControl(tokens: tokens),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingTopBarPlaceholder extends StatelessWidget {
  const _LoadingTopBarPlaceholder({required this.tokens});

  final CameraUiTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Icon(
      CupertinoIcons.circle,
      size: tokens.topBarIconSize,
      color: tokens.primaryTextColor.withValues(alpha: 0.18),
    );
  }
}

class _LoadingSquareControl extends StatelessWidget {
  const _LoadingSquareControl({required this.tokens});

  final CameraUiTokens tokens;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: tokens.primaryTextColor.withValues(alpha: 0.24),
          width: tokens.dividerWidth,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SizedBox(
        width: tokens.galleryButtonSize,
        height: tokens.galleryButtonSize,
      ),
    );
  }
}

class _LoadingCircleControl extends StatelessWidget {
  const _LoadingCircleControl({required this.tokens});

  final CameraUiTokens tokens;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: tokens.primaryTextColor.withValues(alpha: 0.24),
          width: tokens.dividerWidth,
        ),
      ),
      child: SizedBox(
        width: tokens.flipButtonSize,
        height: tokens.flipButtonSize,
      ),
    );
  }
}

class _LoadingShutter extends StatelessWidget {
  const _LoadingShutter({required this.tokens});

  final CameraUiTokens tokens;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: tokens.primaryTextColor.withValues(alpha: 0.28),
          width: tokens.shutterOuterBorderWidth,
        ),
      ),
      child: Padding(
        padding: tokens.shutterInnerPadding,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tokens.primaryTextColor.withValues(alpha: 0.14),
          ),
          child: SizedBox.square(
            dimension:
                tokens.shutterSize - tokens.shutterInnerPadding.horizontal,
          ),
        ),
      ),
    );
  }
}

class _ConfigErrorPage extends StatelessWidget {
  const _ConfigErrorPage();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              context.l10n.authMissingSupabaseConfig,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.white, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}
