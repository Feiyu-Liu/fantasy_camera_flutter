import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../auth/domain/auth_user.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../app/app_router.dart';
import '../../features/backend_api/domain/credit_balance.dart';
import '../../features/backend_api/presentation/backend_api_providers.dart';
import '../../features/generation_submission/application/generation_original_cache_cleaner.dart';
import '../../features/generation_submission/presentation/generation_submission_providers.dart';
import '../../features/notifications/presentation/notification_providers.dart';
import '../../l10n/l10n.dart';
import '../../theme/app_colors.dart';
import '../application/app_settings.dart';

typedef SettingsSignOutAction = Future<void> Function();

final settingsSignOutActionProvider = Provider<SettingsSignOutAction>(
  (Ref ref) {
    return () async {
      await ref
          .read(notificationDeviceControllerProvider.notifier)
          .unregisterCurrentDevice();
      await ref.read(authControllerProvider.notifier).signOut();
    };
  },
  dependencies: <ProviderOrFamily>[
    notificationDeviceControllerProvider,
    authControllerProvider,
  ],
);

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  _AppearanceMode _appearanceMode = _AppearanceMode.editorialLight;
  bool _isClearingOriginalCache = false;
  bool _isSigningOut = false;
  GenerationOriginalCacheStats? _latestOriginalCacheStats;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<GenerationOriginalCacheStats>>(
      clearableOriginalCacheStatsProvider,
      (_, AsyncValue<GenerationOriginalCacheStats> next) {
        final GenerationOriginalCacheStats? stats = next.valueOrNull;
        if (stats == null || !mounted) {
          return;
        }
        setState(() {
          _latestOriginalCacheStats = stats;
        });
      },
    );
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<CreditBalance> creditBalance = ref.watch(
      creditBalanceProvider,
    );
    final AppSettingsState appSettings = ref.watch(
      appSettingsControllerProvider,
    );
    final AsyncValue<GenerationOriginalCacheStats?> cachedOriginalCacheStats =
        ref.watch(cachedOriginalCacheStatsProvider);
    final AsyncValue<GenerationOriginalCacheStats> clearableOriginalCacheStats =
        ref.watch(clearableOriginalCacheStatsProvider);
    final AuthUser? user = ref.watch(authSessionProvider).valueOrNull?.user;
    final double topInset = MediaQuery.paddingOf(context).top;
    final double navigationHeight = topInset + 50;
    return CupertinoPageScaffold(
      backgroundColor: AppColors.settingsBackground,
      child: Stack(
        children: <Widget>[
          ListView(
            padding: EdgeInsets.only(top: navigationHeight),
            physics: const BouncingScrollPhysics(),
            children: <Widget>[
              _ProfileHeader(
                userName: _displayNameFor(user, l10n),
                creditsLabel: _creditsLabelFor(creditBalance, l10n),
              ),
              _AppearanceSection(
                title: l10n.settingsSectionAppearance,
                lightTitle: l10n.settingsAppearanceLight,
                darkTitle: l10n.settingsAppearanceDark,
                selectedMode: _appearanceMode,
                onModeSelected: (_AppearanceMode mode) {
                  setState(() => _appearanceMode = mode);
                },
              ),
              const _SectionDivider(),
              _SectionTitle(l10n.settingsSectionCapture),
              _SettingsToggleRow(
                switchKey: const ValueKey<String>(
                  'settings-confirm-before-generation-switch',
                ),
                title: l10n.settingsConfirmBeforeGenerationTitle,
                subtitle: l10n.settingsConfirmBeforeGenerationSubtitle,
                value: appSettings.confirmBeforeGenerationEnabled,
                onChanged: (bool value) {
                  ref
                      .read(appSettingsControllerProvider.notifier)
                      .setConfirmBeforeGenerationEnabled(value);
                },
              ),
              const _SectionDivider(),
              _SectionTitle(l10n.settingsSectionGeneral),
              _SettingsActionRow(
                title: l10n.settingsLanguageTitle,
                subtitle: _languagePreferenceLabel(
                  appSettings.localePreference,
                  l10n,
                ),
                onPressed: () => _showLanguagePicker(appSettings),
              ),
              _SettingsActionRow(
                title: l10n.settingsClearOriginalCacheTitle,
                subtitle: _originalCacheSubtitle(
                  l10n: l10n,
                  cachedStats: cachedOriginalCacheStats,
                  latestStats: clearableOriginalCacheStats,
                  latestLocalStats: _latestOriginalCacheStats,
                ),
                enabled: !_isClearingOriginalCache,
                trailing: _isClearingOriginalCache
                    ? const CupertinoActivityIndicator(radius: 8)
                    : null,
                onPressed: _confirmClearOriginalCache,
              ),
              _SettingsActionRow(
                title: l10n.settingsManageSubscriptionTitle,
                subtitle: l10n.settingsManageSubscriptionSubtitle,
                onPressed: _openCreditPurchase,
              ),
              const _SectionDivider(),
              _SectionTitle(l10n.settingsSectionInformation),
              _SettingsActionRow(
                title: l10n.settingsPrivacyPolicyTitle,
                subtitle: l10n.settingsPrivacyPolicySubtitle,
                onPressed: _handlePlaceholderAction,
              ),
              _SettingsActionRow(
                title: l10n.settingsTermsTitle,
                subtitle: l10n.settingsTermsSubtitle,
                onPressed: _handlePlaceholderAction,
              ),
              _SettingsActionRow(
                title: l10n.settingsAboutTitle,
                subtitle: l10n.settingsAboutSubtitle,
                onPressed: _handlePlaceholderAction,
              ),
              _SettingsActionRow(
                title: l10n.settingsContactDeveloperTitle,
                subtitle: l10n.settingsContactDeveloperSubtitle,
                onPressed: _handlePlaceholderAction,
              ),
              const _SectionDivider(),
              _SectionTitle(l10n.settingsSectionAccount),
              _SettingsActionRow(
                title: l10n.settingsDeleteAccountTitle,
                subtitle: l10n.settingsDeleteAccountSubtitle,
                onPressed: _handlePlaceholderAction,
              ),
              _SettingsActionRow(
                title: l10n.settingsSignOutTitle,
                subtitle: l10n.settingsSignOutSubtitle,
                enabled: !_isSigningOut,
                trailing: _isSigningOut
                    ? const CupertinoActivityIndicator(radius: 8)
                    : null,
                onPressed: _confirmSignOut,
              ),
              SizedBox(height: MediaQuery.paddingOf(context).bottom + 16),
            ],
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _SettingsNavigationBar(
              topInset: topInset,
              title: l10n.settingsTitle,
              onBackPressed: () => context.pop(),
            ),
          ),
        ],
      ),
    );
  }

  String _displayNameFor(AuthUser? user, AppLocalizations l10n) {
    final String? email = user?.email.trim();
    if (email != null && email.isNotEmpty) {
      final String emailPrefix = email.split('@').first.trim();
      if (emailPrefix.isNotEmpty) {
        return emailPrefix;
      }
      return email;
    }
    return l10n.settingsFallbackUserName;
  }

  String _creditsLabelFor(
    AsyncValue<CreditBalance> creditBalance,
    AppLocalizations l10n,
  ) {
    return creditBalance.when(
      data: (CreditBalance balance) =>
          l10n.settingsCreditsValue(balance.balance),
      error: (_, _) => l10n.settingsCreditsUnavailable,
      loading: () => l10n.settingsCreditsLoading,
    );
  }

  void _handlePlaceholderAction() {
    HapticFeedback.selectionClick();
  }

  Future<void> _confirmSignOut() async {
    if (_isSigningOut) {
      return;
    }
    HapticFeedback.selectionClick();
    final AppLocalizations l10n = context.l10n;
    final bool confirmed =
        await showCupertinoDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return CupertinoAlertDialog(
              title: Text(l10n.settingsSignOutConfirmTitle),
              content: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l10n.settingsSignOutConfirmMessage),
              ),
              actions: <Widget>[
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.commonCancel),
                ),
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(l10n.settingsSignOutConfirmAction),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }
    await _signOut();
  }

  Future<void> _signOut() async {
    if (_isSigningOut) {
      return;
    }
    setState(() {
      _isSigningOut = true;
    });
    Object? failure;
    try {
      await ref.read(settingsSignOutActionProvider).call();
      if (!mounted) {
        return;
      }
      await Navigator.of(context).maybePop();
    } on Object catch (error) {
      failure = error;
      debugPrint('[SettingsPage] sign out failure error=$error');
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }

    if (failure != null && mounted) {
      final AppLocalizations l10n = context.l10n;
      await showCupertinoDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          return CupertinoAlertDialog(
            title: Text(l10n.settingsSignOutFailedTitle),
            content: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(l10n.settingsSignOutFailedMessage),
            ),
            actions: <Widget>[
              CupertinoDialogAction(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(l10n.commonOK),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _clearOriginalCache() async {
    if (_isClearingOriginalCache) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _isClearingOriginalCache = true;
    });

    GenerationOriginalCacheClearResult? result;
    Object? failure;
    try {
      result = await ref
          .read(generationOriginalCacheCleanerProvider)
          .clearCameraOriginalCache();
    } on Object catch (error) {
      failure = error;
      debugPrint('[SettingsPage] clear original cache failure error=$error');
    } finally {
      ref.invalidate(clearableOriginalCacheStatsProvider);
      if (mounted) {
        setState(() {
          _isClearingOriginalCache = false;
        });
      }
    }

    if (!mounted) {
      return;
    }

    final AppLocalizations l10n = context.l10n;
    await showCupertinoDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final String title = failure == null
            ? l10n.settingsClearOriginalCacheDoneTitle
            : l10n.settingsClearOriginalCacheFailedTitle;
        final String message = failure == null && result != null
            ? _clearOriginalCacheMessage(result, l10n)
            : l10n.settingsClearOriginalCacheFailedMessage;
        return CupertinoAlertDialog(
          title: Text(title),
          content: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(message),
          ),
          actions: <Widget>[
            CupertinoDialogAction(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.commonOK),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmClearOriginalCache() async {
    if (_isClearingOriginalCache) {
      return;
    }
    HapticFeedback.selectionClick();
    final AppLocalizations l10n = context.l10n;
    final bool confirmed =
        await showCupertinoDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return CupertinoAlertDialog(
              title: Text(l10n.settingsClearOriginalCacheConfirmTitle),
              content: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l10n.settingsClearOriginalCacheConfirmMessage),
              ),
              actions: <Widget>[
                CupertinoDialogAction(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(l10n.commonCancel),
                ),
                CupertinoDialogAction(
                  isDestructiveAction: true,
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: Text(l10n.settingsClearOriginalCacheConfirmAction),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }
    await _clearOriginalCache();
  }

  String _clearOriginalCacheMessage(
    GenerationOriginalCacheClearResult result,
    AppLocalizations l10n,
  ) {
    if (result.hasFailures) {
      return l10n.settingsClearOriginalCachePartialMessage(
        result.clearedCount,
        result.failedCount,
      );
    }
    return l10n.settingsClearOriginalCacheDoneMessage(result.clearedCount);
  }

  String _originalCacheSubtitle({
    required AppLocalizations l10n,
    required AsyncValue<GenerationOriginalCacheStats?> cachedStats,
    required AsyncValue<GenerationOriginalCacheStats> latestStats,
    required GenerationOriginalCacheStats? latestLocalStats,
  }) {
    if (_isClearingOriginalCache) {
      return l10n.settingsClearOriginalCacheInProgress;
    }

    final GenerationOriginalCacheStats? latest =
        latestStats.valueOrNull ?? latestLocalStats;
    if (latest != null) {
      return _originalCacheStatsLabel(l10n: l10n, stats: latest, cached: false);
    }

    final GenerationOriginalCacheStats? cached = cachedStats.valueOrNull;
    if (cached != null) {
      return _originalCacheStatsLabel(l10n: l10n, stats: cached, cached: true);
    }

    if (latestStats.isLoading) {
      return l10n.settingsClearOriginalCacheCalculating;
    }

    return l10n.settingsClearOriginalCacheSubtitle;
  }

  String _originalCacheStatsLabel({
    required AppLocalizations l10n,
    required GenerationOriginalCacheStats stats,
    required bool cached,
  }) {
    if (stats.totalBytes <= 0) {
      return l10n.settingsClearOriginalCacheNoClearable;
    }
    final String formattedSize = _formatBytes(stats.totalBytes);
    if (cached) {
      return l10n.settingsClearOriginalCacheLastCalculatedSize(formattedSize);
    }
    return l10n.settingsClearOriginalCacheSize(formattedSize);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    const List<String> units = <String>['KB', 'MB', 'GB'];
    double size = bytes / 1024;
    int unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex += 1;
    }
    return '${size.toStringAsFixed(size >= 10 ? 1 : 2)} ${units[unitIndex]}';
  }

  void _openCreditPurchase() {
    HapticFeedback.selectionClick();
    context.push(creditPurchaseRoute);
  }

  String _languagePreferenceLabel(
    AppLocalePreference preference,
    AppLocalizations l10n,
  ) {
    return switch (preference) {
      AppLocalePreference.system => l10n.settingsLanguageSystem,
      AppLocalePreference.zh => l10n.settingsLanguageChinese,
      AppLocalePreference.en => l10n.settingsLanguageEnglish,
    };
  }

  Future<void> _showLanguagePicker(AppSettingsState appSettings) async {
    HapticFeedback.selectionClick();
    final AppLocalizations l10n = context.l10n;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext popupContext) {
        return CupertinoActionSheet(
          title: Text(l10n.settingsLanguageTitle),
          actions: <Widget>[
            _LanguageAction(
              title: l10n.settingsLanguageSystem,
              selected:
                  appSettings.localePreference == AppLocalePreference.system,
              onPressed: () => _selectLanguagePreference(
                popupContext,
                AppLocalePreference.system,
              ),
            ),
            _LanguageAction(
              title: l10n.settingsLanguageChinese,
              selected: appSettings.localePreference == AppLocalePreference.zh,
              onPressed: () => _selectLanguagePreference(
                popupContext,
                AppLocalePreference.zh,
              ),
            ),
            _LanguageAction(
              title: l10n.settingsLanguageEnglish,
              selected: appSettings.localePreference == AppLocalePreference.en,
              onPressed: () => _selectLanguagePreference(
                popupContext,
                AppLocalePreference.en,
              ),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(popupContext).pop(),
            child: Text(l10n.commonCancel),
          ),
        );
      },
    );
  }

  void _selectLanguagePreference(
    BuildContext popupContext,
    AppLocalePreference preference,
  ) {
    HapticFeedback.selectionClick();
    Navigator.of(popupContext).pop();
    ref
        .read(appSettingsControllerProvider.notifier)
        .setLocalePreference(preference);
  }
}

class _LanguageAction extends StatelessWidget {
  const _LanguageAction({
    required this.title,
    required this.selected,
    required this.onPressed,
  });

  final String title;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoActionSheetAction(
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(title),
          if (selected) ...<Widget>[
            const SizedBox(width: 8),
            const Icon(LucideIcons.check, size: 18),
          ],
        ],
      ),
    );
  }
}

