import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:toastification/toastification.dart';

import '../../auth/presentation/auth_providers.dart';
import '../../features/generation_submission/domain/generation_record.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_corners.dart';
import '../../theme/app_theme.dart';

enum AppToastType { success, error, warning, info }

class AppToastMessage {
  const AppToastMessage({
    required this.type,
    required this.title,
    this.message,
    this.dedupeKey,
    this.duration = const Duration(seconds: 4),
  });

  final AppToastType type;
  final String title;
  final String? message;
  final String? dedupeKey;
  final Duration duration;
}

final appToastPresenterProvider = Provider<AppToastPresenter>(
  (Ref ref) => AppToastPresenter(),
  dependencies: const <ProviderOrFamily>[],
);

final appToastServiceProvider = Provider<AppToastService>(
  (Ref ref) {
    return AppToastService(
      presenter: ref.watch(appToastPresenterProvider),
      localizations: ref.watch(appLocalizationsProvider),
    );
  },
  dependencies: <ProviderOrFamily>[
    appLocalizationsProvider,
    appToastPresenterProvider,
  ],
);

class AppToastHost extends StatelessWidget {
  const AppToastHost({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ToastificationWrapper(child: child);
  }
}

class AppToastPresenter {
  final Map<String, DateTime> _lastShownAtByKey = <String, DateTime>{};

  void show(AppToastMessage message) {
    final String? dedupeKey = message.dedupeKey;
    final DateTime now = DateTime.now();
    if (dedupeKey != null && dedupeKey.isNotEmpty) {
      final DateTime? lastShownAt = _lastShownAtByKey[dedupeKey];
      if (lastShownAt != null &&
          now.difference(lastShownAt) < const Duration(seconds: 2)) {
        return;
      }
      _lastShownAtByKey[dedupeKey] = now;
    }

    toastification.showCustom(
      alignment: Alignment.topCenter,
      autoCloseDuration: message.duration,
      animationDuration: const Duration(milliseconds: 260),
      animationBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Alignment alignment,
            Widget child,
          ) {
            final Animation<double> curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.18),
                  end: Offset.zero,
                ).animate(curved),
                child: child,
              ),
            );
          },
      builder: (BuildContext context, ToastificationItem holder) {
        return AppToastCard(message: message, holder: holder);
      },
    );
  }
}

class AppToastService {
  const AppToastService({
    required AppToastPresenter presenter,
    required AppLocalizations localizations,
  }) : _presenter = presenter,
       _localizations = localizations;

  final AppToastPresenter _presenter;
  final AppLocalizations _localizations;

  void show(AppToastMessage message) {
    _presenter.show(message);
  }

  void showGenerationSubmitFailure({
    String? errorCode,
    GenerationRecordFailureStage? failureStage,
  }) {
    show(
      AppToastMessage(
        type: AppToastType.error,
        title: _generationSubmitFailureMessage(errorCode, failureStage),
        dedupeKey:
            'generation.submit.${failureStage?.name ?? errorCode ?? 'unknown'}',
      ),
    );
  }

  void showResultSaveFailure() {
    show(
      AppToastMessage(
        type: AppToastType.error,
        title: _localizations.toastResultSaveFailed,
        dedupeKey: 'generation.result.save_failed',
      ),
    );
  }

  void showGalleryImportFailure(Object error) {
    final String text = error.toString();
    final bool exportFailed =
        text.contains('export_failed') ||
        text.contains('PHPhotosErrorDomain') ||
        text.contains('iCloud');
    show(
      AppToastMessage(
        type: AppToastType.error,
        title: exportFailed
            ? _localizations.toastGalleryICloudImportFailed
            : _localizations.toastGalleryImportFailed,
        dedupeKey: exportFailed ? 'gallery.import.icloud' : 'gallery.import',
      ),
    );
  }

  void showFavoriteFailure() {
    show(
      AppToastMessage(
        type: AppToastType.error,
        title: _localizations.toastFavoriteFailed,
        dedupeKey: 'gallery.favorite.failed',
      ),
    );
  }

  void showSaveOriginalSuccess() {
    show(
      AppToastMessage(
        type: AppToastType.success,
        title: _localizations.toastOriginalSaved,
        dedupeKey: 'gallery.original.saved',
      ),
    );
  }

