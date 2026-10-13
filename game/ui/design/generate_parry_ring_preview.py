from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).with_name("parry_double_ring_preview.png")
PLAYER = ROOT / "game/assets/player/spaceship_small_blue.png"
MPLUS = ROOT / "game/assets/design/fonts/MPLUS1Code-Variable.ttf"
DOT = ROOT / "game/assets/fonts/DotGothic16-Regular.ttf"

BASE = (408, 230)
SCALE = 2
BG = (5, 13, 23, 255)
PANEL = (10, 28, 43, 255)
CYAN = (43, 216, 241, 220)
PALE = (177, 248, 255, 245)
GOLD = (255, 220, 112, 255)
MUTED = (124, 160, 178, 255)


def dashed_ring(draw: ImageDraw.ImageDraw, center: tuple[int, int], radius: int, color: tuple[int, int, int, int], width: int, step: int = 30, arc: int = 18) -> None:
    box = (center[0] - radius, center[1] - radius, center[0] + radius, center[1] + radius)
    for start in range(0, 360, step):
        draw.arc(box, start=start, end=start + arc, fill=color, width=width)


def tick_ring(draw: ImageDraw.ImageDraw, center: tuple[int, int], radius: int, color: tuple[int, int, int, int]) -> None:
    for dx, dy in ((0, -radius), (radius, 0), (0, radius), (-radius, 0)):
        x, y = center[0] + dx, center[1] + dy
        draw.rectangle((x - 2, y - 2, x + 2, y + 2), fill=color)


canvas = Image.new("RGBA", BASE, BG)
draw = ImageDraw.Draw(canvas)
heading = ImageFont.truetype(str(DOT), 13)
label = ImageFont.truetype(str(MPLUS), 9)
status = ImageFont.truetype(str(DOT), 12)

draw.text((8, 6), "通常 / 精密パリィ  二重リング", font=heading, fill=GOLD)
draw.text((8, 23), "同じ入力。内周は最終半径の2/3。中央視界を覆わない。", font=label, fill=MUTED)

centers = ((102, 126), (306, 126))
titles = ("待機・通常捕獲", "精密成功 0.35秒")
ship = Image.open(PLAYER).convert("RGBA").resize((34, 34), Image.Resampling.NEAREST)

for index, center in enumerate(centers):
    left = 5 + index * 204
    draw.rounded_rectangle((left, 42, left + 194, 218), radius=4, fill=PANEL, outline=(39, 112, 143, 255), width=1)
    draw.text((left + 8, 49), titles[index], font=label, fill=PALE)
    dashed_ring(draw, center, 62, CYAN, 2, step=24, arc=15)
    dashed_ring(draw, center, 41, PALE if index == 0 else GOLD, 2, step=30, arc=17)
    tick_ring(draw, center, 62, CYAN)
    tick_ring(draw, center, 41, PALE if index == 0 else GOLD)
    canvas.alpha_composite(ship, (center[0] - 17, center[1] - 17))

draw.text((41, 196), "外周: 通常", font=label, fill=CYAN)
draw.text((123, 196), "内周: 精密", font=label, fill=PALE)

# Precision success: one short label and compact rays; no red and no opaque flash.
for x1, y1, x2, y2 in ((306, 73, 306, 82), (306, 170, 306, 179), (253, 126, 262, 126), (350, 126, 359, 126)):
    draw.line((x1, y1, x2, y2), fill=GOLD, width=2)
draw.text((272, 184), "精密捕獲!", font=status, fill=GOLD, stroke_width=1, stroke_fill=(0, 4, 8, 255))

output = canvas.resize((BASE[0] * SCALE, BASE[1] * SCALE), Image.Resampling.NEAREST)
OUT.parent.mkdir(parents=True, exist_ok=True)
output.save(OUT, optimize=True)
print(OUT)
