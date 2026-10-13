import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[3]
OUT_DIR = ROOT / "game/assets/design/enemies"
REVIEW = Path(__file__).with_name("enemy_roles_pixel_v2_review.png")
FONT = ROOT / "game/assets/design/fonts/MPLUS1Code-Variable.ttf"

CANVAS = (128, 96)
ROLES = ("straight", "wave", "charge")
TARGET_BODY = {
    "straight": (108, 60),
    "wave": (108, 76),
    "charge": (108, 76),
}
DISPLAY_SCALE = {"straight": 0.85, "wave": 0.65, "charge": 0.65}
LABELS = {
    "straight": "STRAIGHT / 単砲",
    "wave": "WAVE / 5連扇砲",
    "charge": "CHARGE / 大口径砲",
}


def alpha_bbox(image: Image.Image, threshold: int = 128) -> tuple[int, int, int, int]:
    solid = image.getchannel("A").point(lambda value: 255 if value >= threshold else 0)
    bbox = solid.getbbox()
    if bbox is None:
        raise ValueError("Image has no visible pixels")
    return bbox


def fit_size(size: tuple[int, int], bounds: tuple[int, int]) -> tuple[int, int]:
    scale = min(bounds[0] / size[0], bounds[1] / size[1])
    width = max(2, round(size[0] * scale))
    height = max(2, round(size[1] * scale))
    # The final asset uses a 2x nearest-neighbour enlargement. Keep both axes even.
    return width - width % 2, height - height % 2


