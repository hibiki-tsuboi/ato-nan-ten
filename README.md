# あとなんてん？

子ども向けのごほうびポイント管理アプリ（iOS / SwiftUI）。

「宿題」「読書」「お手伝い」などができたらポイントがたまり、目標ポイントに到達するとごほうびを獲得できる。紙で運用していた「5点たまったらごほうび」の仕組みを、子ども自身が使える形にしたもの。

コンセプトは **「あと何点でごほうびかが、ひと目で分かる」** こと。「現在3ポイント」よりも

```
        ⭐️ あと 2てん！ ⭐️

       ⭐️ ⭐️ ⭐️ ☆ ☆

            3 / 5 てん

      🎮 ごほうび
       Switch 30ぷん
```

を大きく見せる。

## 使い方の流れ

1. 子どもが、できた行動の「できた！」を押す
2. 承認待ちになる（ポイントはまだ増えない）
3. 親モードで承認するとポイントが加算される
4. 目標に到達すると達成画面を表示
5. 「ごほうびをもらった」でポイントをリセットし、次のチャレンジへ

承認は親モードの「アプリの設定」から任意にでき、その場合は「できた！」を押した時点でポイントが入る。

## 主な機能

### 子どもモード

- 「あと○てん！」と星 / ゲージによる進捗表示（目標10点以下は星、11点以上はバー）
- 行動カードの「できた！」申請と承認待ち表示（連打防止）
- 1日の実行回数制限（上限に達した行動は押せない。制限なしの行動には「なんかいでも」と表示）
- 目標達成の演出と連続達成日数の表示
- ごほうびタイマー（「30ぷん」などを名前から拾い、リングと数字で残り時間を表示。アプリを閉じても再開できる）
- 効果音と触覚フィードバック

### 親モード

親アイコンを1秒長押し → Face ID / 端末パスコードで入る。生体認証も端末パスコードも使えない場合は、アプリ内の4桁パスコード（初回に登録）にフォールバックする。

- 承認待ちの承認 / 却下
- 行動の追加・編集・削除（名前、絵文字、ポイント、1日の上限、表示 / 非表示、表示する曜日、並び順）
- ごほうびと目標ポイントの設定
- ポイントの手動修正（履歴に記録）
- 子どもの管理（複数人。名前とアイコン）
- 履歴（ポイントと達成の記録）
- アプリの設定（見た目、音、承認、通知、データ削除）

### 1日の扱い

チャレンジは端末のローカル日付ごとに管理するが、切り替えは深夜0時ではなく **朝4時**（`Services/AppDay.swift`）。夜遅くに押した「できた！」を日付が変わったあとでも承認できる。

- ポイントと承認待ちは翌日に引き継がず、自動でリセットされる（起動時・フォアグラウンド復帰時・日付変更時）
- 行動・表示設定・曜日・ごほうび・目標ポイントは翌日以降も引き継ぐ

### 通知（任意）

- 承認待ちの通知：申請から5分たっても承認されていない場合のみ
- 毎日のリマインド：指定した時刻に1回

### 見た目

ライト / ダークの両対応。既定は端末の設定に追従し、親モードからライト / ダークに固定もできる。

## 動作環境

- iOS 26 以降（iPhone）
- Xcode（iOS 26 SDK）
- 外部ライブラリなし。サーバー通信なし（すべて端末内で完結）

## セットアップ

```bash
open AtoNanTen.xcodeproj
```

シミュレータまたは実機を選んで Command-R で起動する。初回起動時はセットアップ画面（ごほうび → 行動 → 完了）が表示される。

### コマンドラインからのビルド

```bash
xcodebuild -project AtoNanTen.xcodeproj -scheme AtoNanTen -configuration Debug \
  -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

### テスト

ユニットテストは Swift Testing（`@Test` / `#expect`）で書かれており、`AtoNanTenTests/PointServiceTests.swift` がポイント加算・承認・日次リセット・曜日・連続達成のロジックを検証する。

```bash
xcodebuild test -project AtoNanTen.xcodeproj -scheme AtoNanTen \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO
```

## 構成

```
AtoNanTen/
├── AtoNanTenApp.swift        アプリのエントリポイント（SwiftData コンテナ）
├── ContentView.swift         セットアップ / 子ども画面の切り替え、子どもの選択
├── Models/                   SwiftData モデル
│   ├── ChildProfile.swift
│   ├── RewardGoal.swift
│   ├── TaskItem.swift
│   ├── CompletionRequest.swift
│   ├── PointHistory.swift
│   ├── RewardRedemption.swift
│   └── DailyAchievement.swift
├── Services/                 View から切り離したロジック
│   ├── PointService.swift            申請・承認・却下・修正・受け取り
│   ├── DailyChallengeService.swift   1日の準備とリセット
│   ├── AppDay.swift                 朝4時始まりの「1日」
│   ├── StreakCalculator.swift       連続達成日数
│   ├── RewardDuration.swift         ごほうび名からの時間推測
│   ├── AppSettings.swift            UserDefaults と外観
│   ├── NotificationService.swift    ローカル通知
│   ├── SoundService.swift           効果音
│   ├── ParentAuthenticationService.swift  Face ID / パスコード
│   └── AchievementDeferralStore.swift
├── Views/
│   ├── Child/                ホーム、行動カード、達成画面、ごほうびタイマー
│   ├── Parent/               親ホーム、承認、行動 / ごほうび / 子ども / アプリ設定、履歴、ポイント修正
│   └── Setup/                初回セットアップ
└── Components/               AppTheme、進捗表示、絵文字ピッカー
```

ロジックは `Services/` に置き、View なしでテストできる状態を保つ。

## ドキュメント

- [reward-points-app-spec.md](reward-points-app-spec.md) — 仕様書（画面構成、データモデル、エッジケース、将来候補）
- [AGENTS.md](AGENTS.md) — コーディング規約とコントリビュート時の指針
- [PRIVACY.md](PRIVACY.md) — プライバシーポリシー（公開ページ: https://hibiki-tsuboi.github.io/ato-nan-ten/privacy/ ）

## 未実装 / 将来候補

家族間のクラウド同期・iCloud、複数ごほうびとポイント交換所、Apple Watch、iPad 最適化、ウィジェット、バッジやレベル、キャラクター育成。
