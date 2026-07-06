# Release dart-define 配置清单

本文记录 TesserCam iOS Release / TestFlight / App Store 构建必须注入的
`--dart-define`。这些值集中由 `lib/config/app_config.dart` 读取。

## 必填项

| Key | 用途 | 备注 |
| --- | --- | --- |
| `SUPABASE_URL` | Supabase 项目 URL | 必须是 `https://...supabase.co` |
| `SUPABASE_PUBLISHABLE_KEY` | Supabase 客户端 publishable key | 不能使用 service role / secret key |
| `GOOGLE_IOS_CLIENT_ID` | Google Sign-In iOS OAuth client ID | 以 `.apps.googleusercontent.com` 结尾 |
| `GOOGLE_WEB_CLIENT_ID` | Google Sign-In web OAuth client ID | Supabase 校验 ID token 需要 |
| `WORKER_API_BASE_URL` | Cloudflare Worker API base URL | 例如 `https://fantasy-camera-worker.liufeiyu135.workers.dev` |
| `REVENUECAT_IOS_PUBLIC_SDK_KEY` | RevenueCat iOS public SDK key | 不能使用 secret API key |
| `REVENUECAT_OFFERING_ID` | RevenueCat offering id | 当前为 `credits` |
| `PUSH_NOTIFICATION_TOPIC` | APNs topic | 必须与 iOS Bundle ID 和 Worker `APNS_ALLOWED_TOPICS` 对齐 |

## 本地 release env 文件

复制样例文件：

```bash
cp config/release.env.example config/release.env
```

填入生产值后先运行离线 smoke：

```bash
dart run tool/verify_release_dart_defines.dart --env-file config/release.env
```

如果需要生成完整 `--dart-define` 参数：

```bash
dart run tool/verify_release_dart_defines.dart \
  --env-file config/release.env \
  --emit-dart-defines
```

`config/release.env` 已被 `.gitignore` 忽略，不应提交。`config/release.env.example`
只保留占位值和非敏感示例。

## Archive 前检查

1. `dart run tool/verify_release_dart_defines.dart --env-file config/release.env`
2. 用同一份 `config/release.env` 生成 Archive 使用的 `--dart-define` 参数。
3. TestFlight 包启动后确认：
   - 可以登录 Supabase。
   - 相机页积分能刷新。
   - 购买页能拉到 RevenueCat offering `credits`。
   - Worker API 可以访问 `/v1/credits/balance`、`/v1/billing/products`。
   - 推送 topic 与 `host.eunoia.tessercam` 对齐。

## 失败处理

- 缺少任意必填项：不要出包。
- `SUPABASE_PUBLISHABLE_KEY` 看起来像 service role / secret：不要出包。
- `REVENUECAT_IOS_PUBLIC_SDK_KEY` 看起来像 secret API key：不要出包。
- `WORKER_API_BASE_URL` 不是 HTTPS：不要出包。
