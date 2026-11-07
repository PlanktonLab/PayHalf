# PayHalf · 台北通「陪辦」

> 不是代填，是陪填。長輩在自己的台北通手機上辦事，家人、里長或 1999 客服遠端一步一步陪著填；
> 個資授權與最後送出，只有長輩本人能按。

這個 repo 是 [Town Pass（台北通開源版）](https://github.com/taipei-doit/TownPass) 的 fork，我們在上面加了：

- **陪辦（遠端協助填寫）**：長輩按「需要別人協助填寫」，信任的人或 1999 客服即時收到通知、接手後逐步帶填；敏感個資逐項授權，送出鍵只在長輩手機上。
- **幫別人辦**：掃 QR Code、輸入協助代碼、加好友（直接顯示台北通帳號），以及可搜尋的可協助項目列表。
- **掃 QR Code 填表單**：承辦人在網頁後台建立表單、印出海報／立牌，長輩用 iPhone 相機掃描即開啟 App 填寫；首頁「活動訊息」也會列出這些表單。
- **承辦工作台（網頁）**：陪辦工作台、表單後台與回覆、稽核紀錄，以及「1 分鐘測試」SOP 頁。
- **多國語系**：App 介面支援繁體中文、English、Tiếng Việt、Bahasa Indonesia、ภาษาไทย、日本語、한국어，方便在台外籍移工與看護使用；語言存在使用者帳號上，可在首頁左上角「切換身分」面板或設定頁切換。

| 位置 | 內容 |
|---|---|
| `lib/page/assist/`、`lib/service/assist_service.dart` | App 端陪辦、表單、幫別人辦 |
| `lib/util/tp_i18n.dart`、`lib/util/i18n/` | 多國語系（以繁中原文當 key，沒翻到的字串顯示中文） |
| `assist/assist_backend/` | Node.js 後端（Express + Socket.IO），`npm test` |
| `assist/assist_web/` | Flutter Web 承辦工作台 |
| `assist/README.md` | 陪辦功能的完整說明、啟動與部署方式 |

App 連線的後端由 `--dart-define=ASSIST_API=https://<你的後端>` 指定，也可以在 App「設定 › 陪辦伺服器」切換。

---

# What is Town Pass?

Town Pass is an open-source project developed by the Taipei City Government. With the growth of smart cities, the demand for digitalization in city management and citizen services continues to rise. As we enter a new digital era, our goal is to involve citizens in the process, combining third-party expertise and innovation to make digital life in Taipei more convenient.

Town Pass is not just an application; it is an open community project. Through open-source, every citizen can participate in the ideation, development, and optimization of the application. This not only enhances citizen engagement and satisfaction but also leverages collective intelligence to continuously improve the application, making it truly serve the people. Furthermore, we hope that various municipalities can widely adopt the open-source framework of Town Pass, integrate it with their existing municipal service systems, and quickly have their own applications to enhance digital governance.

Open source is a key driver of technological progress and social development. Through open-source, Town Pass will become an ever-evolving platform, attracting developers from all backgrounds to contribute. We welcome experts to submit code, report issues, provide suggestions, and even develop new features and creative ideas, working together to perfect Town Pass as we advance toward a smart city.

# Getting Started

We highly recommend to read through our [document](https://tpe-guideline.web.app/en/docs/) for more detail.

Here are some quick setup guide.

## Requirement

- [Flutter](https://docs.flutter.dev/get-started/install) or [FVM](https://fvm.app/documentation/getting-started/installation)
- [XCode](https://developer.apple.com/xcode/) (for iOS)
- [Android SDK](https://developer.android.com/studio/index.html) (for Android, with or without Android Studio)

## Build the Project

1. Get the packages project needed:

   ``` bash
   flutter pub get
   ```

2. Generate additional needed dart code for the project.

   ``` bash
   dart run build_runner build
   ```

3. You are all set now, Run the project from your IDE or the through the command line:

   ``` bash
   flutter run
   ```