def prepare(source: Path, role: str) -> Image.Image:
    image = Image.open(source).convert("RGBA")
    bbox = alpha_bbox(image, 8)
    cropped = image.crop(bbox)
    body_size = fit_size(cropped.size, TARGET_BODY[role])
    working_size = (body_size[0] // 2, body_size[1] // 2)

    # The generated source was prompted as true low-resolution pixel art. This pass
    # only resolves it onto the game's 64x48 working grid, limits the palette, and
    # makes alpha binary; it does not add detail or synthesize a pixel texture.
    working = cropped.resize(working_size, Image.Resampling.BOX)
    alpha = working.getchannel("A").point(lambda value: 255 if value >= 96 else 0)
    rgb = Image.new("RGB", working_size, (5, 10, 14))
    rgb.paste(working.convert("RGB"), mask=alpha)
    indexed = rgb.quantize(
        colors=28,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    ).convert("RGBA")
    indexed.putalpha(alpha)
    sprite = indexed.resize(body_size, Image.Resampling.NEAREST)

    canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    position = ((CANVAS[0] - sprite.width) // 2, (CANVAS[1] - sprite.height) // 2)
    canvas.alpha_composite(sprite, position)
    return canvas


def visible_colors(image: Image.Image) -> int:
    colors = image.getcolors(maxcolors=image.width * image.height) or []
    return len([entry for entry in colors if entry[1][3]])


def scaled_sprite(image: Image.Image, scale: float) -> Image.Image:
    size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    return image.resize(size, Image.Resampling.NEAREST)


def place_center(canvas: Image.Image, image: Image.Image, center: tuple[int, int]) -> None:
    canvas.alpha_composite(image, (center[0] - image.width // 2, center[1] - image.height // 2))


def make_review(v2: dict[str, Image.Image]) -> None:
    width, height = 1200, 900
    review = Image.new("RGBA", (width, height), (6, 13, 21, 255))
    draw = ImageDraw.Draw(review)
    title = ImageFont.truetype(str(FONT), 26)
    heading = ImageFont.truetype(str(FONT), 18)
    body = ImageFont.truetype(str(FONT), 14)
    tiny = ImageFont.truetype(str(FONT), 12)

    draw.text((24, 18), "敵3役 PIXEL V2 — 既存世界・実表示比較", font=title, fill=(255, 221, 116, 255))
    draw.text(
        (24, 55),
        "生成段階から低解像度ドット絵 / 最終128×96 RGBA / 2×2px描画単位 / 28色上限",
        font=body,
        fill=(159, 205, 222, 255),
    )

    # Existing world references. Player and drone are shown at their in-game Sprite scales.
    draw.rounded_rectangle((20, 88, 1180, 260), radius=6, fill=(11, 27, 40, 255), outline=(39, 103, 127, 255))
    draw.text((36, 100), "WORLD REFERENCE", font=heading, fill=(111, 236, 255, 255))
    refs = [
        ("PLAYER @1.5", ROOT / "game/assets/player/spaceship_small_blue.png", 1.5, (145, 182)),
        ("STAGE1 DRONE @0.65", ROOT / "game/assets/boss/stage1/stage1_enemy_drone.png", 0.65, (410, 182)),
    ]
    for label, path, scale, center in refs:
        image = Image.open(path).convert("RGBA")
        image = scaled_sprite(image, scale)
        place_center(review, image, center)
        draw.text((center[0] - 100, 232), label, font=body, fill=(211, 220, 226, 255))

    boss = Image.open(ROOT / "game/assets/boss/stage1/stage1_boss_main.png").convert("RGBA")
    crop_w, crop_h = 128, 96
    boss_crop = boss.crop(
        (
            (boss.width - crop_w) // 2,
            (boss.height - crop_h) // 2,
            (boss.width + crop_w) // 2,
            (boss.height + crop_h) // 2,
        )
    )
    boss_crop = boss_crop.resize((256, 192), Image.Resampling.NEAREST)
    review.alpha_composite(boss_crop, (610, 68))
    draw.text((884, 142), "STAGE1 BOSS", font=heading, fill=(255, 220, 116, 255))
    draw.text((884, 174), "中央128×96pxを2倍表示", font=body, fill=(211, 220, 226, 255))
    draw.text((884, 200), "材質・画素密度の局所参照", font=body, fill=(159, 205, 222, 255))

    draw.text((24, 282), "ACTUAL DISPLAY SIZE — 旧候補 / PIXEL V2", font=heading, fill=(111, 236, 255, 255))
    old_dir = ROOT / "game/assets/design/enemies"
    for index, role in enumerate(ROLES):
        left = 20 + index * 393
        draw.rounded_rectangle((left, 316, left + 373, 500), radius=6, fill=(11, 27, 40, 255), outline=(39, 103, 127, 255))
        draw.text((left + 14, 328), LABELS[role], font=heading, fill=(255, 221, 116, 255))
        scale = DISPLAY_SCALE[role]
        old_path = old_dir / f"enemy_{role}_candidate.png"
        old = scaled_sprite(Image.open(old_path).convert("RGBA"), scale)
        new = scaled_sprite(v2[role], scale)
        place_center(review, old, (left + 100, 414))
        place_center(review, new, (left + 275, 414))
        draw.text((left + 54, 466), f"V1 @{scale:.2f}", font=body, fill=(166, 177, 185, 255))
        draw.text((left + 225, 466), f"V2 @{scale:.2f}", font=body, fill=(111, 236, 255, 255))

    draw.text((24, 522), "PIXEL V2 — 4倍Nearest表示と実寸輪郭", font=heading, fill=(111, 236, 255, 255))
    for index, role in enumerate(ROLES):
        left = 20 + index * 393
        draw.rounded_rectangle((left, 556, left + 373, 874), radius=6, fill=(11, 27, 40, 255), outline=(39, 103, 127, 255))
        enlarged = v2[role].resize((256, 192), Image.Resampling.NEAREST)
        review.alpha_composite(enlarged, (left + 58, 576))

        alpha = v2[role].getchannel("A")
        silhouette = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
        silhouette.paste((235, 241, 244, 255), (0, 0, *CANVAS), alpha)
        review.alpha_composite(silhouette, (left + 123, 760))
        bbox = alpha_bbox(v2[role])
        footprint = (bbox[2] - bbox[0], bbox[3] - bbox[1])
        draw.text(
            (left + 14, 844),
            f"{footprint[0]}×{footprint[1]}px / {visible_colors(v2[role])}色 / center(64,48)",
            font=tiny,
            fill=(159, 205, 222, 255),
        )

    REVIEW.parent.mkdir(parents=True, exist_ok=True)
    review.save(REVIEW, optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    for role in ROLES:
        parser.add_argument(f"--{role}", required=True, type=Path)
    args = parser.parse_args()

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    images: dict[str, Image.Image] = {}
    for role in ROLES:
        image = prepare(getattr(args, role), role)
        output = OUT_DIR / f"enemy_{role}_pixel_v2.png"
        image.save(output, optimize=True)
        images[role] = image
        bbox = alpha_bbox(image)
        print(f"{output}\t{image.size}\tbbox={bbox}\tcolors={visible_colors(image)}")

    make_review(images)
    print(REVIEW)


if __name__ == "__main__":
    main()
