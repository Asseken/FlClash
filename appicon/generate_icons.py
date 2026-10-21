"""Regenerates every platform icon from `appicon/icon.png`.

Run it from the repository root with Pillow available:

    python appicon/generate_icons.py

The master is the only artwork; each platform file below is a resize of it, so
changing the logo means replacing `appicon/icon.png` and re-running this.
"""

from io import BytesIO
from pathlib import Path
import struct

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parent.parent
MASTER = ROOT / 'appicon' / 'icon.png'

# The icons this replaced put the artwork's own bounds across ~84% of the
# canvas, so a replacement keeps the same visual weight beside other apps.
ICON_FILL = 0.84
# Android's adaptive foreground keeps its art inside the 66dp safe circle of
# the 108dp canvas, or a round mask clips the corners.
FOREGROUND_FILL = 0.66

ANDROID_DENSITIES = {
    'mdpi': 1.0,
    'hdpi': 1.5,
    'xhdpi': 2.0,
    'xxhdpi': 3.0,
    'xxxhdpi': 4.0,
}
TV_ICON_DP = 80
ADAPTIVE_DP = 108

# The ladder covers Windows' own icon sizes at 100%, 125%, 150% and 175%
# scaling: a missing entry is one Explorer scales, which reads as blur.
WINDOWS_ICO_SIZES = [16, 20, 24, 28, 32, 40, 48, 56, 60, 64, 72, 84, 96, 128, 256]
# Small entries trade margin for pixels on the mark, then take a light sharpening
# pass: the artwork's ring is sub-pixel at 16 and vanishes unsharpened.
ICO_SMALL_FILL = 0.92
ICO_SHARPEN_MAX = 96
MACOS_SIZES = [16, 32, 64, 128, 256, 512, 1024]

# Android's notification small icon and Quick Settings tile both draw at 24dp;
# the status bar keeps only the mark's alpha, so the tile ships a white copy.
NOTIFICATION_DP = 24

# The tray shows one icon per state: the logo greyed out while the app is idle,
# in color once it runs, and with the amber ring the old set used for TUN.
TRAY_BASE = 18
TRAY_SCALES = [1, 2, 3, 4]
TRAY_ICO_SIZES = [16, 20, 24, 32, 40, 48, 64]
TRAY_IDLE_RING = '#B8C0CD'
TRAY_TUN_RING = '#FFB02E'
TRAY_FILL = 0.8

# The Android TV banner is a 320x180 plate: the logo beside the app name, which
# `banner-title.png` carries as artwork so the generator needs no font.
BANNER_SIZE = (320, 180)
BANNER_BACKGROUND = (245, 245, 245, 255)
BANNER_LOGO_BOX = (96, 96)
BANNER_LOGO_CENTER = (72, 90)
BANNER_TITLE_ORIGIN = (147, 76)
BANNER_TITLE = ROOT / 'appicon' / 'banner-title.png'

# Play rejects transparency, so the store icon is the artwork on the same
# #FAFAFA plate Android uses for the adaptive background.
PLAY_STORE_SIZE = 512
PLAY_STORE_FILL = 0.72
PLAY_STORE_BACKGROUND = (250, 250, 250, 255)


def artwork() -> Image.Image:
    image = Image.open(MASTER).convert('RGBA')
    return image.crop(image.getchannel('A').getbbox())