  void showSaveOriginalFailure() {
    show(
      AppToastMessage(
        type: AppToastType.error,
        title: _localizations.toastOriginalSaveFailed,
        dedupeKey: 'gallery.original.save_failed',
      ),
    );
  }

  void showFeedbackSuccess() {
    show(
      AppToastMessage(
        type: AppToastType.success,
        title: _localizations.toastFeedbackSubmitted,
        dedupeKey: 'gallery.feedback.submitted',
      ),
    );
  }

  void showFeedbackFailure() {
    show(
      AppToastMessage(
        type: AppToastType.error,
        title: _localizations.toastFeedbackFailed,
        dedupeKey: 'gallery.feedback.failed',
      ),
    );
  }

  void showOpenPhotoLibraryFailure() {
    show(
      AppToastMessage(
        type: AppToastType.error,
        title: _localizations.toastOpenPhotoLibraryFailed,
        dedupeKey: 'gallery.open_library.failed',
      ),
    );
  }

  void showClearOriginalCacheSuccess({String? message}) {
    show(
      AppToastMessage(
        type: AppToastType.success,
        title: _localizations.settingsClearOriginalCacheDoneTitle,
        message: message,
        dedupeKey: 'settings.original_cache.clear.success',
      ),
    );
  }

  void showClearOriginalCachePartial({String? message}) {
    show(
      AppToastMessage(
        type: AppToastType.warning,
        title: _localizations.settingsClearOriginalCachePartialTitle,
        message: message,
        dedupeKey: 'settings.original_cache.clear.partial',
      ),
    );
  }

  void showClearOriginalCacheFailure({String? message}) {
    show(
      AppToastMessage(
        type: AppToastType.error,
        title: _localizations.settingsClearOriginalCacheFailedTitle,
        message:
            message ?? _localizations.settingsClearOriginalCacheFailedMessage,
        dedupeKey: 'settings.original_cache.clear.failed',
      ),
    );
  }

  void showPurchaseFailure() {
    show(
      AppToastMessage(
        type: AppToastType.error,
        title: _localizations.toastPurchaseFailed,
        dedupeKey: 'billing.purchase.failed',
      ),
    );
  }

  void showPurchaseSuccess(int credits) {
    show(
      AppToastMessage(
        type: AppToastType.success,
        title: _localizations.toastPurchaseSuccess(credits),
        dedupeKey: 'billing.purchase.success',
      ),
    );
  }

  void showRestorePurchaseFailure() {
    show(
      AppToastMessage(
        type: AppToastType.error,
        title: _localizations.toastRestorePurchaseFailed,
        dedupeKey: 'billing.restore.failed',
      ),
    );
  }

  void showCreditRedemptionSuccess(int credits) {
    show(
      AppToastMessage(
        type: AppToastType.success,
        title: _localizations.toastCreditRedemptionSuccess(credits),
        dedupeKey: 'billing.redemption.success',
      ),
    );
  }

  void showCreditRedemptionFailure(String? errorCode) {
    show(
      AppToastMessage(
        type: AppToastType.error,
        title: _creditRedemptionFailureMessage(errorCode),
        dedupeKey: 'billing.redemption.${errorCode ?? 'failed'}',
      ),
    );
  }

  String _generationSubmitFailureMessage(
    String? errorCode,
    GenerationRecordFailureStage? failureStage,
  ) {
    final String? stageMessage = switch (failureStage) {
      GenerationRecordFailureStage.creatingUpload ||
      GenerationRecordFailureStage.uploading =>
        _localizations.toastGenerationUploadFailed,
      GenerationRecordFailureStage.creatingTask =>
        _localizations.toastGenerationTaskCreateFailed,
      GenerationRecordFailureStage.backendGeneration =>
        _localizations.toastGenerationBackendFailed,
      GenerationRecordFailureStage.processingResult ||
      GenerationRecordFailureStage.resultSaving =>
        _localizations.toastResultSaveFailed,
      GenerationRecordFailureStage.originalUnavailable =>
        _localizations.toastOriginalUnavailable,
      GenerationRecordFailureStage.preparingUploadImage ||
      GenerationRecordFailureStage.pollingTask ||
      GenerationRecordFailureStage.local ||
      null => null,
    };
    if (stageMessage != null) {
      return stageMessage;
    }
    return switch (errorCode) {
      'network_timeout' ||
      'network_error' => _localizations.toastGenerationNetworkFailed,
      'original_unavailable' => _localizations.toastOriginalUnavailable,
      'insufficient_credits' ||
      'insufficient_credit' ||
      'credits_insufficient' ||
      'not_enough_credits' => _localizations.toastInsufficientCredits,
      _ => _localizations.toastGenerationSubmitFailed,
    };
  }

