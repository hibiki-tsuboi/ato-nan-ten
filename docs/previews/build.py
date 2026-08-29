#!/usr/bin/env python3
"""App Store 提出用プレビュー画像の組み立てページを書き出す。

source/*.dc.html（Claude Design のアートボード）を読み、埋め込み用の圧縮画像を
docs/screenshots/ のフル解像度 PNG に差し替えた renders.html を作る。
あとはブラウザで 1320 × 2868 の要素ごとにスクリーンショットを撮れば提出用の画像になる。

    python3 docs/previews/build.py
    (cd docs/previews && python3 -m http.server 8731)
    # renders.html の #s1〜#s8 を等倍（1x）で要素キャプチャする
"""
import io
import os

HERE = os.path.dirname(os.path.abspath(__file__))
BOARDS = [
    ("Main", "01-home"),
    ("Achievement", "02-achievement"),
    ("Approval", "03-approval"),
    ("Tasks", "04-tasks"),
    ("Timer", "05-timer"),
    ("Siblings", "06-siblings"),
    ("History", "07-history"),
    ("ParentMode", "08-parent"),
]

sections = []
for index, (name, slug) in enumerate(BOARDS, start=1):
    source = io.open(os.path.join(HERE, "source", name + ".dc.html"), encoding="utf-8").read()
    body = source.split("</helmet>")[1].split("</x-dc>")[0].strip()
    body = body.replace('src="%s.jpg"' % slug, 'src="../screenshots/%s.png"' % slug)
    if "../screenshots/%s.png" % slug not in body:
        raise SystemExit("画像の差し替えに失敗しました: " + slug)
    sections.append('<section id="s%d">%s</section>' % (index, body))

page = """<!doctype html>
<html>
<head>
<meta charset="utf-8">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=M+PLUS+Rounded+1c:wght@700;800&display=swap">
<style>
  html, body { margin: 0; padding: 0; background: #fff; }
  section { display: block; width: 1320px; height: 2868px; overflow: hidden; }
</style>
</head>
<body>
%s
</body>
</html>
""" % "\n".join(sections)

io.open(os.path.join(HERE, "renders.html"), "w", encoding="utf-8").write(page)
print("wrote renders.html (%d sections)" % len(sections))
