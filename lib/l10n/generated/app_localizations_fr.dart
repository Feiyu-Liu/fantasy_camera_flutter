// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Fantasy Camera';

  @override
  String get appName => 'Fantasy Camera';

  @override
  String get authAccountCreatedSignIn =>
      'Compte créé. Connecte-toi pour continuer.';

  @override
  String get authAlreadyHaveAccountSignIn => 'Déjà un compte ? Connexion';

  @override
  String get authAppleSignInFailed => 'La connexion avec Apple a échoué.';

  @override
  String get authAuthenticationFailed => 'Authentification échouée. Réessaie.';

  @override
  String get authCameraDevicesLoadFailed =>
      'Impossible de charger les appareils photo.';

  @override
  String get authContinueWithApple => 'Continuer avec Apple';

  @override
  String get authContinueWithGoogle => 'Continuer avec Google';

  @override
  String get authCreateAccountButton => 'Créer un compte';

  @override
  String get authCreateAccountSubtitle => 'Crée ton compte';

  @override
  String get authEmailInvalid => 'Saisis une adresse courriel valide.';

  @override
  String get authEmailLabel => 'Adresse courriel';

  @override
  String get authEmailPlaceholder => 'Courriel';

  @override
  String get authEditorialAccessBadge => 'Accès éditorial';

  @override
  String get authEditorialSubtitle => 'Saisis tes informations pour continuer';

  @override
  String get authEditorialTitleLine1 => 'L\'objectif';

  @override
  String get authEditorialTitleLine2 => 'T\'attend';

  @override
  String get authForgotKeyButton => 'Clé oubliée ?';

  @override
  String get authGoogleSignInFailed => 'La connexion avec Google a échoué.';

  @override
  String get authEmailRequired => 'Le courriel est requis.';

  @override
  String get authInvalidCredentials =>
      'Courriel ou mot de passe incorrect. S\'il s\'agit d\'un nouveau compte, crée-le d\'abord et confirme le courriel si nécessaire.';

  @override
  String get authMissingSupabaseConfig =>
      'Configuration Supabase manquante. Configure SUPABASE_URL et SUPABASE_PUBLISHABLE_KEY via les dart-defines.';

  @override
  String get authNewHereCreateAccount => 'Nouveau ici ? Créer un compte';

  @override
  String get authOrDividerLabel => 'ou';

  @override
  String get authPasswordMinLength => 'Utilise au moins 6 caractères.';

  @override
  String get authPasswordLabel => 'Clé secrète';

  @override
  String get authPasswordPlaceholder => 'Mot de passe';

  @override
  String get authSecretKeyPlaceholder => '••••••••';

  @override
  String get authSessionExpired => 'Session expirée. Reconnecte-toi.';

  @override
  String get authSessionRestoreFailed =>
      'Impossible de restaurer la session. Reconnecte-toi.';

  @override
  String get authSignInButton => 'Se connecter';

  @override
  String get authSignInSubtitle => 'Connecte-toi pour continuer';

  @override
  String cameraCreditsBalanceSemanticsLabel(Object value) {
    return '$value crédits';
  }

  @override
  String get cameraNoCameraFound => 'Aucun appareil photo trouvé.';

  @override
  String get cameraStartingCamera => 'Démarrage de l\'appareil photo...';

  @override
  String cameraErrorMessage(Object message) {
    return 'Erreur caméra : $message';
  }

  @override
  String get generationSubmissionDownloadingFromICloud =>
      'Téléchargement depuis iCloud';

  @override
  String get generationSubmissionPreparingPhoto => 'Préparation de la photo...';

  @override
  String get generationSubmissionGalleryTitle => 'GALERIE';

  @override
  String get generationSubmissionImportNew => 'IMPORTER DEPUIS PHOTOS';

  @override
  String get generationSubmissionDefaultMomentMode => 'MOMENT';

  @override
  String get generationSubmissionDefaultPromptBadge => 'DÉFAUT';

  @override
  String get generationSubmissionSelectMoment => 'PRENDRE OU CHOISIR UNE PHOTO';

  @override
  String get generationSubmissionProcessedResultImageLoadFailed =>
      'Impossible de charger l\'image résultat traitée';

  @override
  String get generationSubmissionResultImageLoadFailed =>
      'Impossible de charger l\'image résultat';

  @override
  String get generationSubmissionOriginalImageLoadFailed =>
      'Impossible de charger l\'image originale';

  @override
  String get generationSubmissionTapToLoadResult =>
      'TOUCHER POUR CHARGER LE RÉSULTAT';

  @override
  String get generationSubmissionStatusGenerationFailed => 'Génération échouée';

  @override
  String get generationSubmissionStatusWaitingForConfirmation =>
      'En attente de confirmation';

  @override
  String get generationSubmissionStatusPreparingUploadImage =>
      'Préparation de l\'image à envoyer';

  @override
  String get generationSubmissionStatusProcessingResultImage =>
      'Traitement de l\'image résultat';

  @override
  String get generationSubmissionStatusResultSaved => 'Résultat enregistré';

  @override
  String get generationSubmissionStatusResultProcessingFailed =>
      'Traitement du résultat échoué';

  @override
  String get generationSubmissionStatusWaitingForGenerationResult =>
      'En attente du résultat';

  @override
  String get generationSubmissionStatusPreparingGenerationTask =>
      'Préparation de la tâche';

  @override
  String get generationSubmissionActionViewInAlbum => 'Voir dans l\'album';

  @override
  String get generationSubmissionActionSaveOriginal =>
      'Enregistrer l\'original';

  @override
  String get generationSubmissionActionRetry => 'Réessayer';

  @override
  String get generationSubmissionActionDislikeImage =>
      'Je n\'aime pas cette image';

  @override
  String get generationSubmissionActionFeedbackSubmitted =>
      'Commentaire envoyé';

  @override
  String get generationSubmissionDislikeFeedbackTitle => 'Pas tout à fait ?';

  @override
  String get generationSubmissionDislikeFeedbackPlaceholder =>
      'Laisse un commentaire (facultatif)';

  @override
  String get generationSubmissionDislikeFeedbackSubmit => 'Envoyer';

  @override
  String get generationSubmissionActionRemove => 'Supprimer';

  @override
  String get promptSwitchRecomposeTitle => 'Recadrer';

  @override
  String get promptSwitchBeautifyFaceTitle => 'Beauté';

  @override
  String get promptSwitchCleanFrameTitle => 'Épurer';

  @override
  String get promptSwitchBackgroundBlurTitle => 'Flou d\'arrière-plan';

  @override
  String get promptStyleRealisticTitle => 'Réaliste';

  @override
  String get promptCaptureModeManualTitle => 'MANUEL';

  @override
  String get promptCaptureModeAutoTitle => 'AUTO';

  @override
  String get settingsTitle => 'RÉGLAGES';

  @override
  String get settingsFallbackUserName => 'Julian Vane';

  @override
  String settingsCreditsValue(int value) {
    return '$value CRÉDITS';
  }

  @override
  String get settingsCreditsLoading => '-- CRÉDITS';

  @override
  String get settingsCreditsUnavailable => 'CRÉDITS INDISPONIBLES';

  @override
  String get settingsSectionAppearance => 'APPARENCE';

  @override
  String get settingsAppearanceLight => 'Clair';

  @override
  String get settingsAppearanceDark => 'Sombre';

  @override
  String get settingsSectionCapture => 'CAPTURE';

  @override
  String get settingsConfirmBeforeGenerationTitle =>
      'Confirmer avant génération';

  @override
  String get settingsConfirmBeforeGenerationSubtitle =>
      'Vérifier la photo avant envoi';

  @override
  String get settingsSectionGeneral => 'GÉNÉRAL';

  @override
  String get settingsLanguageTitle => 'Langue';

  @override
  String get settingsLanguageSubtitle => 'Langue du système';

  @override
  String get settingsLanguageSystem => 'Langue du système';

  @override
  String get settingsLanguageChinese => '简体中文';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageJapanese => '日本語';

  @override
  String get settingsLanguageTraditionalChinese => '繁體中文';

  @override
  String get settingsLanguageFrench => 'Français';

  @override
  String get settingsClearOriginalCacheTitle => 'Vider le cache des originaux';

  @override
  String get settingsClearOriginalCacheSubtitle =>
      'Supprimer les originaux locaux';

  @override
  String get settingsClearOriginalCacheCalculating => 'Recalcul en cours...';

  @override
  String get settingsClearOriginalCacheNoClearable => 'Aucun original en cache';

  @override
  String get settingsClearOriginalCacheConfirmTitle =>
      'Vider le cache des originaux ?';

  @override
  String get settingsClearOriginalCacheConfirmMessage =>
      'Les originaux caméra de tous les comptes connectés sur cet appareil seront supprimés. Les historiques et images générées ne seront pas affectés.';

  @override
  String get settingsClearOriginalCacheConfirmAction => 'Vider';

  @override
  String settingsClearOriginalCacheSize(Object size) {
    return '$size à libérer';
  }

  @override
  String settingsClearOriginalCacheLastCalculatedSize(Object size) {
    return 'Dernier calcul : $size à libérer';
  }

  @override
  String get settingsClearOriginalCacheInProgress => 'Vidage en cours...';

  @override
  String get settingsClearOriginalCacheDoneTitle => 'Cache vidé';

  @override
  String settingsClearOriginalCacheDoneMessage(int count) {
    return '$count originaux supprimés.';
  }

  @override
  String settingsClearOriginalCachePartialMessage(
    int clearedCount,
    int failedCount,
  ) {
    return '$clearedCount originaux supprimés. $failedCount ont échoué.';
  }

  @override
  String get settingsClearOriginalCacheFailedTitle => 'Échec du vidage';

  @override
  String get settingsClearOriginalCacheFailedMessage =>
      'Impossible de vider le cache. Réessaie plus tard.';

  @override
  String get settingsRedeemCodeTitle => 'Utiliser un code';

  @override
  String get settingsRedeemCodeSubtitle => 'Obtenir des crédits avec un code';

  @override
  String get settingsManageSubscriptionTitle => 'Acheter des crédits';

  @override
  String get settingsManageSubscriptionSubtitle =>
      'Packs de crédits et restauration';

  @override
  String get settingsSectionInformation => 'INFORMATIONS';

  @override
  String get settingsPrivacyPolicyTitle => 'Politique de confidentialité';

  @override
  String get settingsPrivacyPolicySubtitle => 'Gestion des données et photos';

  @override
  String get settingsTermsTitle => 'Conditions d\'utilisation';

  @override
  String get settingsTermsSubtitle => 'Règles et droits du service';

  @override
  String get settingsAboutTitle => 'À propos';

  @override
  String get settingsAboutSubtitle => 'Infos de version et remerciements';

  @override
  String get settingsContactDeveloperTitle => 'Contacter le développeur';

  @override
  String get settingsContactDeveloperSubtitle =>
      'Envoyer un commentaire ou une demande d\'aide';

  @override
  String get settingsSectionAccount => 'COMPTE';

  @override
  String get settingsDeleteAccountTitle => 'Supprimer le compte';

  @override
  String get settingsDeleteAccountSubtitle =>
      'Supprimer définitivement ton compte';

  @override
  String get settingsSignOutTitle => 'Se déconnecter';

  @override
  String get settingsSignOutSubtitle => 'Retour à l\'écran de connexion';

  @override
  String get settingsSignOutConfirmTitle => 'Se déconnecter ?';

  @override
  String get settingsSignOutConfirmMessage =>
      'Tes créations locales resteront sur cet appareil. Tu peux te reconnecter à tout moment.';

  @override
  String get settingsSignOutConfirmAction => 'Déconnecter';

  @override
  String get settingsSignOutFailedTitle => 'Déconnexion échouée';

  @override
  String get settingsSignOutFailedMessage =>
      'Impossible de se déconnecter. Réessaie plus tard.';

  @override
  String get billingTitle => 'CRÉDITS';

  @override
  String get billingHeroTitle => 'Obtenir des crédits';

  @override
  String get billingHeroSubtitle => 'Les crédits servent à générer des images';

  @override
  String billingCreditPackTitle(int credits) {
    return '$credits crédits';
  }

  @override
  String get billingCreditPackSubtitle => 'Pack de crédits à usage unique';

  @override
  String get billingPurchaseButton => 'Acheter';

  @override
  String billingPurchaseSuccessButton(int credits) {
    return 'Achat réussi (+$credits crédits)';
  }

  @override
  String get billingRestorePurchases => 'Restaurer les achats';

  @override
  String get billingRedeemCodeTitle => 'Utiliser un code';

  @override
  String get billingRedeemCodePlaceholder => 'Saisir le code';

  @override
  String get billingRedeemCodeButton => 'Utiliser';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonOK => 'OK';

  @override
  String get billingProductsUnavailable =>
      'Aucun pack de crédits disponible pour l\'instant.';

  @override
  String get billingRetry => 'Réessayer';

  @override
  String billingGrantedCreditsMessage(int credits) {
    return '+$credits crédits';
  }

  @override
  String get billingLegalNote =>
      'Les achats sont traités par l\'App Store. En continuant, tu acceptes les conditions d\'utilisation et la politique de confidentialité.';

  @override
  String get toastGenerationNetworkFailed =>
      'Le réseau est instable. Réessaie plus tard.';

  @override
  String get toastOriginalUnavailable =>
      'La photo originale est introuvable ou illisible. Vérifie l\'autorisation Photos puis réessaie.';

  @override
  String get toastInsufficientCredits => 'Crédits insuffisants.';

  @override
  String get toastGenerationSubmitFailed =>
      'La demande photo a échoué. Réessaie.';

  @override
  String get toastGenerationUploadFailed =>
      'La demande photo a échoué. Réessaie.';

  @override
  String get toastGenerationTaskCreateFailed =>
      'La demande photo a échoué. Réessaie.';

  @override
  String get toastGenerationBackendFailed =>
      'La demande photo a échoué. Réessaie.';

  @override
  String get toastResultSaveFailed =>
      'Impossible d\'enregistrer l\'image résultat. Vérifie l\'autorisation Photos puis réessaie.';

  @override
  String get toastGalleryICloudImportFailed =>
      'Impossible de télécharger cette photo depuis iCloud. Réessaie plus tard.';

  @override
  String get toastGalleryImportFailed =>
      'Impossible d\'importer cette photo. Essaies-en une autre.';

  @override
  String get toastFavoriteFailed =>
      'Impossible d\'enregistrer dans Favoris. Réessaie plus tard.';

  @override
  String get toastOriginalSaved => 'Photo originale enregistrée dans Photos.';

  @override
  String get toastOriginalSaveFailed =>
      'Impossible d\'enregistrer la photo originale. Vérifie les permissions Photos et réessaie.';

  @override
  String get toastFeedbackSubmitted => 'Commentaire envoyé.';

  @override
  String get toastFeedbackFailed =>
      'Impossible d\'envoyer le commentaire. Réessaie plus tard.';

  @override
  String get toastOpenPhotoLibraryFailed => 'Impossible d\'ouvrir Photos.';

  @override
  String get settingsClearOriginalCachePartialTitle => 'Vidage partiel';

  @override
  String toastPurchaseSuccess(int credits) {
    return 'Achat réussi. $credits crédits ajoutés.';
  }

  @override
  String get toastPurchaseFailed => 'Achat incomplet. Réessaie plus tard.';

  @override
  String get toastRestorePurchaseFailed =>
      'Impossible de restaurer les achats. Réessaie plus tard.';

  @override
  String toastCreditRedemptionSuccess(int credits) {
    return '$credits crédits échangés.';
  }

  @override
  String get toastCreditRedemptionInvalid => 'Format de code invalide.';

  @override
  String get toastCreditRedemptionUnavailable =>
      'Ce code est invalide ou déjà utilisé.';

  @override
  String get toastCreditRedemptionCampaignLimitReached =>
      'Cette offre est limitée à une utilisation par compte.';

  @override
  String get toastCreditRedemptionRateLimited =>
      'Trop de tentatives. Réessaie plus tard.';

  @override
  String get toastCreditRedemptionFailed =>
      'Échange du code échoué. Réessaie plus tard.';
}
