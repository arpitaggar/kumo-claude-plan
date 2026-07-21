#!/usr/bin/env python3
"""
Kumo icon generator.

Usage
  python3 scripts/gen_icons.py              # render PNGs for ALL themes
  python3 scripts/gen_icons.py all          # same
  python3 scripts/gen_icons.py deep_voyage  # render + apply that theme (runs flutter tools)

Output files (always written to assets/icons/)
  app_icon_{theme}.png                   — full icon with gradient background (iOS squircle safe)
  adaptive_icon_foreground_{theme}.png   — logo + gradient background, logo fits Android safe zone

Switching themes
  Run with a theme name.  The script copies the theme PNGs to the canonical names
  (app_icon.png / adaptive_icon_foreground.png), updates ic_launcher_background.xml,
  runs flutter_launcher_icons + flutter_native_splash, and patches ic_launcher.xml.

Safe-zone notes
  • Android adaptive icon — logo must fit the centre 66.7 % circle (radius 342 px on a
    1024 px canvas).  FOREGROUND_FILL = 0.607 puts the airplane tip at ~339 px.
    The inset="16%" that flutter_launcher_icons writes is removed after every run.
  • iOS rounded icon      — iOS squircle clips ~22 % from every corner.  APP_ICON_FILL =
    0.90 keeps every logo corner within the safe radius (squircle_val 0.800 < 1.0).
"""

import shutil, subprocess, math, sys, os, re
import numpy as np
from PIL import Image

# ── Configuration ──────────────────────────────────────────────────────────────

THEMES = {
    "cherry_blossom": {
        "logo_svg":   "assets/icons/kumo_logo_charcoal_depth_soft_faint_edge.svg",
        "bg_start":   (0xFA, 0xF8, 0xF4),
        "bg_end":     (0xDD, 0xD5, 0xC5),
        "grad_start": "#FAF8F4",
        "grad_end":   "#DDD5C5",
        "splash_bg":  "#F5F2EB",   # warmOatmeal
    },
    "golden_hour": {
        "logo_svg":   "assets/icons/kumo_logo_golden_hour.svg",
        "bg_start":   (0xFD, 0xF8, 0xE8),
        "bg_end":     (0xF0, 0xD0, 0x90),
        "grad_start": "#FDF8E8",
        "grad_end":   "#F0D090",
        "splash_bg":  "#FDF8E8",   # goldenIvory
    },
    "deep_voyage": {
        "logo_svg":   "assets/icons/kumo_logo_deep_voyage.svg",
        "bg_start":   (0x16, 0x29, 0x4D),
        "bg_end":     (0x0E, 0x1B, 0x33),
        "grad_start": "#16294D",
        "grad_end":   "#0E1B33",
        "splash_bg":  "#0E1B33",   # voyageNavy
        # Silver strokes injected only into icon PNGs (source SVG unchanged)
        "icon_stroke": {
            "fill_id":    "swanGrad",
            "light":      "#F0F2F4",
            "mid":        "#D4D8DC",
            "dark":       "#A8AEBB",
            "width":      14,
            "fill_light": "#C8D4E0",
            "fill_mid":   "#E0E8F0",
            "fill_dark":  "#8A9BAC",
        },
    },
}

CANVAS          = 1024
SVG_W, SVG_H    = 1024, 832
FOREGROUND_FILL = 0.607   # airplane tip reaches safe-zone radius 341.5 px
APP_ICON_FILL   = 0.90    # full app icon (iOS squircle safe)

ROOT      = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICONS_DIR = os.path.join(ROOT, "assets", "icons")
TMP       = "/tmp/kumo_icon_gen"

# ── Helpers ────────────────────────────────────────────────────────────────────

def svg_to_png(svg_path, w, h, out_path):
    subprocess.run(
        ["rsvg-convert", "-w", str(w), "-h", str(h), "-o", out_path, svg_path],
        check=True,
    )

def diagonal_gradient(c1, c2, size=CANVAS):
    xs = np.linspace(0.0, 1.0, size, dtype=np.float32)
    ys = np.linspace(0.0, 1.0, size, dtype=np.float32)
    xx, yy = np.meshgrid(xs, ys)
    t = ((xx + yy) / 2)[:, :, np.newaxis]
    c1a = np.array(c1, dtype=np.float32)
    c2a = np.array(c2, dtype=np.float32)
    return Image.fromarray((c1a * (1 - t) + c2a * t).clip(0, 255).astype(np.uint8), "RGB")