def compose(size: int, art: Image.Image, fill: float, circle: bool = False) -> Image.Image:
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    scale = size * fill / max(art.size)
    width = max(1, round(art.width * scale))
    height = max(1, round(art.height * scale))
    scaled = art.resize((width, height), Image.LANCZOS)
    canvas.alpha_composite(scaled, ((size - width) // 2, (size - height) // 2))
    if circle:
        mask = Image.new('L', (size, size), 0)
        ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
        canvas.putalpha(ImageChops.multiply(canvas.getchannel('A'), mask))
    return canvas


def silhouette(source: Image.Image, color: tuple[int, int, int] = (255, 255, 255)) -> Image.Image:
    flat = Image.new('RGBA', source.size, (*color, 255))
    flat.putalpha(source.getchannel('A'))
    return flat


def save_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, 'PNG', optimize=True)
    print(path.relative_to(ROOT))


def save_webp(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, 'WEBP', lossless=True, quality=100, method=6)
    print(path.relative_to(ROOT))


def _png_bytes(image: Image.Image) -> bytes:
    buffer = BytesIO()
    image.save(buffer, 'PNG', optimize=True)
    return buffer.getvalue()


def write_ico(frames: list[tuple[int, Image.Image]], path: Path) -> None:
    """Writes one PNG-compressed entry per size, so nothing is resampled twice."""
    header = struct.pack('<HHH', 0, 1, len(frames))
    directory = b''
    payloads = b''
    offset = 6 + 16 * len(frames)
    for size, frame in frames:
        png = _png_bytes(frame)
        directory += struct.pack(
            '<BBBBHHII',
            size % 256,
            size % 256,
            0,
            0,
            1,
            32,
            len(png),
            offset + len(payloads),
        )
        payloads += png
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(header + directory + payloads)
    print(path.relative_to(ROOT))


def icon_frame(art: Image.Image, size: int) -> Image.Image:
    fill = ICON_FILL if size > ICO_SHARPEN_MAX else ICO_SMALL_FILL
    frame = compose(size, art, fill)
    if size <= ICO_SHARPEN_MAX:
        frame = frame.filter(
            ImageFilter.UnsharpMask(
                radius=max(0.5, size / 48),
                percent=150,
                threshold=0,
            )
        )
    return frame


def save_icon_ico(art: Image.Image, path: Path, sizes: list[int]) -> None:
    write_ico([(size, icon_frame(art, size)) for size in sizes], path)


def save_image_ico(image: Image.Image, path: Path, sizes: list[int]) -> None:
    write_ico(
        [(size, image.resize((size, size), Image.LANCZOS)) for size in sizes],
        path,
    )


def grayed(source: Image.Image) -> Image.Image:
    gray = ImageOps.grayscale(source)
    return Image.merge('RGBA', (gray, gray, gray, source.getchannel('A')))


def tray_icon(size: int, art: Image.Image, ring: str | None) -> Image.Image:
    canvas = compose(size, art, TRAY_FILL)
    if ring is None:
        return canvas
    stroke = max(1, round(size * 0.06))
    inset = stroke / 2
    ImageDraw.Draw(canvas).ellipse(
        (inset, inset, size - 1 - inset, size - 1 - inset),
        outline=ring,
        width=stroke,
    )
    return canvas


def tray_variants(art: Image.Image) -> dict[str, Image.Image]:
    return {
        'status_1': grayed(tray_icon(TRAY_BASE * 4, art, TRAY_IDLE_RING)),
        'status_2': tray_icon(TRAY_BASE * 4, art, None),
        'status_3': tray_icon(TRAY_BASE * 4, art, TRAY_TUN_RING),
    }


def banner(art: Image.Image) -> Image.Image:
    canvas = Image.new('RGBA', BANNER_SIZE, BANNER_BACKGROUND)
    scale = min(BANNER_LOGO_BOX[0] / art.width, BANNER_LOGO_BOX[1] / art.height)
    logo = art.resize(
        (max(1, round(art.width * scale)), max(1, round(art.height * scale))),
        Image.LANCZOS,
    )
    canvas.alpha_composite(
        logo,
        (
            BANNER_LOGO_CENTER[0] - logo.width // 2,
            BANNER_LOGO_CENTER[1] - logo.height // 2,
        ),
    )
    title = Image.open(BANNER_TITLE).convert('RGBA')
    canvas.alpha_composite(title, BANNER_TITLE_ORIGIN)
    return canvas


def play_store_icon(art: Image.Image) -> Image.Image:
    canvas = Image.new('RGBA', (PLAY_STORE_SIZE,) * 2, PLAY_STORE_BACKGROUND)
    canvas.alpha_composite(compose(PLAY_STORE_SIZE, art, PLAY_STORE_FILL))
    return canvas


def main() -> None:
    art = artwork()

    # Windows: the runner icon, and the copy the app itself ships.
    save_icon_ico(art, ROOT / 'windows/runner/resources/app_icon.ico', WINDOWS_ICO_SIZES)
    save_icon_ico(art, ROOT / 'assets/images/icon.ico', WINDOWS_ICO_SIZES)

    # Linux packaging and the in-app logo both read this one.
    save_png(compose(1024, art, ICON_FILL), ROOT / 'assets/images/icon.png')

    for size in MACOS_SIZES:
        save_png(
            compose(size, art, ICON_FILL),
            ROOT / f'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{size}.png',
        )

    # Tray: one PNG set per scale on Linux and macOS, one multi-size ICO on
    # Windows; macOS reads a template, so only its alpha survives there.
    tray = tray_variants(art)
    for name, master in tray.items():
        for scale in TRAY_SCALES:
            directory = 'assets/images/tray/unix'
            if scale > 1:
                directory = f'{directory}/{scale}.0x'
            save_png(
                master.resize((TRAY_BASE * scale,) * 2, Image.LANCZOS),
                ROOT / f'{directory}/{name}.png',
            )
    for scale in TRAY_SCALES:
        directory = 'assets/images/tray/macos'
        if scale > 1:
            directory = f'{directory}/{scale}.0x'
        save_png(
            silhouette(tray['status_2'], (0, 0, 0)).resize(
                (TRAY_BASE * scale,) * 2,
                Image.LANCZOS,
            ),
            ROOT / f'{directory}/status_1.png',
        )
    for name in ['status_1', 'status_2', 'status_3']:
        save_image_ico(
            tray[name],
            ROOT / f'assets/images/tray/windows/{name}.ico',
            TRAY_ICO_SIZES,
        )

    # Android TV's launcher banner, 320x180 at xhdpi.
    save_png(
        banner(art),
        ROOT / 'android/app/src/main/res/mipmap-xhdpi/ic_banner.png',
    )

    # The Play Store listing icon.
    save_png(
        play_store_icon(art),
        ROOT / 'android/app/src/main/ic_launcher-playstore.png',
    )

    res = ROOT / 'android/app/src/main/res'
    for density, scale in ANDROID_DENSITIES.items():
        legacy = round(48 * scale)
        save_webp(
            compose(legacy, art, ICON_FILL),
            res / f'mipmap-{density}/ic_launcher.webp',
        )
        save_webp(
            compose(legacy, art, ICON_FILL, circle=True),
            res / f'mipmap-{density}/ic_launcher_round.webp',
        )
        adaptive = round(ADAPTIVE_DP * scale)
        foreground = compose(adaptive, art, FOREGROUND_FILL)
        save_webp(foreground, res / f'mipmap-{density}/ic_launcher_foreground.webp')
        save_webp(silhouette(foreground), res / f'mipmap-{density}/ic_launcher_monochrome.webp')

        television = round(TV_ICON_DP * scale)
        save_webp(
            compose(television, art, ICON_FILL),
            res / f'mipmap-television-{density}/ic_launcher.webp',
        )
        save_webp(
            compose(adaptive, art, FOREGROUND_FILL),
            res / f'mipmap-television-{density}/ic_launcher_foreground_tv.webp',
        )

    # The service's notification icon (`setSmallIcon`, and the document
    # provider's root) and the Quick Settings tile, both at 24dp.
    service = ROOT / 'android/service/src/main/res'
    for density, scale in ANDROID_DENSITIES.items():
        size = round(NOTIFICATION_DP * scale)
        frame = icon_frame(art, size)
        save_png(frame, service / f'drawable-{density}/ic_service.png')
        save_png(silhouette(frame), service / f'drawable-{density}/ic.png')


if __name__ == '__main__':
    main()
