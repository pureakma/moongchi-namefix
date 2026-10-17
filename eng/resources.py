from pathlib import Path
import json

root = Path(__file__).resolve().parent.parent
resources = root / "Resources"
catalog_path = resources / "Localizable.xcstrings"
languages = ["ko", "en", "ja"]

catalog = json.loads(catalog_path.read_text())["strings"]

def value_for(key, language):
    try:
        return catalog[key]["localizations"][language]["stringUnit"]["value"]
    except KeyError as exc:
        raise SystemExit(f"Missing localization: {key}/{language}") from exc

# Info.plist keys that macOS shows to the user, each mapped to its catalog key.
info_plist_keys = [
    ("CFBundleDisplayName", "AppName"),
    ("CFBundleName", "AppName"),
    ("Inspect Names with NameFix", "FinderServiceTitle"),
    ("NSDesktopFolderUsageDescription", "FolderAccessPurpose"),
    ("NSDocumentsFolderUsageDescription", "FolderAccessPurpose"),
    ("NSDownloadsFolderUsageDescription", "FolderAccessPurpose"),
]

def info_plist_strings(language):
    return "".join(
        json.dumps(name) + " = " + json.dumps(value_for(key, language), ensure_ascii=False) + ";\n"
        for name, key in info_plist_keys
    )

# Localizable.xcstrings is the single translation SSOT.
# Generate runtime .strings only for the app's explicit in-app language selection.
for language in languages:
    target = resources / f"{language}.lproj"
    target.mkdir(exist_ok=True)
    lines = [
        json.dumps(key) + " = " + json.dumps(value_for(key, language), ensure_ascii=False) + ";"
        for key in sorted(catalog)
    ]
    (target / "Localizable.strings").write_text("\n".join(lines) + "\n")
    (target / "InfoPlist.strings").write_text(info_plist_strings(language))
    # The Services menu reads the name of a service from ServicesMenu.strings, not from InfoPlist.strings.
    (target / "ServicesMenu.strings").write_text("".join(line + "\n" for line in info_plist_strings(language).splitlines() if line.startswith('"Inspect Names')))

for font in ["PretendardVariable", "PretendardJPVariable"]:
    ttf = resources / f"{font}.ttf"
    license_file = resources / f"{font}-LICENSE.txt"
    if not ttf.is_file() or not license_file.is_file():
        raise SystemExit(f"Missing bundled font asset: {font}")

print(len(catalog), "keys, three locales; Localizable.xcstrings is canonical")
