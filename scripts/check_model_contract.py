import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACT_DIR = ROOT / "assets" / "mobile_artifacts_fp16"
INFO_PATH = ROOT / "assets" / "landmark_info.json"
HERO_DIR = ROOT / "assets" / "hero_images"

REQUIRED_BUNDLE_FILES = (
    "manifest.json",
    "classes.json",
    "prototype_index.json",
    "preprocessing.json",
    "tokenizer.json",
    "labels_master.json",
    "config.yaml",
)


def load_json(path: Path):
    with path.open("r", encoding="utf-8") as file:
        return json.load(file)


def fail(errors, message):
    errors.append(message)
    print(f"[FAIL] {message}")


def warn(warnings, message):
    warnings.append(message)
    print(f"[WARN] {message}")


def ok(message):
    print(f"[OK] {message}")


def class_ids_from_classes_json(data):
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        for key in ("classes", "items", "class_names"):
            value = data.get(key)
            if isinstance(value, list):
                return value
    return []


def required_manifest_files(manifest):
    required = []
    for section in ("image_encoder", "text_encoder"):
        encoder = manifest.get(section)
        if not isinstance(encoder, dict):
            continue
        for key in ("onnx", "external_data"):
            value = encoder.get(key)
            if isinstance(value, str) and value:
                required.append(value)
    return required


def main():
    errors = []
    warnings = []

    manifest_path = ARTIFACT_DIR / "manifest.json"
    classes_path = ARTIFACT_DIR / "classes.json"
    prototype_path = ARTIFACT_DIR / "prototype_index.json"

    for path in (manifest_path, classes_path, prototype_path, INFO_PATH):
        if not path.exists():
            fail(errors, f"required file not found: {path.relative_to(ROOT)}")

    if errors:
        return 1

    manifest = load_json(manifest_path)
    classes = class_ids_from_classes_json(load_json(classes_path))
    prototype = load_json(prototype_path)
    info = load_json(INFO_PATH)

    ok("manifest/classes/prototype/landmark_info loaded")

    for file_name in REQUIRED_BUNDLE_FILES:
        path = ARTIFACT_DIR / file_name
        if path.exists():
            ok(f"bundle metadata exists: {path.relative_to(ROOT)}")
        else:
            fail(errors, f"missing required bundle metadata: {path.relative_to(ROOT)}")

    for file_name in required_manifest_files(manifest):
        path = ARTIFACT_DIR / file_name
        if path.exists():
            ok(f"artifact exists: {path.relative_to(ROOT)}")
        else:
            fail(errors, f"missing artifact required by manifest: {path.relative_to(ROOT)}")

    class_count = manifest.get("class_count")
    if len(classes) == class_count:
        ok(f"class_count matches manifest: {class_count}")
    else:
        fail(errors, f"class_count mismatch: manifest={class_count}, classes.json={len(classes)}")

    items = prototype.get("items", []) if isinstance(prototype, dict) else []
    if len(items) == class_count:
        ok(f"prototype item count matches manifest: {len(items)}")
    else:
        fail(errors, f"prototype item count mismatch: manifest={class_count}, prototype_index={len(items)}")

    embedding_dim = manifest.get("embedding_dim")
    prototype_ids = []
    for index, item in enumerate(items):
        landmark_id = item.get("landmark_id")
        embedding = item.get("embedding") or item.get("prototype")
        prototype_ids.append(landmark_id)
        if not isinstance(embedding, list):
            fail(errors, f"prototype item {index} has no embedding list: {landmark_id}")
        elif len(embedding) != embedding_dim:
            fail(errors, f"embedding dim mismatch for {landmark_id}: expected={embedding_dim}, actual={len(embedding)}")

    if not errors:
        ok(f"all prototype embeddings have dimension {embedding_dim}")

    info_items = info.get("items", []) if isinstance(info, dict) else []
    info_by_id = {item.get("landmark_id"): item for item in info_items}
    info_ids = set(info_by_id)

    missing_info = sorted(set(prototype_ids) - info_ids)
    if missing_info:
        fail(errors, f"prototype landmark_id missing in landmark_info.json: {missing_info}")
    else:
        ok("all prototype landmark_ids exist in landmark_info.json")

    bad_parents = []
    for item in info_items:
        parent = item.get("parent_landmark_id")
        if parent and parent not in info_ids:
            bad_parents.append((item.get("landmark_id"), parent))

    if bad_parents:
        fail(errors, f"invalid parent_landmark_id references: {bad_parents}")
    else:
        ok("all parent_landmark_id values resolve to landmark_info ids")

    hero_ids = {path.stem for path in HERO_DIR.glob("*") if path.is_file()}
    missing_direct_hero = sorted(set(prototype_ids) - hero_ids)
    missing_without_fallback = []
    for landmark_id in missing_direct_hero:
        parent = info_by_id.get(landmark_id, {}).get("parent_landmark_id")
        if not parent or parent not in hero_ids:
            missing_without_fallback.append(landmark_id)

    if missing_direct_hero:
        warn(warnings, f"missing direct hero images; parent/placeholder fallback needed: {missing_direct_hero}")
    else:
        ok("all prototype classes have direct hero images")

    if missing_without_fallback:
        warn(warnings, f"missing direct hero images without parent hero fallback: {missing_without_fallback}")

    print("")
    print(f"Contract check complete: errors={len(errors)}, warnings={len(warnings)}")
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