def radial_gradient(c_center, c_edge, size=CANVAS):
    """Radial gradient: c_center at the image centre, c_edge at the corners.

    Used for the adaptive-icon foreground and the splash background so both
    share the same shading — the icon edge colour equals the flat splash
    background colour, making the icon appear to emerge from the background.
    """
    xs = np.linspace(-1.0, 1.0, size, dtype=np.float32)
    ys = np.linspace(-1.0, 1.0, size, dtype=np.float32)
    xx, yy = np.meshgrid(xs, ys)
    # r = 0 at centre, 1 at corners
    r = (np.sqrt(xx ** 2 + yy ** 2) / np.sqrt(2)).clip(0, 1)[:, :, np.newaxis]
    c1 = np.array(c_center, dtype=np.float32)
    c2 = np.array(c_edge,   dtype=np.float32)
    return Image.fromarray((c1 * (1 - r) + c2 * r).clip(0, 255).astype(np.uint8), "RGB")

def centre_paste(canvas_img, logo_img, logo_w, logo_h):
    x = (CANVAS - logo_w) // 2
    y = (CANVAS - logo_h) // 2
    canvas_img.paste(logo_img, (x, y), logo_img)
    return x, y

def pixel_safe_zone(png_path, safe_r, label):
    img = Image.open(png_path).convert("RGBA")
    a   = np.array(img)
    cx, cy = img.width // 2, img.height // 2
    ys, xs = np.where(a[:, :, 3] > 10)
    if len(xs) == 0:
        print(f"  {label}: no visible pixels!")
        return
    dists   = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2)
    max_d   = dists.max()
    max_idx = dists.argmax()
    mx, my  = xs[max_idx], ys[max_idx]
    status  = "OK" if max_d <= safe_r else f"EXCEEDS by {max_d - safe_r:.1f}px"
    print(f"  {label}: furthest pixel ({mx},{my}) dist={max_d:.1f}  safe={safe_r:.1f}  [{status}]")

def validate_safe_zone(x, y, logo_w, logo_h, label):
    cx, cy = CANVAS // 2, CANVAS // 2
    half = CANVAS / 2
    corners = [(x, y), (x + logo_w, y), (x, y + logo_h), (x + logo_w, y + logo_h)]
    ios_vals = [abs((px - cx) / half) ** 5 + abs((py - cy) / half) ** 5 for px, py in corners]
    status = "OK" if max(ios_vals) < 1.0 else "EXCEEDS iOS SQUIRCLE"
    print(f"  {label}: {logo_w}×{logo_h} @ ({x},{y})  squircle_val={max(ios_vals):.3f}  [{status}]")

# ── Icon SVG variant ──────────────────────────────────────────────────────────

def _icon_svg(svg_path, cfg):
    """Return path to icon-specific SVG variant.

    For themes with 'icon_stroke', injects silver gradients into a temp copy
    so they remain visible on the dark background.  Source SVG is untouched.
    """
    if "icon_stroke" not in cfg:
        return svg_path

    s = cfg["icon_stroke"]
    with open(svg_path) as f:
        svg = f.read()

    silver_defs = (
        f'<linearGradient id="iconSilverGrad" x1="0%" y1="0%" x2="100%" y2="100%">'
        f'<stop offset="0%"   stop-color="{s["light"]}"/>'
        f'<stop offset="40%"  stop-color="#FFFFFF"/>'
        f'<stop offset="70%"  stop-color="{s["mid"]}"/>'
        f'<stop offset="100%" stop-color="{s["dark"]}"/>'
        f'</linearGradient>'
        f'<linearGradient id="iconSilverFill" x1="0%" y1="0%" x2="100%" y2="100%">'
        f'<stop offset="0%"   stop-color="{s["fill_light"]}"/>'
        f'<stop offset="45%"  stop-color="{s["fill_mid"]}"/>'
        f'<stop offset="100%" stop-color="{s["fill_dark"]}"/>'
        f'</linearGradient>'
    )
    svg = svg.replace("</defs>", f"  {silver_defs}\n  </defs>", 1)

    stroke_attr = (
        f' stroke="url(#iconSilverGrad)"'
        f' stroke-width="{s["width"]}"'
        f' stroke-linejoin="round" stroke-linecap="round"'
    )
    svg = svg.replace(
        f'fill="url(#{s["fill_id"]})"',
        f'fill="url(#iconSilverFill)"{stroke_attr}',
    )

    out = os.path.join(TMP, f"icon_variant_{cfg['logo_svg'].split('/')[-1]}")
    with open(out, "w") as f:
        f.write(svg)
    return out

