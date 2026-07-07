// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Fantasy Camera';

  @override
  String get appName => 'Fantasy Camera';

  @override
  String get authAccountCreatedSignIn => 'アカウントを作成しました。ログインしてください。';

  @override
  String get authAlreadyHaveAccountSignIn => 'アカウントをお持ちですか？ログイン';

  @override
  String get authAppleSignInFailed => 'Appleでのサインインに失敗しました。';

  @override
  String get authAuthenticationFailed => '認証に失敗しました。もう一度お試しください。';

  @override
  String get authCameraDevicesLoadFailed => 'カメラデバイスを読み込めませんでした。';

  @override
  String get authContinueWithApple => 'Appleでサインイン';

  @override
  String get authContinueWithGoogle => 'Googleでログイン';

  @override
  String get authCreateAccountButton => 'アカウントを作成';

  @override
  String get authCreateAccountSubtitle => 'アカウントを作成してください';

  @override
  String get authEmailInvalid => '有効なメールアドレスを入力してください。';

  @override
  String get authEmailLabel => 'メールアドレス';

  @override
  String get authEmailPlaceholder => 'メール';

  @override
  String get authEditorialAccessBadge => '編集アクセス';

  @override
  String get authEditorialSubtitle => '認証情報を入力して続行してください';

  @override
  String get authEditorialTitleLine1 => 'レンズが';

  @override
  String get authEditorialTitleLine2 => '待っている';

  @override
  String get authForgotKeyButton => 'パスワードをお忘れですか？';

  @override
  String get authGoogleSignInFailed => 'Googleでのログインに失敗しました。';

  @override
  String get authEmailRequired => 'メールアドレスは必須です。';

  @override
  String get authInvalidCredentials =>
      'メールアドレスまたはパスワードが正しくありません。新規アカウントの場合は、先にアカウントを作成し、必要に応じてメールを確認してください。';

  @override
  String get authMissingSupabaseConfig =>
      'Supabase設定が見つかりません。SUPABASE_URLとSUPABASE_PUBLISHABLE_KEYのdart-definesを設定してください。';

  @override
  String get authNewHereCreateAccount => '新規登録';

  @override
  String get authOrDividerLabel => 'または';

  @override
  String get authPasswordMinLength => '6文字以上で入力してください。';

  @override
  String get authPasswordLabel => 'パスワード';

  @override
  String get authPasswordPlaceholder => 'パスワード';

  @override
  String get authSecretKeyPlaceholder => '••••••••';

  @override
  String get authSessionExpired => 'セッションの有効期限が切れました。再度ログインしてください。';

  @override
  String get authSessionRestoreFailed => 'セッションを復元できませんでした。再度ログインしてください。';

  @override
  String get authSignInButton => 'ログイン';

  @override
  String get authSignInSubtitle => '続行するにはログインしてください';

  @override
  String cameraCreditsBalanceSemanticsLabel(Object value) {
    return '$valueクレジット';
  }

  @override
  String get cameraNoCameraFound => 'カメラが見つかりません。';

  @override
  String get cameraStartingCamera => 'カメラを起動中...';

  @override
  String cameraErrorMessage(Object message) {
    return 'カメラエラー：$message';
  }

  @override
  String get generationSubmissionDownloadingFromICloud => 'iCloudからダウンロード中';

  @override
  String get generationSubmissionPreparingPhoto => '写真を準備中...';

  @override
  String get generationSubmissionGalleryTitle => 'ギャラリー';

  @override
  String get generationSubmissionImportNew => '写真から読み込む';

  @override
  String get generationSubmissionDefaultMomentMode => 'モーメント';

  @override
  String get generationSubmissionDefaultPromptBadge => 'デフォルト';

  @override
  String get generationSubmissionSelectMoment => '写真を撮影または選択';

  @override
  String get generationSubmissionProcessedResultImageLoadFailed =>
      '処理済み結果画像を読み込めませんでした';

  @override
  String get generationSubmissionResultImageLoadFailed => '結果画像を読み込めませんでした';

  @override
  String get generationSubmissionOriginalImageLoadFailed => '元の画像を読み込めませんでした';

  @override
  String get generationSubmissionTapToLoadResult => 'タップして結果を読み込む';

  @override
  String get generationSubmissionStatusGenerationFailed => '生成に失敗しました';

  @override
  String get generationSubmissionStatusWaitingForConfirmation => '確認待ち';

  @override
  String get generationSubmissionStatusPreparingUploadImage => 'アップロード画像を準備中';

  @override
  String get generationSubmissionStatusProcessingResultImage => '結果画像を処理中';

  @override
  String get generationSubmissionStatusResultSaved => '結果を保存しました';

  @override
  String get generationSubmissionStatusResultProcessingFailed => '結果の処理に失敗しました';

  @override
  String get generationSubmissionStatusWaitingForGenerationResult => '生成結果を待機中';

  @override
  String get generationSubmissionStatusPreparingGenerationTask => '生成タスクを準備中';

  @override
  String get generationSubmissionConfirmationGuideMessage =>
      '写真の最適化には1枚につき2クレジットを使用します。確認後、完了まで約1分かかります。アプリを閉じても、完了時に通知でお知らせします。';

  @override
  String get generationSubmissionConfirmationGuideDismiss => '了解';

  @override
  String get generationSubmissionActionViewInAlbum => 'アルバムで表示';

  @override
  String get generationSubmissionActionSaveOriginal => '元の写真を保存';

  @override
  String get generationSubmissionActionRetry => '再試行';

  @override
  String get generationSubmissionActionDislikeImage => 'この画像は気に入らない';

  @override
  String get generationSubmissionActionFeedbackSubmitted => 'フィードバックを送信しました';

  @override
  String get generationSubmissionDislikeFeedbackTitle => '気に入りませんでしたか？';

  @override
  String get generationSubmissionDislikeFeedbackPlaceholder =>
      'フィードバックをお聞かせください（任意）';

  @override
  String get generationSubmissionDislikeFeedbackSubmit => '送信';

  @override
  String get generationSubmissionActionRemove => '削除';

  @override
  String get promptSwitchRecomposeTitle => '再構成';

  @override
  String get promptSwitchBeautifyFaceTitle => 'ビューティー';

  @override
  String get promptSwitchCleanFrameTitle => 'すっきり';

  @override
  String get promptSwitchBackgroundBlurTitle => '背景ぼかし';

  @override
  String get promptStyleRealisticTitle => 'リアル';

  @override
  String get promptCaptureModeManualTitle => 'マニュアル';

  @override
  String get promptCaptureModeAutoTitle => 'オート';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsFallbackUserName => 'Julian Vane';

  @override
  String settingsCreditsValue(int value) {
    return '$valueクレジット';
  }

  @override
  String get settingsCreditsLoading => '--クレジット';

  @override
  String get settingsCreditsUnavailable => 'クレジット情報を取得できません';

  @override
  String get settingsSectionAppearance => '外観';

  @override
  String get settingsAppearanceLight => 'ライト';

  @override
  String get settingsAppearanceDark => 'ダーク';

  @override
  String get settingsSectionCapture => '撮影';

  @override
  String get settingsConfirmBeforeGenerationTitle => '生成前に確認';

  @override
  String get settingsConfirmBeforeGenerationSubtitle => 'アップロード前に写真を確認する';

  @override
  String get settingsMirrorFrontCameraTitle => 'フロントカメラをミラー';

  @override
  String get settingsMirrorFrontCameraSubtitle => 'フロントカメラで撮影した写真を反転して保存';

  @override
  String get settingsSectionGeneral => '一般';

  @override
  String get settingsLanguageTitle => '言語';

  @override
  String get settingsLanguageSubtitle => 'システムのデフォルト';

  @override
  String get settingsLanguageSystem => 'システムのデフォルト';

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
  String get settingsClearOriginalCacheTitle => '元画像キャッシュを削除';

  @override
  String get settingsClearOriginalCacheSubtitle => 'ローカルのカメラ元画像を削除';

  @override
  String get settingsClearOriginalCacheCalculating => '再計算中...';

  @override
  String get settingsClearOriginalCacheNoClearable => '削除できる元画像はありません';

  @override
  String get settingsClearOriginalCacheConfirmTitle => '元画像キャッシュを削除しますか？';

  @override
  String get settingsClearOriginalCacheConfirmMessage =>
      'このデバイスでサインインしたすべてのアカウントのカメラ元画像キャッシュが削除されます。生成記録と生成済み画像は削除されません。';

  @override
  String get settingsClearOriginalCacheConfirmAction => '削除';

  @override
  String settingsClearOriginalCacheSize(Object size) {
    return '$size削除可能';
  }

  @override
  String settingsClearOriginalCacheLastCalculatedSize(Object size) {
    return '前回の計算：$size削除可能';
  }

  @override
  String get settingsClearOriginalCacheInProgress => '削除中...';

  @override
  String get settingsClearOriginalCacheDoneTitle => '削除完了';

  @override
  String settingsClearOriginalCacheDoneMessage(int count) {
    return 'カメラ元画像を$count枚削除しました。';
  }

  @override
  String settingsClearOriginalCachePartialMessage(
    int clearedCount,
    int failedCount,
  ) {
    return 'カメラ元画像を$clearedCount枚削除しました。$failedCount枚は失敗しました。';
  }

  @override
  String get settingsClearOriginalCacheFailedTitle => '削除失敗';

  @override
  String get settingsClearOriginalCacheFailedMessage =>
      '元画像キャッシュを削除できませんでした。後でもう一度お試しください。';

  @override
  String get settingsRedeemCodeTitle => '引き換えコードを使用';

  @override
  String get settingsRedeemCodeSubtitle => 'コードを使ってクレジットを取得';

  @override
  String get settingsManageSubscriptionTitle => 'クレジットを購入';

  @override
  String get settingsManageSubscriptionSubtitle => 'クレジットパックと購入の復元';

  @override
  String get settingsSectionInformation => '情報';

  @override
  String get settingsPrivacyPolicyTitle => 'プライバシーポリシー';

  @override
  String get settingsPrivacyPolicySubtitle => 'データと写真の取り扱い';

  @override
  String get settingsTermsTitle => '利用規約';

  @override
  String get settingsTermsSubtitle => 'サービス規則と権利';

  @override
  String get settingsAboutTitle => 'このアプリについて';

  @override
  String get settingsAboutSubtitle => 'バージョン情報とクレジット';

  @override
  String get settingsContactDeveloperTitle => '開発者に連絡';

  @override
  String get settingsContactDeveloperSubtitle => 'フィードバックまたはサポートリクエストを送信';

  @override
  String get settingsSectionAccount => 'アカウント';

  @override
  String get settingsDeleteAccountTitle => 'アカウントを削除';

  @override
  String get settingsDeleteAccountSubtitle => 'アカウントを完全に削除します';

  @override
  String get settingsDeleteAccountConfirmTitle => 'アカウントを削除しますか？';

  @override
  String get settingsDeleteAccountConfirmMessage =>
      'アカウント、クレジット、クラウドの生成履歴は完全に削除されます。この操作は元に戻せません。';

  @override
  String get settingsDeleteAccountConfirmAction => '削除';

  @override
  String get settingsDeleteAccountFailedTitle => '削除失敗';

  @override
  String get settingsDeleteAccountFailedMessage =>
      'アカウントを削除できませんでした。後でもう一度お試しください。';

  @override
  String get settingsSignOutTitle => 'サインアウト';

  @override
  String get settingsSignOutSubtitle => 'サインイン画面に戻る';

  @override
  String get settingsSignOutConfirmTitle => 'サインアウトしますか？';

  @override
  String get settingsSignOutConfirmMessage =>
      'ローカルの作品はこのデバイスに残ります。いつでも再度サインインできます。';

  @override
  String get settingsSignOutConfirmAction => 'サインアウト';

  @override
  String get settingsSignOutFailedTitle => 'サインアウト失敗';

  @override
  String get settingsSignOutFailedMessage => 'サインアウトできませんでした。後でもう一度お試しください。';

  @override
  String get billingTitle => 'クレジット';

  @override
  String get billingHeroTitle => 'クレジットを取得';

  @override
  String get billingHeroSubtitle => 'クレジットは画像生成に使用されます';

  @override
  String billingCreditPackTitle(int credits) {
    return '$creditsクレジット';
  }

  @override
  String get billingCreditPackSubtitle => '買い切りクレジットパック';

  @override
  String get billingPurchaseButton => '購入';

  @override
  String billingPurchaseSuccessButton(int credits) {
    return '購入完了（+$creditsクレジット）';
  }

  @override
  String get billingRestorePurchases => '購入を復元';

  @override
  String get billingRedeemCodeTitle => 'コードを引き換える';

  @override
  String get billingRedeemCodePlaceholder => 'コードを入力';

  @override
  String get billingRedeemCodeButton => '引き換える';

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get commonOK => 'OK';

  @override
  String get billingProductsUnavailable => '現在利用できるクレジットパックはありません。';

  @override
  String get billingRetry => '再試行';

  @override
  String billingGrantedCreditsMessage(int credits) {
    return '+$creditsクレジット';
  }

  @override
  String get billingLegalNote =>
      '購入はApp Storeで処理されます。続行することで、利用規約とプライバシーポリシーに同意したことになります。';

  @override
  String get toastGenerationNetworkFailed => 'ネットワークが不安定です。後でもう一度お試しください。';

  @override
  String get toastOriginalUnavailable =>
      '元の写真が見つからないか読み込めません。写真へのアクセス権限を確認してから再試行してください。';

  @override
  String get toastInsufficientCredits => 'クレジットが不足しています。';

  @override
  String get toastGenerationSubmitFailed => '写真リクエストに失敗しました。再試行してください。';

  @override
  String get toastGenerationUploadFailed => '写真リクエストに失敗しました。再試行してください。';

  @override
  String get toastGenerationTaskCreateFailed => '写真リクエストに失敗しました。再試行してください。';

  @override
  String get toastGenerationBackendFailed => '写真リクエストに失敗しました。再試行してください。';

  @override
  String get toastResultSaveFailed =>
      '結果画像を保存できませんでした。写真へのアクセス権限を確認してから再試行してください。';

  @override
  String get toastGalleryICloudImportFailed =>
      'iCloudからこの写真をダウンロードできませんでした。後でもう一度お試しください。';

  @override
  String get toastGalleryImportFailed => 'この写真を読み込めませんでした。別の写真をお試しください。';

  @override
  String get toastFavoriteFailed => 'お気に入りに保存できませんでした。後でもう一度お試しください。';

  @override
  String get toastOriginalSaved => '元の写真を写真アプリに保存しました。';

  @override
  String get toastOriginalSaveFailed =>
      '元の写真を保存できませんでした。写真アプリのアクセス権限を確認してから再試行してください。';

  @override
  String get toastFeedbackSubmitted => 'フィードバックを送信しました。';

  @override
  String get toastFeedbackFailed => 'フィードバックを送信できませんでした。後でもう一度お試しください。';

  @override
  String get toastOpenPhotoLibraryFailed => '写真アプリを開けませんでした。';

  @override
  String get toastOpenExternalLinkFailed => 'リンクを開けませんでした。後でもう一度お試しください。';

  @override
  String get settingsClearOriginalCachePartialTitle => '一部削除完了';

  @override
  String toastPurchaseSuccess(int credits) {
    return '購入完了。$creditsクレジットが追加されました。';
  }

  @override
  String get toastPurchaseFailed => '購入を完了できませんでした。後でもう一度お試しください。';

  @override
  String get toastRestorePurchaseFailed => '購入を復元できませんでした。後でもう一度お試しください。';

  @override
  String toastCreditRedemptionSuccess(int credits) {
    return '$creditsクレジットを引き換えました。';
  }

  @override
  String get toastCreditRedemptionInvalid => 'コードの形式が無効です。';

  @override
  String get toastCreditRedemptionUnavailable => 'このコードは無効か、すでに使用されています。';

  @override
  String get toastCreditRedemptionCampaignLimitReached =>
      'このオファーは1アカウントにつき1回のみ利用できます。';

  @override
  String get toastCreditRedemptionRateLimited => '試行回数が多すぎます。後でもう一度お試しください。';

  @override
  String get toastCreditRedemptionFailed => 'コードの引き換えに失敗しました。後でもう一度お試しください。';
}
