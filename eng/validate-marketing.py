#!/usr/bin/env python3
"""Checks marketing/appstore.json: every locale has every field, within the store's limits,
and the public facts agree with the app (version, support address, website)."""
import json, pathlib, plistlib, re, sys

root = pathlib.Path(__file__).resolve().parent.parent
data = json.loads((root / "marketing/appstore.json").read_text(encoding="utf-8"))
errors = []
limits = data["limits"]
fields = ["name", "subtitle", "promotionalText", "description", "keywords"]
for code in data["product"]["languages"]:
    locale = data["locales"].get(code)
    if not locale:
        errors.append(f"{code}: locale missing"); continue
    for field in fields:
        value = locale.get(field, "")
        if not value.strip(): errors.append(f"{code}.{field}: empty")
        if len(value) > limits[field]: errors.append(f"{code}.{field}: {len(value)} > {limits[field]}")
    if locale.get("name") != data["product"]["name"]: errors.append(f"{code}.name differs from the product name")
    if any(len(word.strip()) < 2 for word in locale.get("keywords", "").split(",")): errors.append(f"{code}.keywords: a keyword is too short")
    for scene in data["screenshots"]["scenes"]:
        caption = scene["caption"].get(code)
        if not caption or len(caption) != 2 or not all(caption): errors.append(f"{code}: caption missing for {scene['id']}")
for name, url in data["urls"].items():
    if not url.startswith("https://moongchi.ailoworks.com/"): errors.append(f"urls.{name}: not on the product website")
# No superlatives or unproven promises in any public copy.
banned = re.compile(r"세계 최고|완벽|절대 안전|world'?s best|perfect|100% safe|世界一|完璧|絶対安全", re.I)
for code, locale in data["locales"].items():
    for field in fields:
        if banned.search(locale.get(field, "")): errors.append(f"{code}.{field}: unsupported claim")
project = (root / "project.yml").read_text(encoding="utf-8")
if f'MARKETING_VERSION: {data["product"]["version"]}' not in project and f'MARKETING_VERSION: "{data["product"]["version"]}"' not in project:
    errors.append("product.version differs from project.yml")
if data["appStore"]["bundleId"] not in project: errors.append("appStore.bundleId is not a bundle identifier in project.yml")
source = (root / "App/Localization.swift").read_text(encoding="utf-8")
if "mailto:" + data["product"]["supportEmail"] not in source: errors.append("supportEmail differs from the app")
with open(root / "App/Info.plist", "rb") as handle:
    if data["appStore"]["copyright"] not in plistlib.load(handle).get("NSHumanReadableCopyright", "").replace("Copyright © ", ""): errors.append("copyright differs from Info.plist")
if errors:
    print("\n".join(errors)); sys.exit(1)
print("PASS: store metadata for", ", ".join(data["product"]["languages"]), "is complete and within limits")