# ── Render PNGs ───────────────────────────────────────────────────────────────

def render_pngs(theme_name):
    """Generate app_icon_{theme}.png and adaptive_icon_foreground_{theme}.png."""
    cfg = THEMES[theme_name]
    svg = os.path.join(ROOT, cfg["logo_svg"])
    os.makedirs(TMP, exist_ok=True)

    print(f"\n── {theme_name} ──")
    icon_svg = _icon_svg(svg, cfg)

    # adaptive_icon_foreground: logo at FOREGROUND_FILL on RADIAL gradient background.
    # Edge colour = bg_end = splash_bg, so the icon blends into the flat splash background.
    fg_w = int(CANVAS * FOREGROUND_FILL)
    fg_h = int(fg_w * SVG_H / SVG_W)
    svg_to_png(icon_svg, fg_w, fg_h, f"{TMP}/fg.png")
    # Check safe zone on the transparent logo before baking the background
    pixel_safe_zone(f"{TMP}/fg.png", CANVAS * 0.3335, "adaptive foreground")
    fg_bg = radial_gradient(cfg["bg_start"], cfg["bg_end"])
    logo_fg = Image.open(f"{TMP}/fg.png").convert("RGBA")
    centre_paste(fg_bg, logo_fg, fg_w, fg_h)
    fg_out = os.path.join(ICONS_DIR, f"adaptive_icon_foreground_{theme_name}.png")
    fg_bg.save(fg_out)

    # app_icon: logo at APP_ICON_FILL on gradient background (larger, for iOS)
    ic_w = int(CANVAS * APP_ICON_FILL)
    ic_h = int(ic_w * SVG_H / SVG_W)
    svg_to_png(icon_svg, ic_w, ic_h, f"{TMP}/icon.png")
    ic_bg = diagonal_gradient(cfg["bg_start"], cfg["bg_end"])
    logo_ic = Image.open(f"{TMP}/icon.png").convert("RGBA")
    ix, iy = centre_paste(ic_bg, logo_ic, ic_w, ic_h)
    ic_out = os.path.join(ICONS_DIR, f"app_icon_{theme_name}.png")
    ic_bg.save(ic_out)
    validate_safe_zone(ix, iy, ic_w, ic_h, "app icon (iOS)")

    print(f"  → adaptive_icon_foreground_{theme_name}.png")
    print(f"  → app_icon_{theme_name}.png")

# ── Apply theme ───────────────────────────────────────────────────────────────

