import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('zh'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Fantasy Camera'**
  String get appTitle;

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Fantasy Camera'**
  String get appName;

  /// No description provided for @authAccountCreatedSignIn.
  ///
  /// In en, this message translates to:
  /// **'Account created. Please sign in.'**
  String get authAccountCreatedSignIn;

  /// No description provided for @authAlreadyHaveAccountSignIn.
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get authAlreadyHaveAccountSignIn;

  /// No description provided for @authAppleSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Apple sign in failed.'**
  String get authAppleSignInFailed;

  /// No description provided for @authAuthenticationFailed.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Please try again.'**
  String get authAuthenticationFailed;

  /// No description provided for @authCameraDevicesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Camera devices could not be loaded.'**
  String get authCameraDevicesLoadFailed;

  /// No description provided for @authContinueWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get authContinueWithApple;

  /// No description provided for @authCreateAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreateAccountButton;

  /// No description provided for @authCreateAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get authCreateAccountSubtitle;

  /// No description provided for @authEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email.'**
  String get authEmailInvalid;

  /// No description provided for @authEmailPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmailPlaceholder;

  /// No description provided for @authEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required.'**
  String get authEmailRequired;

  /// No description provided for @authInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Email or password is incorrect. If this is a new account, create it first and confirm the email if required.'**
  String get authInvalidCredentials;

  /// No description provided for @authMissingSupabaseConfig.
  ///
  /// In en, this message translates to:
  /// **'Missing Supabase configuration. Start with SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY dart-defines.'**
  String get authMissingSupabaseConfig;

  /// No description provided for @authNewHereCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'New here? Create account'**
  String get authNewHereCreateAccount;

  /// No description provided for @authPasswordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Use at least 6 characters.'**
  String get authPasswordMinLength;

  /// No description provided for @authPasswordPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordPlaceholder;

  /// No description provided for @authSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session expired. Please sign in again.'**
  String get authSessionExpired;

  /// No description provided for @authSessionRestoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Session could not be restored. Please sign in.'**
  String get authSessionRestoreFailed;

  /// No description provided for @authSignInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignInButton;

  /// No description provided for @authSignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get authSignInSubtitle;

  /// No description provided for @cameraCreditsBalanceSemanticsLabel.
  ///
  /// In en, this message translates to:
  /// **'{value} credits'**
  String cameraCreditsBalanceSemanticsLabel(Object value);

  /// No description provided for @cameraNoCameraFound.
  ///
  /// In en, this message translates to:
  /// **'No camera found.'**
  String get cameraNoCameraFound;

  /// No description provided for @cameraStartingCamera.
  ///
  /// In en, this message translates to:
  /// **'Starting camera...'**
  String get cameraStartingCamera;

  /// No description provided for @cameraErrorMessage.
  ///
  /// In en, this message translates to:
  /// **'Camera error: {message}'**
  String cameraErrorMessage(Object message);

  /// No description provided for @generationSubmissionDownloadingFromICloud.
  ///
  /// In en, this message translates to:
  /// **'Downloading from iCloud'**
  String get generationSubmissionDownloadingFromICloud;

  /// No description provided for @generationSubmissionPreparingPhoto.
  ///
  /// In en, this message translates to:
  /// **'Preparing your photo...'**
  String get generationSubmissionPreparingPhoto;

  /// No description provided for @generationSubmissionRelatedMoments.
  ///
  /// In en, this message translates to:
  /// **'RELATED MOMENTS'**
  String get generationSubmissionRelatedMoments;

  /// No description provided for @generationSubmissionImportNew.
  ///
  /// In en, this message translates to:
  /// **'IMPORT FROM ALBUM'**
  String get generationSubmissionImportNew;

  /// No description provided for @generationSubmissionDefaultMomentMode.
  ///
  /// In en, this message translates to:
  /// **'MOMENT'**
  String get generationSubmissionDefaultMomentMode;

  /// No description provided for @generationSubmissionDefaultPromptBadge.
  ///
  /// In en, this message translates to:
  /// **'DEFAULT'**
  String get generationSubmissionDefaultPromptBadge;

  /// No description provided for @generationSubmissionSelectMoment.
  ///
  /// In en, this message translates to:
  /// **'SELECT A MOMENT'**
  String get generationSubmissionSelectMoment;

  /// No description provided for @generationSubmissionProcessedResultImageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Processed result image could not be loaded'**
  String get generationSubmissionProcessedResultImageLoadFailed;

  /// No description provided for @generationSubmissionResultImageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Result image could not be loaded'**
  String get generationSubmissionResultImageLoadFailed;

  /// No description provided for @generationSubmissionOriginalImageLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Original image could not be loaded'**
  String get generationSubmissionOriginalImageLoadFailed;

  /// No description provided for @generationSubmissionTapToLoadResult.
  ///
  /// In en, this message translates to:
  /// **'TAP TO LOAD RESULT'**
  String get generationSubmissionTapToLoadResult;

  /// No description provided for @generationSubmissionStatusGenerationFailed.
  ///
  /// In en, this message translates to:
  /// **'Generation failed'**
  String get generationSubmissionStatusGenerationFailed;

  /// No description provided for @generationSubmissionStatusWaitingForConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Waiting for confirmation'**
  String get generationSubmissionStatusWaitingForConfirmation;

  /// No description provided for @generationSubmissionStatusPreparingUploadImage.
  ///
  /// In en, this message translates to:
  /// **'Preparing upload image'**
  String get generationSubmissionStatusPreparingUploadImage;

  /// No description provided for @generationSubmissionStatusProcessingResultImage.
  ///
  /// In en, this message translates to:
  /// **'Processing result image'**
  String get generationSubmissionStatusProcessingResultImage;

  /// No description provided for @generationSubmissionStatusResultSaved.
  ///
  /// In en, this message translates to:
  /// **'Result saved'**
  String get generationSubmissionStatusResultSaved;

  /// No description provided for @generationSubmissionStatusResultProcessingFailed.
  ///
  /// In en, this message translates to:
  /// **'Result processing failed'**
  String get generationSubmissionStatusResultProcessingFailed;

  /// No description provided for @generationSubmissionStatusWaitingForGenerationResult.
  ///
  /// In en, this message translates to:
  /// **'Waiting for generation result'**
  String get generationSubmissionStatusWaitingForGenerationResult;

  /// No description provided for @generationSubmissionStatusPreparingGenerationTask.
  ///
  /// In en, this message translates to:
  /// **'Preparing generation task'**
  String get generationSubmissionStatusPreparingGenerationTask;

  /// No description provided for @generationSubmissionActionViewInAlbum.
  ///
  /// In en, this message translates to:
  /// **'View in Album'**
  String get generationSubmissionActionViewInAlbum;

  /// No description provided for @generationSubmissionActionSaveOriginal.
  ///
  /// In en, this message translates to:
  /// **'Save Original'**
  String get generationSubmissionActionSaveOriginal;

  /// No description provided for @generationSubmissionActionRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get generationSubmissionActionRetry;

  /// No description provided for @generationSubmissionActionDislikeImage.
  ///
  /// In en, this message translates to:
  /// **'Dislike this image'**
  String get generationSubmissionActionDislikeImage;

  /// No description provided for @generationSubmissionActionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get generationSubmissionActionRemove;

  /// No description provided for @promptSwitchRecomposeTitle.
  ///
  /// In en, this message translates to:
  /// **'Recompose'**
  String get promptSwitchRecomposeTitle;

  /// No description provided for @promptSwitchBeautifyFaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Face refine'**
  String get promptSwitchBeautifyFaceTitle;

  /// No description provided for @promptSwitchCleanFrameTitle.
  ///
  /// In en, this message translates to:
  /// **'Clean frame'**
  String get promptSwitchCleanFrameTitle;

  /// No description provided for @promptSwitchBackgroundBlurTitle.
  ///
  /// In en, this message translates to:
  /// **'Background blur'**
  String get promptSwitchBackgroundBlurTitle;

  /// No description provided for @promptStyleRealisticTitle.
  ///
  /// In en, this message translates to:
  /// **'Realistic'**
  String get promptStyleRealisticTitle;

  /// No description provided for @promptCaptureModePortraitTitle.
  ///
  /// In en, this message translates to:
  /// **'Portrait'**
  String get promptCaptureModePortraitTitle;

  /// No description provided for @promptCaptureModeGeneralTitle.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get promptCaptureModeGeneralTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'SETTINGS'**
  String get settingsTitle;

  /// No description provided for @settingsFallbackUserName.
  ///
  /// In en, this message translates to:
  /// **'Julian Vane'**
  String get settingsFallbackUserName;

  /// No description provided for @settingsCreditsValue.
  ///
  /// In en, this message translates to:
  /// **'{value} CREDITS'**
  String settingsCreditsValue(int value);

  /// No description provided for @settingsCreditsLoading.
  ///
  /// In en, this message translates to:
  /// **'-- CREDITS'**
  String get settingsCreditsLoading;

  /// No description provided for @settingsCreditsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'CREDITS UNAVAILABLE'**
  String get settingsCreditsUnavailable;

  /// No description provided for @settingsSectionAppearance.
  ///
  /// In en, this message translates to:
  /// **'APPEARANCE'**
  String get settingsSectionAppearance;

  /// No description provided for @settingsAppearanceLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsAppearanceLight;

  /// No description provided for @settingsAppearanceDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsAppearanceDark;

  /// No description provided for @settingsSectionCapture.
  ///
  /// In en, this message translates to:
  /// **'CAPTURE'**
  String get settingsSectionCapture;

  /// No description provided for @settingsConfirmBeforeGenerationTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm before generation'**
  String get settingsConfirmBeforeGenerationTitle;

  /// No description provided for @settingsConfirmBeforeGenerationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review a photo before upload'**
  String get settingsConfirmBeforeGenerationSubtitle;

  /// No description provided for @settingsSectionGeneral.
  ///
  /// In en, this message translates to:
  /// **'GENERAL'**
  String get settingsSectionGeneral;

  /// No description provided for @settingsLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageTitle;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSubtitle;

  /// No description provided for @settingsClearOriginalCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear original cache'**
  String get settingsClearOriginalCacheTitle;

  /// No description provided for @settingsClearOriginalCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remove local camera originals'**
  String get settingsClearOriginalCacheSubtitle;

  /// No description provided for @settingsManageSubscriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage subscription'**
  String get settingsManageSubscriptionTitle;

  /// No description provided for @settingsManageSubscriptionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Plan and billing'**
  String get settingsManageSubscriptionSubtitle;

  /// No description provided for @settingsSectionInformation.
  ///
  /// In en, this message translates to:
  /// **'INFORMATION'**
  String get settingsSectionInformation;

  /// No description provided for @settingsPrivacyPolicyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get settingsPrivacyPolicyTitle;

  /// No description provided for @settingsPrivacyPolicySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Data and photo handling'**
  String get settingsPrivacyPolicySubtitle;

  /// No description provided for @settingsTermsTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get settingsTermsTitle;

  /// No description provided for @settingsTermsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Service rules and rights'**
  String get settingsTermsSubtitle;

  /// No description provided for @settingsAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAboutTitle;

  /// No description provided for @settingsAboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'App version and credits'**
  String get settingsAboutSubtitle;

  /// No description provided for @settingsContactDeveloperTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact developer'**
  String get settingsContactDeveloperTitle;

  /// No description provided for @settingsContactDeveloperSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Send feedback or support request'**
  String get settingsContactDeveloperSubtitle;

  /// No description provided for @settingsSectionAccount.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get settingsSectionAccount;

  /// No description provided for @settingsDeleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccountTitle;

  /// No description provided for @settingsDeleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently remove your account'**
  String get settingsDeleteAccountSubtitle;

  /// No description provided for @settingsSignOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOutTitle;

  /// No description provided for @settingsSignOutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Return to the sign-in screen'**
  String get settingsSignOutSubtitle;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
