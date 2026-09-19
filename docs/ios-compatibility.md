# iOSの互換性確認

## 対応方針

最低対応OSは **iOS 26.0**。これは下限であり、iOS 27で動かすために27.0へ変更する必要はない。Xcode 27 / iOS 27 SDKでビルドし、iOS 26と27の両方で検証する。

「現在配布しているアプリを新しいOSで動かす確認」と「新しいSDKで再ビルドしたアプリの確認」は別に行う。SDKの更新によってもシステムUIやAPIの挙動が変わるため、ビルド成功だけで対応完了とは判断しない。

## iOS 27検証で加えた対策

新規のiOS 27シミュレーターで、承認時の通知取り消しがOSの同期IPC応答待ちとなり、メインスレッド上のポイント保存まで進まないケースを確認した。`NotificationService` は通知の予約・取り消しを専用の直列キューで処理し、許可確認もメインスレッドから分離する。`BackupRestoreController` も通知の再設定を復元完了の条件にしない。

この対策はOSの通知サービスを復旧させるものではなく、通知サービスが遅れたときもアプリのデータ保存と操作を継続できるようにするもの。通知の実際の配信は実機でも確認する。

## 確認済みの環境（2026-09-19）

Xcode 27.0（27A266a）で、通知処理の対策後に以下を実行した。

| 環境 | 結果 |
| --- | --- |
| iOS 27.0（24A434）/ iPhone 18 Proシミュレーター | ロジック34件・UI操作4件、全38件成功 |
| iOS 26.0（23A343）/ iPhone 17 Proシミュレーター | ロジック34件・UI操作4件、全38件成功 |
| iOS 27 SDK / 実機向けRelease構成 | 署名なしビルド成功 |

実機のFace ID・通知配信・AirDrop、およびApp Storeで現在配布中のバイナリは、この検証には含まない。

## 自動テスト

共有スキーム `AtoNanTen` にロジックテストとUIテストを登録している。XcodeでOSのバージョンを確認して実行先を選択し、Command-Uで実行できる。

```bash
# iOS 27
xcodebuild test -project AtoNanTen.xcodeproj -scheme AtoNanTen \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0' \
  -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO

# 最低対応OSへの回帰確認
xcodebuild test -project AtoNanTen.xcodeproj -scheme AtoNanTen \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0' \
  -parallel-testing-enabled NO -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO
```

シミュレーター名が異なる場合は `xcrun simctl list devices available` で確認し、`name` と `OS`、または `id` を指定する。`-collect-test-diagnostics never` はシミュレーター全体の診断収集を省略する指定で、テスト結果やUIテストのスクリーンショットは `.xcresult` に残る。

他のアプリのUIテストと同じシミュレーターを同時に操作しない。複数プロジェクトを並行して検証するときは、Device Hubで専用のシミュレーターを作成してその `id` を指定する。

| テスト | 確認内容 |
| --- | --- |
| `PointServiceTests` | ポイント、承認、日次リセット、曜日、達成記録、音声リソース |
| `BackupServiceTests` | データ全項目の往復、置換、重複防止、不正ファイル、保存失敗時の保護 |
| `CompatibilityUITests` | 初回設定からホームへの移動、承認とポイント・履歴の更新、ごほうび受取からタイマー終了、設定・初回設定からのファイル選択とキャンセル |

UIテストは `-demoScene` のメモリ内サンプルデータを使う。OSや画面サイズに依存する挙動を実際のタップで検証し、主要画面のスクリーンショットを結果に添付する。

## 配布用ビルド

```bash
xcodebuild -project AtoNanTen.xcodeproj -scheme AtoNanTen \
  -configuration Release -destination 'generic/platform=iOS' \
  build CODE_SIGNING_ALLOWED=NO
```

これは実機向けコードのコンパイル確認。署名・App Store提出・実機での起動確認は含まない。

iOS 27 SDKで必要になるSceneライフサイクルはSwiftUIの `App` / `WindowGroup` を使っており、`UIApplicationSceneManifest` を生成している。起動画面の `UILaunchScreen` も生成している。設定変更時はビルド後の `AtoNanTen.app/Info.plist` でも両方のキーを確認する。

## 実機での最終確認

リリース前にiOS 27のiPhoneへTestFlightなどで配布用ビルドを入れ、次を確認する。

- 既存のアプリを削除せず更新し、子ども・履歴・ポイントが保持される。新規インストールでも初回設定を完了できる。
- 親アイコンの長押し、Face ID、端末パスコード、アプリ内パスコードが使える。
- 承認・却下・ポイント修正・ごほうび受取が反映され、終了・再起動後も記録が残る。
- バックグラウンド移行や画面ロック後もタイマーが正しい。通知の許可・拒否、承認待ち通知、リマインド、効果音と消音を確認する。
- 古いiPhoneでエクスポートし、AirDropまたはiCloud Driveで新しいiPhoneへ渡してインポートする。全員分の履歴と設定を確認する。
- ライト・ダーク、大きな文字設定、キーボード表示時に操作できる。iPadへ配布する場合はiPadOS 27の実機でも確認する。

シミュレーターでは実機のFace ID、通知配信、AirDrop、性能・電池消費まで保証できない。確認前に移行元の記録を削除しない。

## Appleの資料

- [OSバージョンごとのコードと最低対応OS](https://developer.apple.com/documentation/xcode/running-code-on-a-specific-version/)
- [新しいOSで既存アプリを検証する方法](https://developer.apple.com/documentation/xcode/testing-a-beta-os)
- [Releaseビルドの検証](https://developer.apple.com/documentation/xcode/testing-a-release-build)
- [iOS / iPadOS 27リリースノート](https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-27-release-notes)
