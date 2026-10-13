from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).with_name("font_preview_9x16_60.png")
MPLUS = ROOT / "game/assets/design/fonts/MPLUS1Code-Variable.ttf"
DOT = ROOT / "game/assets/fonts/DotGothic16-Regular.ttf"

WIDTH, HEIGHT = 405, 720  # 675x1200 rendered at 60%.
BG = (7, 14, 24, 255)
PANEL = (13, 29, 44, 235)
CYAN = (102, 232, 255, 255)
GOLD = (255, 213, 92, 255)
WHITE = (239, 246, 250, 255)
MUTED = (150, 170, 184, 255)
OUTLINE = (0, 5, 10, 255)


def font(path: Path, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(path), size=size)


def text(
    draw: ImageDraw.ImageDraw,
    pos: tuple[int, int],
    value: str,
    face: ImageFont.FreeTypeFont,
    fill: tuple[int, int, int, int] = WHITE,
    stroke: int = 1,
) -> None:
    draw.text(pos, value, font=face, fill=fill, stroke_width=stroke, stroke_fill=OUTLINE)


def panel(draw: ImageDraw.ImageDraw, y: int, height: int) -> None:
    draw.rounded_rectangle((12, y, WIDTH - 12, y + height), radius=5, fill=PANEL, outline=(45, 116, 146, 255), width=1)


canvas = Image.new("RGBA", (WIDTH, HEIGHT), BG)
draw = ImageDraw.Draw(canvas)

# A faint combat-like grid keeps contrast testing closer to a busy game screen.
for x in range(0, WIDTH, 27):
    draw.line((x, 0, x, HEIGHT), fill=(15, 34, 46, 120), width=1)
for y in range(0, HEIGHT, 27):
    draw.line((0, y, WIDTH, y), fill=(15, 34, 46, 120), width=1)

dot_heading = font(DOT, 20)
mplus_label = font(MPLUS, 12)
mplus_hud = font(MPLUS, 14)
mplus_body = font(MPLUS, 13)
dot_hud = font(DOT, 14)

text(draw, (14, 12), "COUNTER CORE  字体比較", dot_heading, GOLD, 2)
text(draw, (14, 42), "9:16内部675×1200 → 60%表示 405×720", mplus_label, MUTED)

panel(draw, 70, 288)
text(draw, (24, 80), "第一候補  M PLUS 1 Code", mplus_hud, CYAN, 2)
samples = [
    ("捕獲 12/12　保持中", GOLD),
    ("修復まであと2回", WHITE),
    ("シールド再展開 2.4s", CYAN),
    ("クリア済みボス", WHITE),
    ("0123456789  HP 500/500", WHITE),
    ("COUNTER READY [Left Shift]", GOLD),
]
for index, (sample, color) in enumerate(samples):
    text(draw, (24, 116 + index * 36), sample, mplus_hud, color, 2)

text(draw, (24, 334), "本文例: 敵弾を引きつけ、内側で精密パリィ", mplus_body, WHITE, 1)

panel(draw, 372, 270)
text(draw, (24, 382), "既存見出し  DotGothic16", dot_hud, GOLD, 2)
for index, (sample, color) in enumerate(samples):
    text(draw, (24, 418 + index * 34), sample, dot_hud, color, 2)

text(draw, (14, 665), "推奨: HUD/本文=M PLUS 1 Code  見出し=DotGothic16", mplus_label, WHITE, 1)
text(draw, (14, 692), "暗色パネル＋1～2px縁取り。長いキー名は短縮候補。", mplus_label, MUTED, 1)

OUT.parent.mkdir(parents=True, exist_ok=True)
canvas.save(OUT, optimize=True)
print(OUT)
