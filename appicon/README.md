# App icons

`icon.png` is the only artwork. Every platform icon below is a resize of it, so
changing the logo means replacing `icon.png` and re-running the generator.

```bash
python appicon/generate_icons.py
```

It needs Pillow (`pip install Pillow`) and writes, from the repository root:

| Platform | Files | Sizes |
| --- | --- | --- |
| Windows | `windows/runner/resources/app_icon.ico`, `assets/images/icon.ico` | 16–256 px: one entry per size Windows asks for at 100–175% scaling, small ones sharpened |
| Linux | `assets/images/icon.png` (packaging icon and in-app logo) | 1024 px |
| macOS | `macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{n}.png` | 16, 32, 64, 128, 256, 512, 1024 px |
| Android | `res/mipmap-<density>/ic_launcher.webp`, `ic_launcher_round.webp` | 48–192 px |
| Android 8+ | `res/mipmap-<density>/ic_launcher_foreground.webp`, `ic_launcher_monochrome.webp` | 108–432 px, art inside the 72 dp safe zone |
| Android TV | `res/mipmap-television-<density>/ic_launcher.webp`, `ic_launcher_foreground_tv.webp` | 80–320 px, and 108–432 px for the adaptive foreground |
| Tray (Linux, Windows) | `assets/images/tray/unix/status_{1,2,3}.png` at `1x`–`4x`, `assets/images/tray/windows/status_{1,2,3}.ico` | 18–72 px, and 16–64 px for the ICO |
| Tray (macOS) | `assets/images/tray/macos/status_1.png` | 18–72 px, a black template |
| Android TV banner | `res/mipmap-xhdpi/ic_banner.png` | 320×180, the logo beside `banner-title.png` |
| Play Store | `android/app/src/main/ic_launcher-playstore.png` | 512×512, opaque on `#FAFAFA` |

`banner-title.png` is the app name as artwork, extracted from the banner this
replaced so the generator needs no font.

The three tray states keep the old set's encoding: `status_1` greys the logo out
with a grey ring while the app is idle, `status_2` shows it in color once it
runs, and `status_3` adds the amber ring while TUN is on. Safe mode's bug
(`status_4`) is a separate drawing and stays in
`assets_source/images/icon/status_4.svg`, rendered by
`tool/generate_status_icons.dart`.

Every icon keeps a transparent background, as the set it replaced did; Android
supplies its own `#FAFAFA` plate through `values/ic_launcher_background.xml`.