  String _creditRedemptionFailureMessage(String? errorCode) {
    return switch (errorCode) {
      'invalid_redemption_code' => _localizations.toastCreditRedemptionInvalid,
      'redemption_code_unavailable' ||
      'redemption_code_expired' ||
      'redemption_code_revoked' ||
      'redemption_code_redeemed' =>
        _localizations.toastCreditRedemptionUnavailable,
      'redemption_campaign_user_limit_reached' =>
        _localizations.toastCreditRedemptionCampaignLimitReached,
      'redemption_rate_limited' =>
        _localizations.toastCreditRedemptionRateLimited,
      _ => _localizations.toastCreditRedemptionFailed,
    };
  }
}

class AppToastCard extends StatelessWidget {
  const AppToastCard({required this.message, this.holder, super.key});

  final AppToastMessage message;
  final ToastificationItem? holder;

  @override
  Widget build(BuildContext context) {
    final AppThemeColors colors = AppThemeColors.of(context);
    final _AppToastStyle style = _AppToastStyle.forType(message.type);
    final String? detail = message.message;
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double cardWidth = (screenWidth - 40).clamp(0.0, 420.0);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: cardWidth,
            child: GestureDetector(
              onTap: holder == null
                  ? null
                  : () => toastification.dismiss(holder!),
              onTapDown: holder == null ? null : (_) => holder!.pause(),
              onTapUp: holder == null ? null : (_) => holder!.start(),
              onTapCancel: holder == null ? null : () => holder!.start(),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: colors.isDark
                          ? AppColors.black.withValues(alpha: 0.78)
                          : AppColors.white.withValues(alpha: 0.88),
                      shape: SmoothRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        smoothness: AppCorners.smoothness,
                        side: BorderSide(
                          color: colors.isDark
                              ? AppColors.white.withValues(alpha: 0.16)
                              : AppColors.black.withValues(alpha: 0.12),
                          width: 0.8,
                        ),
                      ),
                      shadows: <BoxShadow>[
                        BoxShadow(
                          color: colors.shadow,
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(13, 12, 14, 12),
                      child: Row(
                        crossAxisAlignment: detail == null
                            ? CrossAxisAlignment.center
                            : CrossAxisAlignment.start,
                        children: <Widget>[
                          _ToastIcon(style: style),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  message.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    height: 1.18,
                                  ),
                                ),
                                if (detail != null) ...<Widget>[
                                  const SizedBox(height: 3),
                                  Text(
                                    detail,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w400,
                                      height: 1.2,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ToastIcon extends StatelessWidget {
  const _ToastIcon({required this.style});

  final _AppToastStyle style;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      child: SizedBox.square(
        dimension: 26,
        child: Icon(style.icon, color: style.color, size: 15),
      ),
    );
  }
}

class _AppToastStyle {
  const _AppToastStyle({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  static _AppToastStyle forType(AppToastType type) {
    return switch (type) {
      AppToastType.success => const _AppToastStyle(
        icon: LucideIcons.circleCheck,
        color: AppColors.purchaseSuccessGreen,
      ),
      AppToastType.error => const _AppToastStyle(
        icon: LucideIcons.circleAlert,
        color: AppColors.danger,
      ),
      AppToastType.warning => const _AppToastStyle(
        icon: LucideIcons.triangleAlert,
        color: Color(0xFFB78300),
      ),
      AppToastType.info => const _AppToastStyle(
        icon: LucideIcons.info,
        color: AppColors.link,
      ),
    };
  }
}
