# App Store 用スクリーンショット

iPhone 17 Pro Max（6.9インチ / 1320 × 2868 px）で撮影したもの。App Store Connect の
「iPhone 6.9インチディスプレイ」の枠にそのまま入る。このアプリは iPhone 専用
（`TARGETED_DEVICE_FAMILY = 1`）なので、iPad 用の画像は不要。

| ファイル | 画面 | 見せたいこと |
| --- | --- | --- |
| `01-home.png` | 子ども画面 | 「あと2てん！」と星、ごほうび、行動カード |
| `02-achievement.png` | 達成のお祝い | 目標に届いたときの演出 |
| `03-approval.png` | 承認待ち（親モード） | 押すのは子ども、決めるのは親 |
| `04-tasks.png` | 行動の設定（親モード） | 曜日・回数・表示の切り替え |
| `05-timer.png` | ごほうびタイマー | 「30ぷん」を自動で計る |
| `06-siblings.png` | きょうだい切り替え | 何人でも登録できる |
| `07-history.png` | 履歴（親モード） | 1週間の達成と獲得ポイント |
| `08-parent.png` | 親モードのホーム | 設定項目の一覧 |

掲載順は App Store Connect 側で自由に並べ替えられる。全部を使う必要はなく、
1〜5枚目までが一覧で目に入りやすい。

## 撮り直しかた

サンプルデータは DEBUG ビルドだけに入っている `AtoNanTen/Debug/DemoScreenshots.swift`
が用意する。起動引数 `-demoScene <名前>` を渡したときだけ、メモリ内のサンプルデータで
その画面を最初から表示する（端末に保存された本物のデータには触れない）。

```bash
DEV=$(xcrun simctl list devices available | grep "iPhone 17 Pro Max" | tail -1 | sed -E 's/.*\(([-0-9A-F]+)\).*/\1/')
xcrun simctl boot "$DEV"

xcodebuild -project AtoNanTen.xcodeproj -scheme AtoNanTen -configuration Debug \
  -destination "platform=iOS Simulator,id=$DEV" -derivedDataPath /tmp/dd \
  build CODE_SIGNING_ALLOWED=NO
xcrun simctl install "$DEV" /tmp/dd/Build/Products/Debug-iphonesimulator/AtoNanTen.app

# 時刻と電波・バッテリーをきれいな状態に固定する
xcrun simctl status_bar "$DEV" override --time "9:41" --batteryState charged \
  --batteryLevel 100 --cellularMode active --cellularBars 4 --dataNetwork wifi \
  --wifiMode active --wifiBars 3

for entry in 01-home:home 02-achievement:achievement 03-approval:approval \
             04-tasks:tasks 05-timer:timer 06-siblings:siblings \
             07-history:history 08-parent:parent; do
  xcrun simctl terminate "$DEV" jp.hibiki.gohobiplus 2>/dev/null
  xcrun simctl launch "$DEV" jp.hibiki.gohobiplus -demoScene "${entry##*:}"
  sleep 4   # お祝い画面だけは紙吹雪が落ちきる前（1.6秒ほど）に撮る
  xcrun simctl io "$DEV" screenshot --type png "docs/screenshots/${entry%%:*}.png"
done
```

サンプルデータの中身（子どもの名前、行動、ごほうび）は `DemoScreenshots.swift` の
`DemoData` にまとめてある。実在する商品名や塾名は使わない。
