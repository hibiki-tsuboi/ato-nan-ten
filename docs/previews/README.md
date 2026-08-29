# App Store 用プレビュー画像

`docs/screenshots/` の素のスクリーンショットに、キャッチコピーと背景を入れた提出用の画像。
1242 × 2688 px（iPhone 6.5インチ）で、App Store Connect にそのまま入る。
アートボードは 1320 幅で設計し、出力時に 0.941 倍で組み直している（`source/` の値は縮小後）。

| ファイル | コピー |
| --- | --- |
| `01-home.png` | 「あと2てん！」が子どものやる気に |
| `02-achievement.png` | たまったら、ごほうびゲット |
| `03-approval.png` | 押すのは子ども、決めるのは親 |
| `04-tasks.png` | 家庭のルールに合わせて設定 |
| `05-timer.png` | 「30ぷん」はアプリが計る |
| `06-siblings.png` | きょうだい何人でもOK |
| `07-history.png` | がんばりは記録に残る |
| `08-parent.png` | 親モードはFace IDでロック |

## デザイン

色はアプリの `AtoNanTen/Components/AppTheme.swift` から取っている。

- 下地: `#FFF7E8` → `#FFEDD6`（達成の1枚だけ `#7A59E0` → `#572EA8`）
- 文字: `#29243B` / マーカー: `#FFC733` / アクセント: `#FF7A33`
- 書体: M PLUS Rounded 1c（無い環境ではヒラギノ丸ゴ ProN）

編集できるキャンバス（Claude Design）:
https://claude.ai/code/artifact/9d333b2c-3210-4a27-a28c-772179d819b8

## 作り直しかた

アートボードの元データは `source/*.dc.html`（キャンバスと同じもの）。文言や配置を変えたい
ときは、キャンバス上で直してから `source/` に取り出すか、`source/` を直接編集する。

```bash
python3 docs/previews/build.py        # renders.html を書き出す
cd docs/previews && python3 -m http.server 8731
```

`http://127.0.0.1:8731/renders.html` を開き、`#s1`〜`#s8` の各 `<section>` を**等倍（1x）**で
要素キャプチャすると 1242 × 2688 の PNG になる。ページ全体ではなく要素ごとに撮ること。
スクリーンショット自体を撮り直す手順は [../screenshots/README.md](../screenshots/README.md)。
