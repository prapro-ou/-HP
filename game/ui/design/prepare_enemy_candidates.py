import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[3]
OUT_DIR = ROOT / "game/assets/design/enemies"
PREVIEW = Path(__file__).with_name("enemy_roles_preview.png")
FONT = ROOT / "game/assets/design/fonts/MPLUS1Code-Variable.ttf"

CANVAS = (128, 96)
MAX_BODY = (108, 76)
ROLES = ("straight", "wave", "charge")
LABELS = {
    "straight": "STRAIGHT / 射撃機",
    "wave": "WAVE / 掃射機",
    "charge": "CHARGE / 溜め撃ち機",
}


def prepare(source: Path, output: Path) -> Image.Image:
    image = Image.open(source).convert("RGBA")
    alpha = image.getchannel("A")
    solid = alpha.point(lambda value: 255 if value >= 8 else 0)
    bbox = solid.getbbox()
    if bbox is None:
        raise ValueError(f"No visible pixels in {source}")

    pad = 24
    left = max(0, bbox[0] - pad)
    top = max(0, bbox[1] - pad)
    right = min(image.width, bbox[2] + pad)
    bottom = min(image.height, bbox[3] + pad)
    cropped = image.crop((left, top, right, bottom))

    scale = min(MAX_BODY[0] / cropped.width, MAX_BODY[1] / cropped.height)
    resized_size = (
        max(1, round(cropped.width * scale)),
        max(1, round(cropped.height * scale)),
    )
    # Preserve the project's dot-art presentation: resolve detail on a half-size
    # grid, then enlarge with nearest-neighbor so each source pixel becomes a
    # crisp 2x2 block on the final 128x96 texture.
    dot_size = (
        max(1, resized_size[0] // 2),
        max(1, resized_size[1] // 2),
    )
    dotted = cropped.resize(dot_size, Image.Resampling.LANCZOS)
    dotted = dotted.filter(ImageFilter.UnsharpMask(radius=1.0, percent=190, threshold=2))
    dotted = dotted.quantize(colors=64, method=Image.Quantize.FASTOCTREE).convert("RGBA")
    resized = dotted.resize((dot_size[0] * 2, dot_size[1] * 2), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    position = (
        (CANVAS[0] - resized.width) // 2,
        (CANVAS[1] - resized.height) // 2,
    )
    canvas.alpha_composite(resized, position)
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output, optimize=True)
    return canvas


def make_preview(images: dict[str, Image.Image]) -> None:
    width, height = 816, 420
    preview = Image.new("RGBA", (width, height), (6, 14, 23, 255))
    draw = ImageDraw.Draw(preview)
    title_font = ImageFont.truetype(str(FONT), 22)
    label_font = ImageFont.truetype(str(FONT), 17)
    note_font = ImageFont.truetype(str(FONT), 14)
    draw.text((18, 12), "敵3役 外形・砲口比較", font=title_font, fill=(255, 220, 116, 255))
    draw.text((18, 43), "右向き / 128×96透明キャンバス / 中心(64,48)", font=note_font, fill=(155, 195, 215, 255))

    for index, role in enumerate(ROLES):
        x = 12 + index * 268
        draw.rounded_rectangle((x, 72, x + 256, 400), radius=6, fill=(12, 29, 43, 255), outline=(42, 118, 146, 255), width=1)
        draw.text((x + 12, 82), LABELS[role], font=label_font, fill=(110, 236, 255, 255))
        enlarged = images[role].resize((256, 192), Image.Resampling.NEAREST)
        preview.alpha_composite(enlarged, (x, 116))

        alpha = images[role].getchannel("A")
        silhouette = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
        silhouette.paste((238, 244, 247, 255), (0, 0, *CANVAS), alpha)
        preview.alpha_composite(silhouette, (x + 64, 300))
        draw.text((x + 12, 382), "上: 2x / 下: 実寸輪郭", font=note_font, fill=(165, 176, 186, 255))

    PREVIEW.parent.mkdir(parents=True, exist_ok=True)
    preview.save(PREVIEW, optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    for role in ROLES:
        parser.add_argument(f"--{role}", required=True, type=Path)
    args = parser.parse_args()

    images: dict[str, Image.Image] = {}
    for role in ROLES:
        source = getattr(args, role)
        output = OUT_DIR / f"enemy_{role}_candidate.png"
        images[role] = prepare(source, output)
        print(output)
    make_preview(images)
    print(PREVIEW)


if __name__ == "__main__":
    main()