class _SettingsNavigationBar extends StatelessWidget {
  const _SettingsNavigationBar({
    required this.topInset,
    required this.title,
    required this.onBackPressed,
  });

  final double topInset;
  final String title;
  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.settingsBackground.withValues(alpha: 0.72),
            border: const Border(
              bottom: BorderSide(color: AppColors.black, width: 0.5),
            ),
          ),
          child: SizedBox(
            width: double.infinity,
            height: topInset + 50,
            child: Padding(
              padding: EdgeInsets.only(top: topInset),
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  Positioned(
                    left: 12,
                    child: CupertinoButton(
                      key: const ValueKey<String>('settings-back-button'),
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(44, 44),
                      onPressed: onBackPressed,
                      child: const Icon(
                        LucideIcons.chevronLeft,
                        color: AppColors.black,
                        size: 20,
                      ),
                    ),
                  ),
                  Text(
                    title,
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      color: AppColors.black,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
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

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.userName, required this.creditsLabel});

  final String userName;
  final String creditsLabel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.black, width: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 34, 18, 36),
        child: Column(
          children: <Widget>[
            const _AvatarPlaceholder(),
            const SizedBox(height: 18),
            Text(
              userName,
              textAlign: TextAlign.center,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(
                color: AppColors.black,
                fontFamily: 'Times New Roman',
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  LucideIcons.tickets,
                  color: AppColors.settingsMutedText,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    creditsLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    textScaler: TextScaler.noScaling,
                    style: const TextStyle(
                      color: AppColors.settingsMutedText,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2.4,
                      height: 1,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.settingsAvatarBackground,
        border: Border.all(color: AppColors.black, width: 1),
      ),
      child: const Icon(LucideIcons.user, color: AppColors.black, size: 27),
    );
  }
}

enum _AppearanceMode { editorialLight, studioDark }

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({
    required this.title,
    required this.lightTitle,
    required this.darkTitle,
    required this.selectedMode,
    required this.onModeSelected,
  });

  final String title;
  final String lightTitle;
  final String darkTitle;
  final _AppearanceMode selectedMode;
  final ValueChanged<_AppearanceMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            textScaler: TextScaler.noScaling,
            style: const TextStyle(
              color: AppColors.settingsMutedText,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              height: 1,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: <Widget>[
              Expanded(
                child: _AppearanceOptionCard(
                  key: const ValueKey<String>(
                    'settings-appearance-editorial-light',
                  ),
                  title: lightTitle,
                  mode: _AppearanceMode.editorialLight,
                  selected: selectedMode == _AppearanceMode.editorialLight,
                  onSelected: onModeSelected,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _AppearanceOptionCard(
                  key: const ValueKey<String>(
                    'settings-appearance-studio-dark',
                  ),
                  title: darkTitle,
                  mode: _AppearanceMode.studioDark,
                  selected: selectedMode == _AppearanceMode.studioDark,
                  onSelected: onModeSelected,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppearanceOptionCard extends StatelessWidget {
  const _AppearanceOptionCard({
    required this.title,
    required this.mode,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String title;
  final _AppearanceMode mode;
  final bool selected;
  final ValueChanged<_AppearanceMode> onSelected;

  @override
  Widget build(BuildContext context) {
    final Color foreground = selected ? AppColors.white : AppColors.black;
    final Color background = selected ? AppColors.black : AppColors.white;
    final Color previewColor = selected
        ? AppColors.white
        : AppColors.darkSurface;
    final Color borderColor = AppColors.black;

    return Semantics(
      button: true,
      selected: selected,
      label: title,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: () {
          HapticFeedback.selectionClick();
          onSelected(mode);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          height: 126,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 17),
          decoration: BoxDecoration(
            color: background,
            border: Border.all(color: borderColor, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                height: 40,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 24),
                color: previewColor,
              ),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: foreground,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 19),
      child: Text(
        title,
        textScaler: TextScaler.noScaling,
        style: const TextStyle(
          color: AppColors.settingsMutedText,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.0,
          height: 1,
        ),
      ),
    );
  }
}

class _SectionDivider extends StatelessWidget {
  const _SectionDivider();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.black, width: 0.5)),
      ),
      child: SizedBox(height: 1),
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  const _SettingsToggleRow({
    required this.switchKey,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final Key switchKey;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsRowFrame(
      child: Row(
        children: <Widget>[
          Expanded(
            child: _SettingsRowText(title: title, subtitle: subtitle),
          ),
          const SizedBox(width: 10),
          _BlockSwitch(key: switchKey, value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _SettingsActionRow extends StatelessWidget {
  const _SettingsActionRow({
    required this.title,
    required this.subtitle,
    required this.onPressed,
    this.enabled = true,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final VoidCallback onPressed;
  final bool enabled;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: enabled ? onPressed : null,
      child: _SettingsRowFrame(
        child: Row(
          children: <Widget>[
            Expanded(
              child: _SettingsRowText(title: title, subtitle: subtitle),
            ),
            trailing ??
                const Icon(
                  LucideIcons.chevronRight,
                  color: AppColors.settingsMutedText,
                  size: 20,
                ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRowFrame extends StatelessWidget {
  const _SettingsRowFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.settingsRowDivider, width: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 15, 16, 20),
        child: child,
      ),
    );
  }
}

class _SettingsRowText extends StatelessWidget {
  const _SettingsRowText({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textScaler: TextScaler.noScaling,
          style: const TextStyle(
            color: AppColors.black,
            fontSize: 15.5,
            fontWeight: FontWeight.w400,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textScaler: TextScaler.noScaling,
          style: const TextStyle(
            color: AppColors.settingsMutedText,
            fontSize: 13,
            fontWeight: FontWeight.w400,
            height: 1.05,
          ),
        ),
      ],
    );
  }
}

class _BlockSwitch extends StatelessWidget {
  const _BlockSwitch({required this.value, required this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onChanged(!value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOutCubic,
          width: 40,
          height: 22,
          padding: const EdgeInsets.all(2),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: value
                ? AppColors.accentYellow
                : AppColors.settingsDisabledSwitch,
            border: Border.all(color: AppColors.black, width: 0.5),
          ),
          child: const SizedBox(
            width: 16,
            height: 16,
            child: DecoratedBox(
              decoration: BoxDecoration(color: AppColors.black),
            ),
          ),
        ),
      ),
    );
  }
}