def apply_theme(theme_name):
    """Copy theme PNGs to canonical names and run flutter tools."""
    cfg = THEMES[theme_name]

    fg_src = os.path.join(ICONS_DIR, f"adaptive_icon_foreground_{theme_name}.png")
    ic_src = os.path.join(ICONS_DIR, f"app_icon_{theme_name}.png")
    if not os.path.exists(fg_src) or not os.path.exists(ic_src):
        print(f"ERROR: PNGs for '{theme_name}' not found — run without a theme arg first.")
        sys.exit(1)

    shutil.copy2(fg_src, os.path.join(ICONS_DIR, "adaptive_icon_foreground.png"))
    shutil.copy2(ic_src, os.path.join(ICONS_DIR, "app_icon.png"))
    print(f"\nApplying theme: {theme_name}")
    print("  Copied PNGs to canonical names")

    # Run flutter_launcher_icons
    print("  Running flutter_launcher_icons…")
    subprocess.run(["flutter", "pub", "run", "flutter_launcher_icons"], cwd=ROOT, check=True)

    # Patch ic_launcher.xml — flutter_launcher_icons resets background ref and adds inset
    ic_xml = os.path.join(
        ROOT, "android", "app", "src", "main", "res",
        "mipmap-anydpi-v26", "ic_launcher.xml",
    )
    with open(ic_xml) as f:
        xml = f.read()
    xml = xml.replace('@color/ic_launcher_background', '@drawable/ic_launcher_background')
    xml = re.sub(
        r'<foreground>\s*<inset\b[^>]*/>\s*</foreground>',
        '<foreground android:drawable="@drawable/ic_launcher_foreground"/>',
        xml, flags=re.DOTALL,
    )
    with open(ic_xml, "w") as f:
        f.write(xml)
    print("  Patched ic_launcher.xml")

    # Update ic_launcher_background.xml gradient
    bg_xml = os.path.join(
        ROOT, "android", "app", "src", "main", "res",
        "drawable", "ic_launcher_background.xml",
    )
    with open(bg_xml, "w") as f:
        f.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<shape xmlns:android="http://schemas.android.com/apk/res/android">\n'
            f'  <gradient android:type="linear" android:angle="135"\n'
            f'      android:startColor="{cfg["grad_start"]}" android:endColor="{cfg["grad_end"]}"/>\n'
            '</shape>\n'
        )
    print(f"  Updated ic_launcher_background.xml ({cfg['grad_start']} → {cfg['grad_end']})")

    # Patch flutter_native_splash colors in pubspec.yaml before running the tool.
    # Replace every  color: "#XXXXXX"  and  icon_background_color: "#XXXXXX"
    # that appears inside the flutter_native_splash: section.
    splash_bg = cfg["splash_bg"]
    pubspec = os.path.join(ROOT, "pubspec.yaml")
    with open(pubspec) as f:
        lines = f.readlines()

    in_splash = False
    for i, line in enumerate(lines):
        stripped = line.lstrip()
        # Detect section start / end by indentation
        if stripped.startswith("flutter_native_splash:"):
            in_splash = True
            continue
        if in_splash:
            # A top-level (non-indented) key that isn't blank ends the section
            if line and not line[0].isspace():
                in_splash = False
                continue
            # Replace color: "..." and icon_background_color: "..." values
            lines[i] = re.sub(r'((?:icon_background_)?color:\s*")[^"]+(")', lambda m: m.group(1) + splash_bg + m.group(2), line)

    with open(pubspec, "w") as f:
        f.writelines(lines)
    print(f"  Updated pubspec.yaml splash colors → {splash_bg}")

    # Run flutter_native_splash
    print("  Running flutter_native_splash:create…")
    subprocess.run(["flutter", "pub", "run", "flutter_native_splash:create"], cwd=ROOT, check=True)

    # Overwrite the flat-colour background.png that flutter_native_splash just wrote
    # with the same radial gradient used in adaptive_icon_foreground.png so the
    # pre-Android-12 splash background matches the icon shading.
    res_dir = os.path.join(ROOT, "android", "app", "src", "main", "res")
    splash_grad = radial_gradient(cfg["bg_start"], cfg["bg_end"])
    for folder in ("drawable", "drawable-v21"):
        dest = os.path.join(res_dir, folder, "background.png")
        if os.path.exists(dest):
            splash_grad.save(dest)
    print(f"  Wrote radial-gradient background.png ({cfg['grad_start']} centre → {cfg['grad_end']} edge)")

    print(f"\nDone. Build with:")
    print("  flutter build apk --debug")

# ── Alternate icons (launcher icon switching) ─────────────────────────────────

# Android mipmap densities → launcher icon size (px)
_ANDROID_MIPMAP_SIZES = {
    "mipmap-mdpi":    48,
    "mipmap-hdpi":    72,
    "mipmap-xhdpi":   96,
    "mipmap-xxhdpi":  144,
    "mipmap-xxxhdpi": 192,
}

# Adaptive icon foreground sizes — 108dp × density (2.25× the 48dp icon).
# flutter_launcher_icons places these in drawable-{density}/ at these sizes.
_ANDROID_FOREGROUND_SIZES = {
    "drawable-mdpi":    108,
    "drawable-hdpi":    162,
    "drawable-xhdpi":   216,
    "drawable-xxhdpi":  324,
    "drawable-xxxhdpi": 432,
}

# iOS alternate icons are needed for all themes except the primary (deep_voyage).
# Files are placed in ios/Runner/ and referenced from Info.plist + project.pbxproj.
_IOS_ALTERNATE_THEMES = ["cherry_blossom", "golden_hour"]
_IOS_ICON_SIZES = [("@2x", 120), ("@3x", 180)]

