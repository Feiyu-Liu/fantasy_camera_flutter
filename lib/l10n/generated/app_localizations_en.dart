// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Fantasy Camera';

  @override
  String get appName => 'Fantasy Camera';

  @override
  String get authAccountCreatedSignIn => 'Account created. Please sign in.';

  @override
  String get authAlreadyHaveAccountSignIn => 'Already have an account? Sign in';

  @override
  String get authAppleSignInFailed => 'Apple sign in failed.';

  @override
  String get authAuthenticationFailed =>
      'Authentication failed. Please try again.';

  @override
  String get authCameraDevicesLoadFailed =>
      'Camera devices could not be loaded.';

  @override
  String get authContinueWithApple => 'Sign in with Apple';

  @override
  String get authContinueWithGoogle => 'Sign in with Google';

  @override
  String get authCreateAccountButton => 'Create account';

  @override
  String get authCreateAccountSubtitle => 'Create your account';

  @override
  String get authEmailInvalid => 'Enter a valid email.';

  @override
  String get authEmailLabel => 'E-mail address';

  @override
  String get authEmailPlaceholder => 'Email';

  @override
  String get authEditorialAccessBadge => 'Editorial access';

  @override
  String get authEditorialSubtitle => 'Enter your credentials to continue';

  @override
  String get authEditorialTitleLine1 => 'The Lens';

  @override
  String get authEditorialTitleLine2 => 'Awaits';

  @override
  String get authForgotKeyButton => 'Forgot key?';

  @override
  String get authGoogleSignInFailed => 'Google sign in failed.';

  @override
  String get authEmailRequired => 'Email is required.';

  @override
  String get authInvalidCredentials =>
      'Email or password is incorrect. If this is a new account, create it first and confirm the email if required.';

  @override
  String get authMissingSupabaseConfig =>
      'Missing Supabase configuration. Start with SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY dart-defines.';

  @override
  String get authNewHereCreateAccount => 'New here? Create account';

  @override
  String get authOrDividerLabel => 'or';

  @override
  String get authPasswordMinLength => 'Use at least 6 characters.';

  @override
  String get authPasswordLabel => 'Secret key';

  @override
  String get authPasswordPlaceholder => 'Password';

  @override
  String get authSecretKeyPlaceholder => '••••••••';

  @override
  String get authSessionExpired => 'Session expired. Please sign in again.';

  @override
  String get authSessionRestoreFailed =>
      'Session could not be restored. Please sign in.';

  @override
  String get authSignInButton => 'Sign in';

  @override
  String get authSignInSubtitle => 'Sign in to continue';

  @override
  String cameraCreditsBalanceSemanticsLabel(Object value) {
    return '$value credits';
  }

  @override
  String get cameraNoCameraFound => 'No camera found.';

  @override
  String get cameraStartingCamera => 'Starting camera...';

  @override
  String cameraErrorMessage(Object message) {
    return 'Camera error: $message';
  }

  @override
  String get generationSubmissionDownloadingFromICloud =>
      'Downloading from iCloud';

  @override
  String get generationSubmissionPreparingPhoto => 'Preparing your photo...';

  @override
  String get generationSubmissionGalleryTitle => 'GALLERY';

  @override
  String get generationSubmissionImportNew => 'IMPORT FROM ALBUM';

  @override
  String get generationSubmissionDefaultMomentMode => 'MOMENT';

  @override
  String get generationSubmissionDefaultPromptBadge => 'DEFAULT';

  @override
  String get generationSubmissionSelectMoment => 'CAPTURE OR CHOOSE A PHOTO';

  @override
  String get generationSubmissionProcessedResultImageLoadFailed =>
      'Processed result image could not be loaded';

  @override
  String get generationSubmissionResultImageLoadFailed =>
      'Result image could not be loaded';

  @override
  String get generationSubmissionOriginalImageLoadFailed =>
      'Original image could not be loaded';

  @override
  String get generationSubmissionTapToLoadResult => 'TAP TO LOAD RESULT';

  @override
  String get generationSubmissionStatusGenerationFailed => 'Generation failed';

  @override
  String get generationSubmissionStatusWaitingForConfirmation =>
      'Waiting for confirmation';

  @override
  String get generationSubmissionStatusPreparingUploadImage =>
      'Preparing upload image';

  @override
  String get generationSubmissionStatusProcessingResultImage =>
      'Processing result image';

  @override
  String get generationSubmissionStatusResultSaved => 'Result saved';

  @override
  String get generationSubmissionStatusResultProcessingFailed =>
      'Result processing failed';

  @override
  String get generationSubmissionStatusWaitingForGenerationResult =>
      'Waiting for generation result';

  @override
  String get generationSubmissionStatusPreparingGenerationTask =>
      'Preparing generation task';

  @override
  String get generationSubmissionActionViewInAlbum => 'View in Album';

  @override
  String get generationSubmissionActionSaveOriginal => 'Save Original';

  @override
  String get generationSubmissionActionRetry => 'Retry';

  @override
  String get generationSubmissionActionDislikeImage => 'Dislike this image';

  @override
  String get generationSubmissionActionFeedbackSubmitted => 'Feedback sent';

  @override
  String get generationSubmissionDislikeFeedbackTitle => 'Not quite right?';

  @override
  String get generationSubmissionDislikeFeedbackPlaceholder =>
      'Leave your feedback (optional)';

  @override
  String get generationSubmissionDislikeFeedbackSubmit => 'Submit';

  @override
  String get generationSubmissionActionRemove => 'Remove';

  @override
  String get promptSwitchRecomposeTitle => 'Recompose';

  @override
  String get promptSwitchBeautifyFaceTitle => 'Portrait Enhance';

  @override
  String get promptSwitchCleanFrameTitle => 'Declutter';

  @override
  String get promptSwitchBackgroundBlurTitle => 'Background Blur';

  @override
  String get promptStyleRealisticTitle => 'Realistic';

  @override
  String get promptCaptureModePortraitTitle => 'Portrait';

  @override
  String get promptCaptureModeGeneralTitle => 'General';

  @override
  String get settingsTitle => 'SETTINGS';

  @override
  String get settingsFallbackUserName => 'Julian Vane';

  @override
  String settingsCreditsValue(int value) {
    return '$value CREDITS';
  }

  @override
  String get settingsCreditsLoading => '-- CREDITS';

  @override
  String get settingsCreditsUnavailable => 'CREDITS UNAVAILABLE';

  @override
  String get settingsSectionAppearance => 'APPEARANCE';

  @override
  String get settingsAppearanceLight => 'Light';

  @override
  String get settingsAppearanceDark => 'Dark';

  @override
  String get settingsSectionCapture => 'CAPTURE';

  @override
  String get settingsConfirmBeforeGenerationTitle =>
      'Confirm before generation';

  @override
  String get settingsConfirmBeforeGenerationSubtitle =>
      'Review a photo before upload';

  @override
  String get settingsSectionGeneral => 'GENERAL';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get settingsLanguageSubtitle => 'System default';

  @override
  String get settingsLanguageSystem => 'System default';

  @override
  String get settingsLanguageChinese => '简体中文';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsClearOriginalCacheTitle => 'Clear cached originals';

  @override
  String get settingsClearOriginalCacheSubtitle =>
      'Remove local camera originals';

  @override
  String get settingsClearOriginalCacheCalculating => 'Recalculating...';

  @override
  String get settingsClearOriginalCacheNoClearable =>
      'No cached originals to clear';

  @override
  String get settingsClearOriginalCacheConfirmTitle => 'Clear original cache?';

  @override
  String get settingsClearOriginalCacheConfirmMessage =>
      'This will delete camera original caches for every account that has signed in on this device. Generation records and generated images will not be deleted.';

  @override
  String get settingsClearOriginalCacheConfirmAction => 'Clear';

  @override
  String settingsClearOriginalCacheSize(Object size) {
    return '$size clearable';
  }

  @override
  String settingsClearOriginalCacheLastCalculatedSize(Object size) {
    return 'Last calculated: $size clearable';
  }

  @override
  String get settingsClearOriginalCacheInProgress => 'Clearing...';

  @override
  String get settingsClearOriginalCacheDoneTitle => 'Cache cleared';

  @override
  String settingsClearOriginalCacheDoneMessage(int count) {
    return 'Cleared $count camera originals.';
  }

  @override
  String settingsClearOriginalCachePartialMessage(
    int clearedCount,
    int failedCount,
  ) {
    return 'Cleared $clearedCount camera originals. $failedCount failed.';
  }

  @override
  String get settingsClearOriginalCacheFailedTitle => 'Clear failed';

  @override
  String get settingsClearOriginalCacheFailedMessage =>
      'Original cache could not be cleared. Try again later.';

  @override
  String get settingsManageSubscriptionTitle => 'Buy credits';

  @override
  String get settingsManageSubscriptionSubtitle => 'Credit packs and restore';

  @override
  String get settingsSectionInformation => 'INFORMATION';

  @override
  String get settingsPrivacyPolicyTitle => 'Privacy Policy';

  @override
  String get settingsPrivacyPolicySubtitle => 'Data and photo handling';

  @override
  String get settingsTermsTitle => 'Terms of Use';

  @override
  String get settingsTermsSubtitle => 'Service rules and rights';

  @override
  String get settingsAboutTitle => 'About';

  @override
  String get settingsAboutSubtitle => 'App version and credits';

  @override
  String get settingsContactDeveloperTitle => 'Contact developer';

  @override
  String get settingsContactDeveloperSubtitle =>
      'Send feedback or support request';

  @override
  String get settingsSectionAccount => 'ACCOUNT';

  @override
  String get settingsDeleteAccountTitle => 'Delete account';

  @override
  String get settingsDeleteAccountSubtitle => 'Permanently remove your account';

  @override
  String get settingsSignOutTitle => 'Sign out';

  @override
  String get settingsSignOutSubtitle => 'Return to the sign-in screen';

  @override
  String get settingsSignOutConfirmTitle => 'Sign out?';

  @override
  String get settingsSignOutConfirmMessage =>
      'Your local creations will stay on this device. You can sign in again anytime.';

  @override
  String get settingsSignOutConfirmAction => 'Sign out';

  @override
  String get settingsSignOutFailedTitle => 'Sign-out failed';

  @override
  String get settingsSignOutFailedMessage =>
      'Could not sign out. Try again later.';

  @override
  String get billingTitle => 'CREDITS';

  @override
  String get billingHeroTitle => 'Get Creation Credits';

  @override
  String get billingHeroSubtitle =>
      'Credits are used to generate images. Purchases are verified by the server before they update your balance.';

  @override
  String billingCreditPackTitle(int credits) {
    return '$credits credits';
  }

  @override
  String get billingCreditPackSubtitle => 'One-time credit pack';

  @override
  String get billingPurchaseButton => 'Purchase';

  @override
  String billingPurchaseSuccessButton(int credits) {
    return 'Purchase complete (+$credits credits)';
  }

  @override
  String get billingRestorePurchases => 'Restore purchases';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonOK => 'OK';

  @override
  String get billingProductsUnavailable =>
      'No credit packs are available right now.';

  @override
  String get billingRetry => 'Retry';

  @override
  String billingGrantedCreditsMessage(int credits) {
    return '+$credits credits';
  }

  @override
  String get billingLegalNote =>
      'Purchases are processed by the App Store. By continuing, you agree to the Terms of Use and Privacy Policy.';
}
