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
  String get authContinueWithApple => 'Continue with Apple';

  @override
  String get authCreateAccountButton => 'Create account';

  @override
  String get authCreateAccountSubtitle => 'Create your account';

  @override
  String get authEmailInvalid => 'Enter a valid email.';

  @override
  String get authEmailPlaceholder => 'Email';

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
  String get authPasswordMinLength => 'Use at least 6 characters.';

  @override
  String get authPasswordPlaceholder => 'Password';

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
  String get generationSubmissionRelatedMoments => 'THIS MOMENT';

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
  String get generationSubmissionActionRemove => 'Remove';

  @override
  String get promptSwitchRecomposeTitle => 'Recompose';

  @override
  String get promptSwitchBeautifyFaceTitle => 'Face refine';

  @override
  String get promptSwitchCleanFrameTitle => 'Clean frame';

  @override
  String get promptSwitchBackgroundBlurTitle => 'Background blur';

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
  String get settingsClearOriginalCacheTitle => 'Clear original cache';

  @override
  String get settingsClearOriginalCacheSubtitle =>
      'Remove local camera originals';

  @override
  String get settingsManageSubscriptionTitle => 'Manage subscription';

  @override
  String get settingsManageSubscriptionSubtitle => 'Plan and billing';

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
}