def generate_alternate_icons():
    """Generate per-theme launcher icon assets for Android (mipmap PNGs + adaptive icon XMLs)
    and iOS (alternate icon PNGs).

    Android (API 26+, adaptive icon):
      drawable-{density}/ic_launcher_foreground_{theme}.png  — resized from adaptive_icon_foreground_{theme}.png
      drawable/ic_launcher_background_{theme}.xml             — gradient matching the theme
      mipmap-anydpi-v26/ic_launcher_{theme}.xml               — adaptive-icon compositor XML

    Android (API < 26, plain PNG fallback):
      mipmap-{density}/ic_launcher_{theme}.png                — resized from app_icon_{theme}.png

    iOS:
      ios/Runner/Icon-{theme}@2x.png (120 px)
      ios/Runner/Icon-{theme}@3x.png (180 px)
      deep_voyage is the primary/default icon so it needs no iOS alternate entry.
    """
    res_dir = os.path.join(ROOT, "android", "app", "src", "main", "res")
    ios_dir = os.path.join(ROOT, "ios", "Runner")
    adaptive_dir = os.path.join(res_dir, "mipmap-anydpi-v26")
    drawable_dir  = os.path.join(res_dir, "drawable")
    os.makedirs(adaptive_dir, exist_ok=True)

    print("\n── Generating alternate launcher icon assets ──")
    for theme_name, cfg in THEMES.items():
        # ── Source images ─────────────────────────────────────────────────────
        fg_src  = os.path.join(ICONS_DIR, f"adaptive_icon_foreground_{theme_name}.png")
        app_src = os.path.join(ICONS_DIR, f"app_icon_{theme_name}.png")
        if not os.path.exists(fg_src) or not os.path.exists(app_src):
            print(f"  SKIP {theme_name}: PNGs not found — run render step first.")
            continue

        fg_img  = Image.open(fg_src).convert("RGBA")
        app_img = Image.open(app_src).convert("RGBA")

        # ── Android: density-specific foreground PNGs (adaptive icon) ────────
        for folder, size in _ANDROID_FOREGROUND_SIZES.items():
            dest_dir = os.path.join(res_dir, folder)
            os.makedirs(dest_dir, exist_ok=True)
            out = os.path.join(dest_dir, f"ic_launcher_foreground_{theme_name}.png")
            fg_img.resize((size, size), Image.LANCZOS).save(out)

        # ── Android: background gradient XML for this theme ───────────────────
        with open(os.path.join(drawable_dir, f"ic_launcher_background_{theme_name}.xml"), "w") as f:
            f.write(
                '<?xml version="1.0" encoding="utf-8"?>\n'
                '<shape xmlns:android="http://schemas.android.com/apk/res/android">\n'
                f'  <gradient android:type="linear" android:angle="135"\n'
                f'      android:startColor="{cfg["grad_start"]}" android:endColor="{cfg["grad_end"]}"/>\n'
                '</shape>\n'
            )

        # ── Android: adaptive icon XML (API 26+) ──────────────────────────────
        with open(os.path.join(adaptive_dir, f"ic_launcher_{theme_name}.xml"), "w") as f:
            f.write(
                '<?xml version="1.0" encoding="utf-8"?>\n'
                '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                f'  <background android:drawable="@drawable/ic_launcher_background_{theme_name}"/>\n'
                f'  <foreground android:drawable="@drawable/ic_launcher_foreground_{theme_name}"/>\n'
                '</adaptive-icon>\n'
            )

        # ── Android: plain PNG fallback (API < 26) ────────────────────────────
        for folder, size in _ANDROID_MIPMAP_SIZES.items():
            dest_dir = os.path.join(res_dir, folder)
            os.makedirs(dest_dir, exist_ok=True)
            out = os.path.join(dest_dir, f"ic_launcher_{theme_name}.png")
            app_img.resize((size, size), Image.LANCZOS).save(out)

        print(f"  Android {theme_name}: adaptive XMLs + foreground PNGs + fallback PNGs written")

        # ── iOS: alternate icon PNGs ──────────────────────────────────────────
        if theme_name in _IOS_ALTERNATE_THEMES:
            for suffix, size in _IOS_ICON_SIZES:
                out = os.path.join(ios_dir, f"Icon-{theme_name}{suffix}.png")
                app_img.resize((size, size), Image.LANCZOS).save(out)
            print(f"  iOS {theme_name}: alternate PNGs written")

    print("\nAlternate icon assets generated.")

# ── Entry point ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    arg = sys.argv[1] if len(sys.argv) > 1 else "all"

    if arg in ("all",) or (len(sys.argv) == 1):
        print("Rendering PNGs for all themes…")
        for t in THEMES:
            render_pngs(t)
        generate_alternate_icons()
        print(f"\nAll done. To apply a theme run:")
        print(f"  python3 scripts/gen_icons.py [{'|'.join(THEMES)}]")
    elif arg == "alternates":
        generate_alternate_icons()
    elif arg in THEMES:
        render_pngs(arg)
        apply_theme(arg)
        generate_alternate_icons()
    else:
        print(f"Usage: python3 scripts/gen_icons.py [all | alternates | {'|'.join(THEMES)}]")
        sys.exit(1)
