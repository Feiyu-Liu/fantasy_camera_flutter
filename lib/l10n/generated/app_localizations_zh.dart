// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Fantasy Camera';

  @override
  String get appName => 'Fantasy Camera';

  @override
  String get authAccountCreatedSignIn => '账号已创建，请登录。';

  @override
  String get authAlreadyHaveAccountSignIn => '已有账号？登录';

  @override
  String get authAppleSignInFailed => 'Apple 登录失败。';

  @override
  String get authAuthenticationFailed => '认证失败，请重试。';

  @override
  String get authCameraDevicesLoadFailed => '无法加载相机设备。';

  @override
  String get authContinueWithApple => '通过 Apple 继续';

  @override
  String get authContinueWithGoogle => '通过 Google 继续';

  @override
  String get authCreateAccountButton => '创建账号';

  @override
  String get authCreateAccountSubtitle => '创建你的账号';

  @override
  String get authEmailInvalid => '请输入有效的邮箱。';

  @override
  String get authEmailLabel => '邮箱地址';

  @override
  String get authEmailPlaceholder => '邮箱';

  @override
  String get authEditorialAccessBadge => '编辑访问';

  @override
  String get authEditorialSubtitle => '输入凭据以继续';

  @override
  String get authEditorialTitleLine1 => '镜头';

  @override
  String get authEditorialTitleLine2 => '已就绪';

  @override
  String get authForgotKeyButton => '忘记密码？';

  @override
  String get authGoogleSignInFailed => 'Google 登录失败。';

  @override
  String get authEmailRequired => '请输入邮箱。';

  @override
  String get authInvalidCredentials => '邮箱或密码不正确。如果这是新账号，请先创建账号，并按要求确认邮箱。';

  @override
  String get authMissingSupabaseConfig =>
      '缺少 Supabase 配置。请先通过 dart-defines 设置 SUPABASE_URL 和 SUPABASE_PUBLISHABLE_KEY。';

  @override
  String get authNewHereCreateAccount => '新用户？创建账号';

  @override
  String get authOrDividerLabel => '或';

  @override
  String get authPasswordMinLength => '请至少输入 6 个字符。';

  @override
  String get authPasswordLabel => '密码';

  @override
  String get authPasswordPlaceholder => '密码';

  @override
  String get authSecretKeyPlaceholder => '••••••••';

  @override
  String get authSessionExpired => '会话已过期，请重新登录。';

  @override
  String get authSessionRestoreFailed => '无法恢复会话，请登录。';

  @override
  String get authSignInButton => '登录';

  @override
  String get authSignInSubtitle => '登录以继续';

  @override
  String cameraCreditsBalanceSemanticsLabel(Object value) {
    return '积分 $value';
  }

  @override
  String get cameraNoCameraFound => '未找到相机。';

  @override
  String get cameraStartingCamera => '正在启动相机...';

  @override
  String cameraErrorMessage(Object message) {
    return '相机错误：$message';
  }

  @override
  String get generationSubmissionDownloadingFromICloud => '正在从 iCloud 下载';

  @override
  String get generationSubmissionPreparingPhoto => '正在准备照片...';

  @override
  String get generationSubmissionRelatedMoments => '此时此刻';

  @override
  String get generationSubmissionImportNew => '从相册导入';

  @override
  String get generationSubmissionDefaultMomentMode => '时刻';

  @override
  String get generationSubmissionDefaultPromptBadge => '默认';

  @override
  String get generationSubmissionSelectMoment => '拍摄或选择照片';

  @override
  String get generationSubmissionProcessedResultImageLoadFailed =>
      '处理后的结果图无法加载';

  @override
  String get generationSubmissionResultImageLoadFailed => '结果图无法加载';

  @override
  String get generationSubmissionOriginalImageLoadFailed => '原图无法加载';

  @override
  String get generationSubmissionTapToLoadResult => '轻点加载结果';

  @override
  String get generationSubmissionStatusGenerationFailed => '生成失败';

  @override
  String get generationSubmissionStatusWaitingForConfirmation => '等待确认';

  @override
  String get generationSubmissionStatusPreparingUploadImage => '正在准备上传图片';

  @override
  String get generationSubmissionStatusProcessingResultImage => '正在处理结果图';

  @override
  String get generationSubmissionStatusResultSaved => '结果已保存';

  @override
  String get generationSubmissionStatusResultProcessingFailed => '结果处理失败';

  @override
  String get generationSubmissionStatusWaitingForGenerationResult => '等待生成结果';

  @override
  String get generationSubmissionStatusPreparingGenerationTask => '正在准备生成任务';

  @override
  String get generationSubmissionActionViewInAlbum => '在相册中查看';

  @override
  String get generationSubmissionActionSaveOriginal => '保存原图';

  @override
  String get generationSubmissionActionRetry => '重试';

  @override
  String get generationSubmissionActionDislikeImage => '不喜欢这张图片';

  @override
  String get generationSubmissionActionRemove => '移除';

  @override
  String get promptSwitchRecomposeTitle => '重构图';

  @override
  String get promptSwitchBeautifyFaceTitle => '人物优化';

  @override
  String get promptSwitchCleanFrameTitle => '画面净化';

  @override
  String get promptSwitchBackgroundBlurTitle => '背景虚化';

  @override
  String get promptStyleRealisticTitle => '写实';

  @override
  String get promptCaptureModePortraitTitle => '人像';

  @override
  String get promptCaptureModeGeneralTitle => '通用';

  @override
  String get settingsTitle => '设置';

  @override
  String get settingsFallbackUserName => 'Julian Vane';

  @override
  String settingsCreditsValue(int value) {
    return '$value 积分';
  }

  @override
  String get settingsCreditsLoading => '-- 积分';

  @override
  String get settingsCreditsUnavailable => '积分不可用';

  @override
  String get settingsSectionAppearance => '外观';

  @override
  String get settingsAppearanceLight => '浅色';

  @override
  String get settingsAppearanceDark => '深色';

  @override
  String get settingsSectionCapture => '拍摄';

  @override
  String get settingsConfirmBeforeGenerationTitle => '拍摄后图片生成确认';

  @override
  String get settingsConfirmBeforeGenerationSubtitle => '上传前先确认照片';

  @override
  String get settingsSectionGeneral => '通用';

  @override
  String get settingsLanguageTitle => '语言切换';

  @override
  String get settingsLanguageSubtitle => '跟随系统';

  @override
  String get settingsClearOriginalCacheTitle => '清除原图缓存';

  @override
  String get settingsClearOriginalCacheSubtitle => '移除本地相机原图';

  @override
  String get settingsClearOriginalCacheInProgress => '正在清理...';

  @override
  String get settingsClearOriginalCacheDoneTitle => '清理完成';

  @override
  String settingsClearOriginalCacheDoneMessage(int count) {
    return '已清除 $count 张相机原图。';
  }

  @override
  String settingsClearOriginalCachePartialMessage(
    int clearedCount,
    int failedCount,
  ) {
    return '已清除 $clearedCount 张相机原图，$failedCount 张清理失败。';
  }

  @override
  String get settingsClearOriginalCacheFailedTitle => '清理失败';

  @override
  String get settingsClearOriginalCacheFailedMessage => '无法清除原图缓存，请稍后重试。';

  @override
  String get settingsManageSubscriptionTitle => '购买积分';

  @override
  String get settingsManageSubscriptionSubtitle => '积分包与恢复购买';

  @override
  String get settingsSectionInformation => '信息';

  @override
  String get settingsPrivacyPolicyTitle => '隐私政策';

  @override
  String get settingsPrivacyPolicySubtitle => '数据与照片处理说明';

  @override
  String get settingsTermsTitle => '使用条款';

  @override
  String get settingsTermsSubtitle => '服务规则与权利说明';

  @override
  String get settingsAboutTitle => '关于';

  @override
  String get settingsAboutSubtitle => '版本与致谢';

  @override
  String get settingsContactDeveloperTitle => '联系开发者';

  @override
  String get settingsContactDeveloperSubtitle => '发送反馈或支持请求';

  @override
  String get settingsSectionAccount => '账号';

  @override
  String get settingsDeleteAccountTitle => '注销账号';

  @override
  String get settingsDeleteAccountSubtitle => '永久移除当前账号';

  @override
  String get settingsSignOutTitle => '退出登录';

  @override
  String get settingsSignOutSubtitle => '返回登录页';

  @override
  String get billingTitle => '积分';

  @override
  String get billingHeroTitle => '获取创作积分';

  @override
  String get billingHeroSubtitle => '积分用于生成图片。购买完成后会由服务器验证并写入余额。';

  @override
  String billingCreditPackTitle(int credits) {
    return '$credits 积分';
  }

  @override
  String get billingCreditPackSubtitle => '一次性积分包';

  @override
  String get billingPurchaseButton => '购买';

  @override
  String get billingRestorePurchases => '恢复购买';

  @override
  String get commonOK => '好';

  @override
  String get billingProductsUnavailable => '当前没有可购买的积分包。';

  @override
  String get billingRetry => '重试';

  @override
  String billingGrantedCreditsMessage(int credits) {
    return '+$credits 积分';
  }

  @override
  String get billingLegalNote => '购买由 App Store 处理。继续购买即表示你同意使用条款与隐私政策。';
}
