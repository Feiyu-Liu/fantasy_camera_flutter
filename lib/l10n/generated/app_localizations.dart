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
  /// **'Sign in with Apple'**
  String get authContinueWithApple;

  /// No description provided for @authContinueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get authContinueWithGoogle;

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

  /// No description provided for @authEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'E-mail address'**
  String get authEmailLabel;

  /// No description provided for @authEmailPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmailPlaceholder;

  /// No description provided for @authEditorialAccessBadge.
  ///
  /// In en, this message translates to:
  /// **'Editorial access'**
  String get authEditorialAccessBadge;

  /// No description provided for @authEditorialSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your credentials to continue'**
  String get authEditorialSubtitle;

  /// No description provided for @authEditorialTitleLine1.
  ///
  /// In en, this message translates to:
  /// **'The Lens'**
  String get authEditorialTitleLine1;

  /// No description provided for @authEditorialTitleLine2.
  ///
  /// In en, this message translates to:
  /// **'Awaits'**
  String get authEditorialTitleLine2;

  /// No description provided for @authForgotKeyButton.
  ///
  /// In en, this message translates to:
  /// **'Forgot key?'**
  String get authForgotKeyButton;

  /// No description provided for @authGoogleSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Google sign in failed.'**
  String get authGoogleSignInFailed;

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

  /// No description provided for @authOrDividerLabel.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get authOrDividerLabel;

  /// No description provided for @authPasswordMinLength.
  ///
  /// In en, this message translates to:
  /// **'Use at least 6 characters.'**
  String get authPasswordMinLength;

  /// No description provided for @authPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Secret key'**
  String get authPasswordLabel;

  /// No description provided for @authPasswordPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordPlaceholder;

  /// No description provided for @authSecretKeyPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'••••••••'**
  String get authSecretKeyPlaceholder;

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

  /// No description provided for @generationSubmissionGalleryTitle.
  ///
  /// In en, this message translates to:
  /// **'GALLERY'**
  String get generationSubmissionGalleryTitle;

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
  /// **'CAPTURE OR CHOOSE A PHOTO'**
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

  /// No description provided for @generationSubmissionActionFeedbackSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Feedback sent'**
  String get generationSubmissionActionFeedbackSubmitted;

  /// No description provided for @generationSubmissionDislikeFeedbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Not quite right?'**
  String get generationSubmissionDislikeFeedbackTitle;

  /// No description provided for @generationSubmissionDislikeFeedbackPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Leave your feedback (optional)'**
  String get generationSubmissionDislikeFeedbackPlaceholder;

  /// No description provided for @generationSubmissionDislikeFeedbackSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get generationSubmissionDislikeFeedbackSubmit;

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
  /// **'Portrait Enhance'**
  String get promptSwitchBeautifyFaceTitle;

  /// No description provided for @promptSwitchCleanFrameTitle.
  ///
  /// In en, this message translates to:
  /// **'Declutter'**
  String get promptSwitchCleanFrameTitle;

  /// No description provided for @promptSwitchBackgroundBlurTitle.
  ///
  /// In en, this message translates to:
  /// **'Background Blur'**
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

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageChinese.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get settingsLanguageChinese;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsClearOriginalCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear cached originals'**
  String get settingsClearOriginalCacheTitle;

  /// No description provided for @settingsClearOriginalCacheSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Remove local camera originals'**
  String get settingsClearOriginalCacheSubtitle;

  /// No description provided for @settingsClearOriginalCacheCalculating.
  ///
  /// In en, this message translates to:
  /// **'Recalculating...'**
  String get settingsClearOriginalCacheCalculating;

  /// No description provided for @settingsClearOriginalCacheNoClearable.
  ///
  /// In en, this message translates to:
  /// **'No cached originals to clear'**
  String get settingsClearOriginalCacheNoClearable;

  /// No description provided for @settingsClearOriginalCacheConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear original cache?'**
  String get settingsClearOriginalCacheConfirmTitle;

  /// No description provided for @settingsClearOriginalCacheConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will delete camera original caches for every account that has signed in on this device. Generation records and generated images will not be deleted.'**
  String get settingsClearOriginalCacheConfirmMessage;

  /// No description provided for @settingsClearOriginalCacheConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get settingsClearOriginalCacheConfirmAction;

  /// No description provided for @settingsClearOriginalCacheSize.
  ///
  /// In en, this message translates to:
  /// **'{size} clearable'**
  String settingsClearOriginalCacheSize(Object size);

  /// No description provided for @settingsClearOriginalCacheLastCalculatedSize.
  ///
  /// In en, this message translates to:
  /// **'Last calculated: {size} clearable'**
  String settingsClearOriginalCacheLastCalculatedSize(Object size);

  /// No description provided for @settingsClearOriginalCacheInProgress.
  ///
  /// In en, this message translates to:
  /// **'Clearing...'**
  String get settingsClearOriginalCacheInProgress;

  /// No description provided for @settingsClearOriginalCacheDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared'**
  String get settingsClearOriginalCacheDoneTitle;

  /// No description provided for @settingsClearOriginalCacheDoneMessage.
  ///
  /// In en, this message translates to:
  /// **'Cleared {count} camera originals.'**
  String settingsClearOriginalCacheDoneMessage(int count);

  /// No description provided for @settingsClearOriginalCachePartialMessage.
  ///
  /// In en, this message translates to:
  /// **'Cleared {clearedCount} camera originals. {failedCount} failed.'**
  String settingsClearOriginalCachePartialMessage(
    int clearedCount,
    int failedCount,
  );

  /// No description provided for @settingsClearOriginalCacheFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear failed'**
  String get settingsClearOriginalCacheFailedTitle;

  /// No description provided for @settingsClearOriginalCacheFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Original cache could not be cleared. Try again later.'**
  String get settingsClearOriginalCacheFailedMessage;

  /// No description provided for @settingsManageSubscriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Buy credits'**
  String get settingsManageSubscriptionTitle;

  /// No description provided for @settingsManageSubscriptionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Credit packs and restore'**
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

  /// No description provided for @settingsSignOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign out?'**
  String get settingsSignOutConfirmTitle;

  /// No description provided for @settingsSignOutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Your local creations will stay on this device. You can sign in again anytime.'**
  String get settingsSignOutConfirmMessage;

  /// No description provided for @settingsSignOutConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get settingsSignOutConfirmAction;

  /// No description provided for @settingsSignOutFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign-out failed'**
  String get settingsSignOutFailedTitle;

  /// No description provided for @settingsSignOutFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Could not sign out. Try again later.'**
  String get settingsSignOutFailedMessage;

  /// No description provided for @billingTitle.
  ///
  /// In en, this message translates to:
  /// **'CREDITS'**
  String get billingTitle;

  /// No description provided for @billingHeroTitle.
  ///
  /// In en, this message translates to:
  /// **'Get Creation Credits'**
  String get billingHeroTitle;

  /// No description provided for @billingHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Credits are used to generate images. Purchases are verified by the server before they update your balance.'**
  String get billingHeroSubtitle;

  /// No description provided for @billingCreditPackTitle.
  ///
  /// In en, this message translates to:
  /// **'{credits} credits'**
  String billingCreditPackTitle(int credits);

  /// No description provided for @billingCreditPackSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One-time credit pack'**
  String get billingCreditPackSubtitle;

  /// No description provided for @billingPurchaseButton.
  ///
  /// In en, this message translates to:
  /// **'Purchase'**
  String get billingPurchaseButton;

  /// No description provided for @billingPurchaseSuccessButton.
  ///
  /// In en, this message translates to:
  /// **'Purchase complete (+{credits} credits)'**
  String billingPurchaseSuccessButton(int credits);

  /// No description provided for @billingRestorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get billingRestorePurchases;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonOK.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get commonOK;

  /// No description provided for @billingProductsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'No credit packs are available right now.'**
  String get billingProductsUnavailable;

  /// No description provided for @billingRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get billingRetry;

  /// No description provided for @billingGrantedCreditsMessage.
  ///
  /// In en, this message translates to:
  /// **'+{credits} credits'**
  String billingGrantedCreditsMessage(int credits);

  /// No description provided for @billingLegalNote.
  ///
  /// In en, this message translates to:
  /// **'Purchases are processed by the App Store. By continuing, you agree to the Terms of Use and Privacy Policy.'**
  String get billingLegalNote;

  /// No description provided for @toastGenerationNetworkFailed.
  ///
  /// In en, this message translates to:
  /// **'The network is unstable, so the photo was not uploaded. Try again later.'**
  String get toastGenerationNetworkFailed;

  /// No description provided for @toastOriginalUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The original photo could not be read. Take or choose another photo.'**
  String get toastOriginalUnavailable;

  /// No description provided for @toastInsufficientCredits.
  ///
  /// In en, this message translates to:
  /// **'You do not have enough creation credits.'**
  String get toastInsufficientCredits;

  /// No description provided for @toastGenerationSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'The generation request failed. Please try again.'**
  String get toastGenerationSubmitFailed;

  /// No description provided for @toastGenerationUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Photo upload failed. Check your network and try again.'**
  String get toastGenerationUploadFailed;

  /// No description provided for @toastGenerationTaskCreateFailed.
  ///
  /// In en, this message translates to:
  /// **'The photo was uploaded, but the generation request could not be created. Please try again.'**
  String get toastGenerationTaskCreateFailed;

  /// No description provided for @toastGenerationBackendFailed.
  ///
  /// In en, this message translates to:
  /// **'Photo generation failed. Please try again.'**
  String get toastGenerationBackendFailed;

  /// No description provided for @toastResultSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The result image could not be saved. Please try again.'**
  String get toastResultSaveFailed;

  /// No description provided for @toastGalleryICloudImportFailed.
  ///
  /// In en, this message translates to:
  /// **'This photo could not be downloaded from iCloud. Try again later.'**
  String get toastGalleryICloudImportFailed;

  /// No description provided for @toastGalleryImportFailed.
  ///
  /// In en, this message translates to:
  /// **'This photo could not be imported. Try another one.'**
  String get toastGalleryImportFailed;

  /// No description provided for @toastFavoriteFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update system favorites. Try again later.'**
  String get toastFavoriteFailed;

  /// No description provided for @toastOriginalSaved.
  ///
  /// In en, this message translates to:
  /// **'Original photo saved to Photos.'**
  String get toastOriginalSaved;

  /// No description provided for @toastOriginalSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Original photo could not be saved. Check Photos permission and try again.'**
  String get toastOriginalSaveFailed;

  /// No description provided for @toastFeedbackSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Feedback sent.'**
  String get toastFeedbackSubmitted;

  /// No description provided for @toastFeedbackFailed.
  ///
  /// In en, this message translates to:
  /// **'Feedback could not be sent. Try again later.'**
  String get toastFeedbackFailed;

  /// No description provided for @toastOpenPhotoLibraryFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open Photos.'**
  String get toastOpenPhotoLibraryFailed;

  /// No description provided for @settingsClearOriginalCachePartialTitle.
  ///
  /// In en, this message translates to:
  /// **'Partially cleared'**
  String get settingsClearOriginalCachePartialTitle;

  /// No description provided for @toastPurchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Purchase was not completed. Try again later.'**
  String get toastPurchaseFailed;

  /// No description provided for @toastRestorePurchaseFailed.
  ///
  /// In en, this message translates to:
  /// **'Purchases could not be restored. Try again later.'**
  String get toastRestorePurchaseFailed;
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
