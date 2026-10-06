from pathlib import Path
import json
import plistlib
import re

root = Path(__file__).resolve().parent.parent
resources = root / "Resources"
languages = ["ko", "en", "ja"]
catalog = json.loads((resources / "Localizable.xcstrings").read_text())["strings"]

def value_for(key, language):
    try:
        value = catalog[key]["localizations"][language]["stringUnit"]["value"]
    except KeyError as exc:
        raise AssertionError(f"Missing localization: {key}/{language}") from exc
    assert isinstance(value, str), (key, language)
    return value

for key in catalog:
    values = [value_for(key, language) for language in languages]
    args = [set(re.findall(r"\{(\d+)\}", value)) for value in values]
    assert args[0] == args[1] == args[2], key
    assert all(not re.search(r"\{\d+:", value) for value in values), key
    assert all(
        not any(word in value for word in ["Windows", "Ctrl+", "Explorer", "MAX_PATH"])
        for value in values
    ), key

for source in (root / "App").glob("*.swift"):
    for key in re.findall(r'(?:\.t\(|L10n\.text\()"([A-Za-z]+)"', source.read_text()):
        assert key in catalog, (source, key)

# Generated runtime strings must be exactly reproducible from the canonical catalog.
for language in languages:
    expected = "\n".join(
        json.dumps(key) + " = " + json.dumps(value_for(key, language), ensure_ascii=False) + ";"
        for key in sorted(catalog)
    )
    actual = (resources / f"{language}.lproj" / "Localizable.strings").read_text()
    assert actual == expected, f"{language} Localizable.strings is not generated from xcstrings"
    expected_info = (
        '"Inspect Names with NameFix" = '
        + json.dumps(value_for("FinderServiceTitle", language), ensure_ascii=False)
        + ";\n"
    )
    actual_info = (resources / f"{language}.lproj" / "InfoPlist.strings").read_text()
    assert actual_info == expected_info, f"{language} InfoPlist.strings mismatch"

for font in ["PretendardVariable", "PretendardJPVariable"]:
    ttf = resources / f"{font}.ttf"
    license_file = resources / f"{font}-LICENSE.txt"
    assert ttf.is_file() and ttf.stat().st_size > 100_000, font
    license_text = license_file.read_text(errors="strict").upper()
    assert "SIL OPEN FONT LICENSE" in license_text and "1.1" in license_text, font

info = plistlib.loads((root / "App/Info.plist").read_bytes())
assert info["LSArchitecturePriority"] == ["arm64"]
assert info["NSServices"]

assert "#DDD8C5" in (root / "App/Theme.swift").read_text()

assert not any(
    re.search(r"URLSession|NWConnection|NSURLConnection", path.read_text())
    for folder in ["App", "Application", "Infrastructure"]
    for path in (root / folder).glob("*.swift")
)

for path in [
    root / "eng/resources.py",
    root / "eng/validate-resources.py",
    root / "docs/ARCHITECTURE.md",
    root / "docs/README.md",
    root / "assets/branding/README.md",
]:
    text = path.read_text()
    assert "Moongchi_NameFix_macOS_Dev_Handoff_v1.0" not in text, path
    assert "eng/expansion-localizations.json" not in text, path

print(
    f"PASS: {len(catalog)} keys × 3 locales; xcstrings canonical; "
    "generated strings parity; fonts/licenses; arm64 Services plist; "
    "no networking APIs; no handoff dependency"
)
