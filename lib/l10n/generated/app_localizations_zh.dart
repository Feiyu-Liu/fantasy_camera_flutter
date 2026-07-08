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
  String get authAccountCreatedSignIn => '账号已创建，请查看邮箱并完成验证后登录。';

  @override
  String get authAccountAlreadyExists => '该邮箱已注册，请直接登录。';

  @override
  String get authAlreadyHaveAccountSignIn => '已有账号？登录';

  @override
  String get authAppleSignInFailed => 'Apple 登录失败。';

  @override
  String get authAuthenticationFailed => '认证失败，请重试。';

  @override
  String get authCameraDevicesLoadFailed => '无法加载相机设备。';

  @override
  String get authContinueWithApple => '通过 Apple 登录';

  @override
  String get authContinueWithGoogle => '通过 Google 登录';

  @override
  String get authCreateAccountButton => '创建账号';

  @override
  String get authCreateAccountSubtitle => '创建你的账号';

  @override
  String get authEmailInvalid => '请输入有效的邮箱。';

  @override
  String get authEmailLabel => '邮箱地址';

  @override
  String get authEmailNotConfirmed => '邮箱尚未确认，请先查看邮箱并完成确认。';

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
  String get authRateLimited => '请求过于频繁，请稍后再试。';

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
  String get authSignupDisabled => '当前暂不支持创建账号。';

  @override
  String get authWeakPassword => '密码强度不足，请换一个更安全的密码。';

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
  String get generationSubmissionGalleryTitle => '画廊';

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
  String get generationSubmissionConfirmationGuideMessage =>
      '每张照片优化将消耗2积分，确认后需要等待约1分钟。期间你可以退出app，完成后会通过通知提醒';

  @override
  String get generationSubmissionConfirmationGuideDismiss => '知道了';

  @override
  String get generationSubmissionActionViewInAlbum => '在相册中查看';

  @override
  String get generationSubmissionActionSaveOriginal => '保存原始照片';

  @override
  String get generationSubmissionActionRetry => '重试';

  @override
  String get generationSubmissionActionDislikeImage => '不喜欢这张图片';

  @override
  String get generationSubmissionActionFeedbackSubmitted => '已提交反馈';

  @override
  String get generationSubmissionDislikeFeedbackTitle => '这张不太满意？';

  @override
  String get generationSubmissionDislikeFeedbackPlaceholder => '请留下宝贵建议（可选）';

  @override
  String get generationSubmissionDislikeFeedbackSubmit => '提交';

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
  String get promptCaptureModeManualTitle => '手动';

  @override
  String get promptCaptureModeAutoTitle => '自动';

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
  String get settingsMirrorFrontCameraTitle => '镜像前置相机';

  @override
  String get settingsMirrorFrontCameraSubtitle => '使用前置相机拍摄时保存镜像照片';

  @override
  String get settingsSectionGeneral => '通用';

  @override
  String get settingsLanguageTitle => '语言切换';

  @override
  String get settingsLanguageSubtitle => '跟随系统';

  @override
  String get settingsLanguageSystem => '跟随系统';

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
  String get settingsClearOriginalCacheTitle => '清除原图缓存';

  @override
  String get settingsClearOriginalCacheSubtitle => '移除本地相机原图';

  @override
  String get settingsClearOriginalCacheCalculating => '正在重新计算...';

  @override
  String get settingsClearOriginalCacheNoClearable => '暂无可清理原图';

  @override
  String get settingsClearOriginalCacheConfirmTitle => '清除原图缓存？';

  @override
  String get settingsClearOriginalCacheConfirmMessage =>
      '这会删除当前设备上所有曾登录账号的相机原图缓存。生成记录和已生成图片不会被删除。';

  @override
  String get settingsClearOriginalCacheConfirmAction => '清除';

  @override
  String settingsClearOriginalCacheSize(Object size) {
    return '可清理 $size';
  }

  @override
  String settingsClearOriginalCacheLastCalculatedSize(Object size) {
    return '上次计算：可清理 $size';
  }

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
  String get settingsRedeemCodeTitle => '使用兑换码';

  @override
  String get settingsRedeemCodeSubtitle => '使用兑换码获取积分';

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
  String get settingsDeleteAccountConfirmTitle => '注销账号？';

  @override
  String get settingsDeleteAccountConfirmMessage =>
      '账号、积分和云端生成记录会被永久删除，此操作无法撤销。';

  @override
  String get settingsDeleteAccountConfirmAction => '注销';

  @override
  String get settingsDeleteAccountFailedTitle => '注销失败';

  @override
  String get settingsDeleteAccountFailedMessage => '无法注销账号，请稍后重试。';

  @override
  String get settingsSignOutTitle => '退出登录';

  @override
  String get settingsSignOutSubtitle => '返回登录页';

  @override
  String get settingsSignOutConfirmTitle => '退出登录？';

  @override
  String get settingsSignOutConfirmMessage => '退出账号会保留当前的照片集';

  @override
  String get settingsSignOutConfirmAction => '退出';

  @override
  String get settingsSignOutFailedTitle => '退出失败';

  @override
  String get settingsSignOutFailedMessage => '无法退出登录，请稍后重试。';

  @override
  String get billingTitle => '积分';

  @override
  String get billingHeroTitle => '获取创作积分';

  @override
  String get billingHeroSubtitle => '积分用于图片生成';

  @override
  String billingCreditPackTitle(int credits) {
    return '$credits 积分';
  }

  @override
  String get billingCreditPackSubtitle => '一次性积分包';

  @override
  String billingCreditPackSavingsBadge(int percent) {
    return '节省 $percent%';
  }

  @override
  String get billingPurchaseButton => '购买';

  @override
  String billingPurchaseSuccessButton(int credits) {
    return '购买成功（积分 +$credits）';
  }

  @override
  String get billingRestorePurchases => '恢复购买';

  @override
  String get billingRedeemCodeTitle => '兑换码';

  @override
  String get billingRedeemCodePlaceholder => '输入兑换码';

  @override
  String get billingRedeemCodeButton => '兑换';

  @override
  String get commonCancel => '取消';

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

  @override
  String get toastGenerationNetworkFailed => '网络连接不稳定，请稍后重试。';

  @override
  String get toastOriginalUnavailable => '原图已丢失或无法读取，请检查相册权限后重试。';

  @override
  String get toastInsufficientCredits => '创作积分不足，请先获取积分。';

  @override
  String get toastGenerationSubmitFailed => '照片请求失败，请重试。';

  @override
  String get toastGenerationUploadFailed => '照片请求失败，请重试。';

  @override
  String get toastGenerationTaskCreateFailed => '照片请求失败，请重试。';

  @override
  String get toastGenerationBackendFailed => '照片请求失败，请重试。';

  @override
  String get toastResultSaveFailed => '结果图保存失败，请检查相册权限后重试。';

  @override
  String get toastGalleryICloudImportFailed => '照片暂时无法从 iCloud 下载，请稍后重试。';

  @override
  String get toastGalleryImportFailed => '无法导入这张照片，请换一张试试。';

  @override
  String get toastFavoriteFailed => '无法更新系统收藏，请稍后重试。';

  @override
  String get toastOriginalSaved => '原图已保存到相册。';

  @override
  String get toastOriginalSaveFailed => '原图保存失败，请检查相册权限后重试。';

  @override
  String get toastFeedbackSubmitted => '反馈已提交。';

  @override
  String get toastFeedbackFailed => '反馈提交失败，请稍后重试。';

  @override
  String get toastOpenPhotoLibraryFailed => '无法打开系统相册。';

  @override
  String get toastOpenExternalLinkFailed => '无法打开链接，请稍后重试。';

  @override
  String get settingsClearOriginalCachePartialTitle => '部分清理失败';

  @override
  String toastPurchaseSuccess(int credits) {
    return '购买成功，已获得 $credits 积分。';
  }

  @override
  String get toastPurchaseFailed => '购买未完成，请稍后重试。';

  @override
  String toastRestorePurchaseSuccess(int credits) {
    return '恢复购买成功，已获得 $credits 积分。';
  }

  @override
  String get toastRestorePurchaseSynced => '购买记录已同步。';

  @override
  String get toastRestorePurchaseFailed => '恢复购买失败，请稍后重试。';

  @override
  String toastCreditRedemptionSuccess(int credits) {
    return '已兑换 $credits 积分。';
  }

  @override
  String get toastCreditRedemptionInvalid => '兑换码格式不正确。';

  @override
  String get toastCreditRedemptionUnavailable => '兑换码无效或已被使用。';

  @override
  String get toastCreditRedemptionCampaignLimitReached => '该活动每个用户只能兑换一次。';

  @override
  String get toastCreditRedemptionRateLimited => '尝试次数过多，请稍后再试。';

  @override
  String get toastCreditRedemptionFailed => '兑换失败，请稍后重试。';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get appTitle => 'Fantasy Camera';

  @override
  String get appName => 'Fantasy Camera';

  @override
  String get authAccountCreatedSignIn => '帳號已建立，請查看信箱並完成驗證後登入。';

  @override
  String get authAccountAlreadyExists => '此電子郵件已註冊，請直接登入。';

  @override
  String get authAlreadyHaveAccountSignIn => '已有帳號？登入';

  @override
  String get authAppleSignInFailed => 'Apple 登入失敗。';

  @override
  String get authAuthenticationFailed => '驗證失敗，請再試一次。';

  @override
  String get authCameraDevicesLoadFailed => '無法載入相機裝置。';

  @override
  String get authContinueWithApple => '以 Apple 登入';

  @override
  String get authContinueWithGoogle => '以 Google 登入';

  @override
  String get authCreateAccountButton => '建立帳號';

  @override
  String get authCreateAccountSubtitle => '建立你的帳號';

  @override
  String get authEmailInvalid => '請輸入有效的電子郵件。';

  @override
  String get authEmailLabel => '電子郵件地址';

  @override
  String get authEmailNotConfirmed => '電子郵件尚未確認，請先查看信箱並完成確認。';

  @override
  String get authEmailPlaceholder => '電子郵件';

  @override
  String get authEditorialAccessBadge => '編輯存取';

  @override
  String get authEditorialSubtitle => '請輸入憑證以繼續';

  @override
  String get authEditorialTitleLine1 => '鏡頭';

  @override
  String get authEditorialTitleLine2 => '已就緒';

  @override
  String get authForgotKeyButton => '忘記密碼？';

  @override
  String get authGoogleSignInFailed => 'Google 登入失敗。';

  @override
  String get authEmailRequired => '請輸入電子郵件。';

  @override
  String get authInvalidCredentials => '電子郵件或密碼不正確。若為新帳號，請先建立帳號，並依要求確認電子郵件。';

  @override
  String get authMissingSupabaseConfig =>
      '缺少 Supabase 設定。請先透過 dart-defines 設定 SUPABASE_URL 與 SUPABASE_PUBLISHABLE_KEY。';

  @override
  String get authNewHereCreateAccount => '新用戶？建立帳號';

  @override
  String get authOrDividerLabel => '或';

  @override
  String get authPasswordMinLength => '請至少輸入 6 個字元。';

  @override
  String get authPasswordLabel => '密碼';

  @override
  String get authPasswordPlaceholder => '密碼';

  @override
  String get authRateLimited => '請求過於頻繁，請稍後再試。';

  @override
  String get authSecretKeyPlaceholder => '••••••••';

  @override
  String get authSessionExpired => '工作階段已過期，請重新登入。';

  @override
  String get authSessionRestoreFailed => '無法還原工作階段，請登入。';

  @override
  String get authSignInButton => '登入';

  @override
  String get authSignInSubtitle => '請登入以繼續';

  @override
  String get authSignupDisabled => '目前暫不支援建立帳號。';

  @override
  String get authWeakPassword => '密碼強度不足，請換一組更安全的密碼。';

  @override
  String cameraCreditsBalanceSemanticsLabel(Object value) {
    return '$value 點數';
  }

  @override
  String get cameraNoCameraFound => '找不到相機。';

  @override
  String get cameraStartingCamera => '正在啟動相機...';

  @override
  String cameraErrorMessage(Object message) {
    return '相機錯誤：$message';
  }

  @override
  String get generationSubmissionDownloadingFromICloud => '正在從 iCloud 下載';

  @override
  String get generationSubmissionPreparingPhoto => '正在準備照片...';

  @override
  String get generationSubmissionGalleryTitle => '作品集';

  @override
  String get generationSubmissionImportNew => '從照片匯入';

  @override
  String get generationSubmissionDefaultMomentMode => '時刻';

  @override
  String get generationSubmissionDefaultPromptBadge => '預設';

  @override
  String get generationSubmissionSelectMoment => '拍攝或選擇照片';

  @override
  String get generationSubmissionProcessedResultImageLoadFailed =>
      '無法載入處理後的結果圖片';

  @override
  String get generationSubmissionResultImageLoadFailed => '無法載入結果圖片';

  @override
  String get generationSubmissionOriginalImageLoadFailed => '無法載入原始圖片';

  @override
  String get generationSubmissionTapToLoadResult => '點一下以載入結果';

  @override
  String get generationSubmissionStatusGenerationFailed => '生成失敗';

  @override
  String get generationSubmissionStatusWaitingForConfirmation => '等待確認';

  @override
  String get generationSubmissionStatusPreparingUploadImage => '正在準備上傳圖片';

  @override
  String get generationSubmissionStatusProcessingResultImage => '正在處理結果圖片';

  @override
  String get generationSubmissionStatusResultSaved => '結果已儲存';

  @override
  String get generationSubmissionStatusResultProcessingFailed => '結果處理失敗';

  @override
  String get generationSubmissionStatusWaitingForGenerationResult => '等待生成結果';

  @override
  String get generationSubmissionStatusPreparingGenerationTask => '正在準備生成任務';

  @override
  String get generationSubmissionConfirmationGuideMessage =>
      '每張照片最佳化將消耗 2 點數，確認後需要等待約 1 分鐘。期間你可以退出 App，完成後會透過通知提醒';

  @override
  String get generationSubmissionConfirmationGuideDismiss => '知道了';

  @override
  String get generationSubmissionActionViewInAlbum => '在相簿中檢視';

  @override
  String get generationSubmissionActionSaveOriginal => '儲存原始照片';

  @override
  String get generationSubmissionActionRetry => '重試';

  @override
  String get generationSubmissionActionDislikeImage => '不喜歡這張圖片';

  @override
  String get generationSubmissionActionFeedbackSubmitted => '已送出回饋';

  @override
  String get generationSubmissionDislikeFeedbackTitle => '結果不滿意？';

  @override
  String get generationSubmissionDislikeFeedbackPlaceholder => '請留下寶貴意見（選填）';

  @override
  String get generationSubmissionDislikeFeedbackSubmit => '送出';

  @override
  String get generationSubmissionActionRemove => '移除';

  @override
  String get promptSwitchRecomposeTitle => '重新構圖';

  @override
  String get promptSwitchBeautifyFaceTitle => '人物美化';

  @override
  String get promptSwitchCleanFrameTitle => '淨化畫面';

  @override
  String get promptSwitchBackgroundBlurTitle => '背景模糊';

  @override
  String get promptStyleRealisticTitle => '寫實';

  @override
  String get promptCaptureModeManualTitle => '手動';

  @override
  String get promptCaptureModeAutoTitle => '自動';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsFallbackUserName => 'Julian Vane';

  @override
  String settingsCreditsValue(int value) {
    return '$value 點數';
  }

  @override
  String get settingsCreditsLoading => '-- 點數';

  @override
  String get settingsCreditsUnavailable => '點數不可用';

  @override
  String get settingsSectionAppearance => '外觀';

  @override
  String get settingsAppearanceLight => '淺色';

  @override
  String get settingsAppearanceDark => '深色';

  @override
  String get settingsSectionCapture => '拍攝';

  @override
  String get settingsConfirmBeforeGenerationTitle => '生成前確認';

  @override
  String get settingsConfirmBeforeGenerationSubtitle => '上傳前先確認照片';

  @override
  String get settingsMirrorFrontCameraTitle => '鏡像前置相機';

  @override
  String get settingsMirrorFrontCameraSubtitle => '使用前置相機拍攝時儲存鏡像照片';

  @override
  String get settingsSectionGeneral => '一般';

  @override
  String get settingsLanguageTitle => '語言';

  @override
  String get settingsLanguageSubtitle => '跟隨系統';

  @override
  String get settingsLanguageSystem => '跟隨系統';

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
  String get settingsClearOriginalCacheTitle => '清除原始快取';

  @override
  String get settingsClearOriginalCacheSubtitle => '移除本機相機原始照片';

  @override
  String get settingsClearOriginalCacheCalculating => '正在重新計算...';

  @override
  String get settingsClearOriginalCacheNoClearable => '沒有可清除的原始照片';

  @override
  String get settingsClearOriginalCacheConfirmTitle => '清除原始快取？';

  @override
  String get settingsClearOriginalCacheConfirmMessage =>
      '這將刪除此裝置上所有曾登入帳號的相機原始照片快取。生成記錄與已生成的圖片不會被刪除。';

  @override
  String get settingsClearOriginalCacheConfirmAction => '清除';

  @override
  String settingsClearOriginalCacheSize(Object size) {
    return '可清除 $size';
  }

  @override
  String settingsClearOriginalCacheLastCalculatedSize(Object size) {
    return '上次計算：可清除 $size';
  }

  @override
  String get settingsClearOriginalCacheInProgress => '正在清除...';

  @override
  String get settingsClearOriginalCacheDoneTitle => '清除完成';

  @override
  String settingsClearOriginalCacheDoneMessage(int count) {
    return '已清除 $count 張相機原始照片。';
  }

  @override
  String settingsClearOriginalCachePartialMessage(
    int clearedCount,
    int failedCount,
  ) {
    return '已清除 $clearedCount 張相機原始照片，$failedCount 張清除失敗。';
  }

  @override
  String get settingsClearOriginalCacheFailedTitle => '清除失敗';

  @override
  String get settingsClearOriginalCacheFailedMessage => '無法清除原始快取，請稍後再試。';

  @override
  String get settingsRedeemCodeTitle => '使用兌換碼';

  @override
  String get settingsRedeemCodeSubtitle => '使用兌換碼取得點數';

  @override
  String get settingsManageSubscriptionTitle => '購買點數';

  @override
  String get settingsManageSubscriptionSubtitle => '點數包與恢復購買';

  @override
  String get settingsSectionInformation => '資訊';

  @override
  String get settingsPrivacyPolicyTitle => '隱私權政策';

  @override
  String get settingsPrivacyPolicySubtitle => '資料與照片處理說明';

  @override
  String get settingsTermsTitle => '使用條款';

  @override
  String get settingsTermsSubtitle => '服務規則與權利說明';

  @override
  String get settingsAboutTitle => '關於';

  @override
  String get settingsAboutSubtitle => '版本資訊與致謝';

  @override
  String get settingsContactDeveloperTitle => '聯絡開發者';

  @override
  String get settingsContactDeveloperSubtitle => '傳送回饋或支援請求';

  @override
  String get settingsSectionAccount => '帳號';

  @override
  String get settingsDeleteAccountTitle => '刪除帳號';

  @override
  String get settingsDeleteAccountSubtitle => '永久移除你的帳號';

  @override
  String get settingsDeleteAccountConfirmTitle => '刪除帳號？';

  @override
  String get settingsDeleteAccountConfirmMessage =>
      '帳號、點數與雲端生成記錄會被永久刪除，此操作無法復原。';

  @override
  String get settingsDeleteAccountConfirmAction => '刪除';

  @override
  String get settingsDeleteAccountFailedTitle => '刪除失敗';

  @override
  String get settingsDeleteAccountFailedMessage => '無法刪除帳號，請稍後再試。';

  @override
  String get settingsSignOutTitle => '登出';

  @override
  String get settingsSignOutSubtitle => '返回登入畫面';

  @override
  String get settingsSignOutConfirmTitle => '登出？';

  @override
  String get settingsSignOutConfirmMessage => '你的本機作品將保留在此裝置上。你可以隨時重新登入。';

  @override
  String get settingsSignOutConfirmAction => '登出';

  @override
  String get settingsSignOutFailedTitle => '登出失敗';

  @override
  String get settingsSignOutFailedMessage => '無法登出，請稍後再試。';

  @override
  String get billingTitle => '點數';

  @override
  String get billingHeroTitle => '取得創作點數';

  @override
  String get billingHeroSubtitle => '點數用於圖片生成';

  @override
  String billingCreditPackTitle(int credits) {
    return '$credits 點數';
  }

  @override
  String get billingCreditPackSubtitle => '一次性點數包';

  @override
  String billingCreditPackSavingsBadge(int percent) {
    return '節省 $percent%';
  }

  @override
  String get billingPurchaseButton => '購買';

  @override
  String billingPurchaseSuccessButton(int credits) {
    return '購買完成（+$credits 點數）';
  }

  @override
  String get billingRestorePurchases => '恢復購買';

  @override
  String get billingRedeemCodeTitle => '兌換碼';

  @override
  String get billingRedeemCodePlaceholder => '輸入兌換碼';

  @override
  String get billingRedeemCodeButton => '兌換';

  @override
  String get commonCancel => '取消';

  @override
  String get commonOK => '好';

  @override
  String get billingProductsUnavailable => '目前沒有可購買的點數包。';

  @override
  String get billingRetry => '重試';

  @override
  String billingGrantedCreditsMessage(int credits) {
    return '+$credits 點數';
  }

  @override
  String get billingLegalNote => '購買由 App Store 處理。繼續即表示你同意使用條款與隱私權政策。';

  @override
  String get toastGenerationNetworkFailed => '網路連線不穩定，請稍後再試。';

  @override
  String get toastOriginalUnavailable => '原始照片已遺失或無法讀取，請檢查相簿權限後重試。';

  @override
  String get toastInsufficientCredits => '點數不足。';

  @override
  String get toastGenerationSubmitFailed => '照片請求失敗，請重試。';

  @override
  String get toastGenerationUploadFailed => '照片請求失敗，請重試。';

  @override
  String get toastGenerationTaskCreateFailed => '照片請求失敗，請重試。';

  @override
  String get toastGenerationBackendFailed => '照片請求失敗，請重試。';

  @override
  String get toastResultSaveFailed => '結果圖片儲存失敗，請檢查相簿權限後重試。';

  @override
  String get toastGalleryICloudImportFailed => '無法從 iCloud 下載此照片，請稍後再試。';

  @override
  String get toastGalleryImportFailed => '無法匯入此照片，請試試其他照片。';

  @override
  String get toastFavoriteFailed => '無法儲存至「喜愛」，請稍後再試。';

  @override
  String get toastOriginalSaved => '原始照片已儲存至「照片」。';

  @override
  String get toastOriginalSaveFailed => '原始照片無法儲存，請檢查「照片」權限後重試。';

  @override
  String get toastFeedbackSubmitted => '回饋已送出。';

  @override
  String get toastFeedbackFailed => '回饋無法送出，請稍後再試。';

  @override
  String get toastOpenPhotoLibraryFailed => '無法開啟「照片」。';

  @override
  String get toastOpenExternalLinkFailed => '無法開啟連結，請稍後再試。';

  @override
  String get settingsClearOriginalCachePartialTitle => '部分清除失敗';

  @override
  String toastPurchaseSuccess(int credits) {
    return '購買完成，已新增 $credits 點數。';
  }

  @override
  String get toastPurchaseFailed => '購買未完成，請稍後再試。';

  @override
  String toastRestorePurchaseSuccess(int credits) {
    return '恢復購買完成，已新增 $credits 點數。';
  }

  @override
  String get toastRestorePurchaseSynced => '購買記錄已同步。';

  @override
  String get toastRestorePurchaseFailed => '無法恢復購買，請稍後再試。';

  @override
  String toastCreditRedemptionSuccess(int credits) {
    return '已兌換 $credits 點數。';
  }

  @override
  String get toastCreditRedemptionInvalid => '兌換碼格式無效。';

  @override
  String get toastCreditRedemptionUnavailable => '此兌換碼無效或已被使用。';

  @override
  String get toastCreditRedemptionCampaignLimitReached => '此優惠每個帳號只能兌換一次。';

  @override
  String get toastCreditRedemptionRateLimited => '嘗試次數過多，請稍後再試。';

  @override
  String get toastCreditRedemptionFailed => '兌換失敗，請稍後再試。';
}
