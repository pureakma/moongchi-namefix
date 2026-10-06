#!/usr/bin/env python3
"""Composes store and website images from the app's own captures.

Input:  <folder>/raw   written by `Moongchi NameFix --render-marketing` (Debug build)
Output: <folder>/store/<locale>/NN-scene.png   store screenshots with a caption
        <folder>/web/<scene>-<language>.jpg    the window alone, sized for the website
        <folder>/og/namefix-og.png             social preview
        <folder>/manifest.json                 what each image was made from

Nothing is drawn over the app's interface except the sheet the app itself shows in that state,
placed where macOS presents it. Captions come from marketing/appstore.json. Needs Pillow.
"""
import hashlib, json, pathlib, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

root = pathlib.Path(__file__).resolve().parent.parent
folder = pathlib.Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else root / "artifacts/marketing/namefix/1.0.0"
raw = folder / "raw"
captures = json.loads((raw / "captures.json").read_text(encoding="utf-8"))
store = json.loads((root / "marketing/appstore.json").read_text(encoding="utf-8"))
canvas = tuple(store["screenshots"]["size"])
captions = {scene["id"]: scene["caption"] for scene in store["screenshots"]["scenes"]}
short = {"ko-KR": "ko", "en-US": "en", "ja-JP": "ja"}
store_locale = {code: locale["appStoreLocale"] for code, locale in store["locales"].items()}

BACKGROUND, INK, MUTED = (240, 243, 248), (16, 40, 92), (88, 102, 128)
fonts = pathlib.Path.home() / "Library/Fonts"

def font(language, weight, size):
    """Pretendard, the app's own typeface; the Japanese variant ships with the app."""
    if language == "ja":
        face = ImageFont.truetype(str(root / "Resources/PretendardJPVariable.ttf"), size)
        face.set_variation_by_axes([700 if weight == "Bold" else 500])
        return face
    return ImageFont.truetype(str(fonts / f"Pretendard-{weight}.otf"), size)

def rounded(image, radius):
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, image.width - 1, image.height - 1], radius, fill=255)
    result = image.convert("RGBA"); result.putalpha(mask)
    return result

def shadowed(base, image, position, blur, alpha, drop):
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    silhouette = Image.new("RGBA", image.size, (10, 20, 45, alpha)); silhouette.putalpha(image.getchannel("A").point(lambda v: v * alpha // 255))
    shadow.paste(silhouette, (position[0], position[1] + drop), silhouette)
    base.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(blur)))
    base.alpha_composite(image, position)

def window(scene):
    """The captured window, with the sheet the app shows in this state placed over it."""
    image = Image.open(raw / scene["window"]).convert("RGBA")
    if "sheet" in scene:
        sheet = rounded(Image.open(raw / scene["sheet"]), 28)
        image.alpha_composite(Image.new("RGBA", image.size, (0, 0, 0, 56)))
        shadowed(image, sheet, ((image.width - sheet.width) // 2, (image.height - sheet.height) // 2), 36, 90, 18)
    return image

def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()

icon = Image.open(root / "assets/branding/NameFix-Original.png").convert("RGBA")
records = []
for scene in captures["scenes"]:
    language = short[scene["language"]]
    shot = window(scene)
    # Website image: the window alone.
    web = folder / "web" / f'{scene["scene"]}-{language}.jpg'; web.parent.mkdir(parents=True, exist_ok=True)
    reduced = shot.convert("RGB").resize((1600, round(1600 * shot.height / shot.width)), Image.LANCZOS)
    reduced.save(web, "JPEG", quality=84, optimize=True, progressive=True)
    # Store image: caption above the whole window.
    page = Image.new("RGBA", canvas, BACKGROUND + (255,))
    head, sub = captions[scene["scene"]][language]
    head_font, sub_font = font(language, "Bold", 104), font(language, "Medium", 50)
    mark = rounded(icon.resize((168, 168), Image.LANCZOS), 38)
    draw = ImageDraw.Draw(page)
    text_width = max(draw.textlength(head, font=head_font), draw.textlength(sub, font=sub_font))
    left = (canvas[0] - (168 + 44 + int(text_width))) // 2
    page.alpha_composite(mark, (left, 104))
    draw.text((left + 212, 92), head, font=head_font, fill=INK)
    draw.text((left + 214, 222), sub, font=sub_font, fill=MUTED)
    height = canvas[1] - 356 - 84
    scaled = rounded(shot.resize((round(shot.width * height / shot.height), height), Image.LANCZOS), 34)
    shadowed(page, scaled, ((canvas[0] - scaled.width) // 2, 356), 40, 70, 22)
    index = scene["scene"].split("-")[0]
    target = folder / "store" / store_locale[language] / f'{index.zfill(2)}-{scene["scene"].split("-", 1)[1]}.png'; target.parent.mkdir(parents=True, exist_ok=True)
    page.convert("RGB").save(target, "PNG", optimize=True)
    records.append({"scene": scene["scene"], "purpose": scene["purpose"], "locale": store_locale[language], "caption": [head, sub],
                    "raw": [scene["window"]] + ([scene["sheet"]] if "sheet" in scene else []), "rawSha256": [digest(raw / scene["window"])] + ([digest(raw / scene["sheet"])] if "sheet" in scene else []),
                    "store": str(target.relative_to(folder)), "storeSize": list(canvas), "storeSha256": digest(target),
                    "web": str(web.relative_to(folder)), "webSize": list(reduced.size)})

# Social preview: the icon, the product name and the repair screen.
og = Image.new("RGBA", (1200, 630), BACKGROUND + (255,))
draw = ImageDraw.Draw(og)
og.alpha_composite(rounded(icon.resize((92, 92), Image.LANCZOS), 21), (64, 60))
draw.text((176, 62), "Moongchi NameFix", font=font("en", "Bold", 46), fill=INK)
draw.text((177, 120), "Fix broken filenames. Preview first, undo from History.", font=font("en", "Medium", 25), fill=MUTED)
first = next(scene for scene in captures["scenes"] if scene["scene"] == "1-repair" and scene["language"] == "en-US")
preview = window(first); preview = rounded(preview.resize((1072, round(1072 * preview.height / preview.width)), Image.LANCZOS), 16)
shadowed(og, preview, (64, 196), 22, 70, 10)
(folder / "og").mkdir(exist_ok=True); og.convert("RGB").save(folder / "og/namefix-og.png", "PNG", optimize=True)

manifest = {"app": captures["app"], "version": captures["version"], "sourceBuild": captures["build"], "configuration": captures["configuration"],
            "note": "Captures are the app's own windows on sample files made for this purpose. Sheets are captured separately and placed over the window as the app presents them.",
            "captionSource": "marketing/appstore.json", "images": records, "og": {"file": "og/namefix-og.png", "size": [1200, 630], "sha256": digest(folder / "og/namefix-og.png")}}
(folder / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"PASS: {len(records)} store screenshots at {canvas[0]}x{canvas[1]}, {len(records)} website images and a social preview")
