import json
import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ARTIFACT_DIR = ROOT / "assets" / "mobile_artifacts_fp16"


def read_text(path):
    return (ROOT / path).read_text(encoding="utf-8")


def load_json(path):
    return json.loads((ROOT / path).read_text(encoding="utf-8"))


class ModelIntegrationContractTest(unittest.TestCase):
    def test_fp16_artifact_bundle_matches_manifest(self):
        manifest = load_json("assets/mobile_artifacts_fp16/manifest.json")
        self.assertEqual(manifest["model_id"], "mobileclip2_s3_server_full_ce_hardneg")
        self.assertEqual(manifest["precision"], "fp16")
        self.assertEqual(manifest["class_count"], 23)
        self.assertEqual(manifest["embedding_dim"], 512)

        for section in ("image_encoder", "text_encoder"):
            with self.subTest(section=section):
                encoder = manifest[section]
                self.assertTrue((ARTIFACT_DIR / encoder["onnx"]).exists())
                self.assertTrue((ARTIFACT_DIR / encoder["external_data"]).exists())

        for file_name in (
            "classes.json",
            "prototype_index.json",
            "preprocessing.json",
            "tokenizer.json",
            "labels_master.json",
            "config.yaml",
            "confidence_policy.json",
            "tokenizer_bundle.json",
            "text_index.json",
            "text_search_policy.json",
            "text_query_regression_set.json",
            "text_search_eval_report.json",
        ):
            with self.subTest(file_name=file_name):
                self.assertTrue((ARTIFACT_DIR / file_name).exists())

    def test_model_artifact_metadata_has_no_local_absolute_paths(self):
        manifest_text = read_text("assets/mobile_artifacts_fp16/manifest.json")
        sync_script = read_text("scripts/sync_model_artifacts.ps1")

        local_path_pattern = re.compile(r"[A-Za-z]:\\|C:/Users|D:/|D:\\")
        self.assertNotRegex(manifest_text, local_path_pattern)
        self.assertNotRegex(sync_script, local_path_pattern)
        self.assertIn("LANDMARK_MODEL_ARTIFACT_SOURCE", sync_script)

    def test_prototype_index_uses_embedding_schema_and_23_classes(self):
        manifest = load_json("assets/mobile_artifacts_fp16/manifest.json")
        prototype = load_json("assets/mobile_artifacts_fp16/prototype_index.json")
        items = prototype["items"]

        self.assertEqual(len(items), manifest["class_count"])
        for item in items:
            with self.subTest(landmark_id=item["landmark_id"]):
                self.assertIn("embedding", item)
                self.assertEqual(len(item["embedding"]), manifest["embedding_dim"])

    def test_landmark_info_covers_prototypes_and_parent_ids(self):
        prototype = load_json("assets/mobile_artifacts_fp16/prototype_index.json")
        info = load_json("assets/landmark_info.json")["items"]
        prototype_ids = {item["landmark_id"] for item in prototype["items"]}
        info_by_id = {item["landmark_id"]: item for item in info}

        self.assertTrue(prototype_ids.issubset(info_by_id))
        self.assertIn("gyeongbokgung", info_by_id)
        for child in (
            "gwanghwamun",
            "gyeongbokgung_geunjeongmun",
            "gyeongbokgung_geunjeongjeon",
        ):
            self.assertEqual(info_by_id[child].get("parent_landmark_id"), "gyeongbokgung")

        for item in info:
            parent = item.get("parent_landmark_id")
            if parent:
                self.assertIn(parent, info_by_id)

    def test_pubspec_and_gitignore_keep_large_artifacts_external(self):
        pubspec = read_text("pubspec.yaml")
        gitignore = read_text(".gitignore")

        self.assertIn("assets/mobile_artifacts_fp16/", pubspec)
        self.assertIn("assets/mobile_artifacts_fp16/*.onnx", gitignore)
        self.assertIn("assets/mobile_artifacts_fp16/*.onnx.data", gitignore)

    def test_dart_code_uses_manifest_split_encoders_and_embedding_schema(self):
        onnx_service = read_text("lib/services/onnx_inference_service.dart")
        local_api = read_text("lib/api/local_api_client_impl.dart")
        main_activity = read_text(
            "android/app/src/main/kotlin/com/example/landmark_demo_app/MainActivity.kt"
        )

        self.assertIn("manifest['image_encoder']", onnx_service)
        self.assertIn("manifest['text_encoder']", onnx_service)
        self.assertIn("OrtSession.fromFile", onnx_service)
        self.assertIn('json.getJSONObject("image_encoder")', main_activity)
        self.assertIn('json.getJSONObject("text_encoder")', main_activity)
        self.assertIn("item['embedding'] ?? item['prototype']", local_api)

    def test_score_contract_and_keyword_text_search_are_separated(self):
        local_api = read_text("lib/api/local_api_client_impl.dart")
        semantic_service = read_text("lib/services/semantic_text_search_service.dart")
        keyword_service = read_text("lib/services/keyword_search_service.dart")
        result_screen = read_text("lib/ui/screens/result_screen.dart")

        for token in (
            "'raw_score'",
            "'display_score'",
            "'score_type'",
            "'cosine_similarity'",
            "'decision_status'",
            "'top3_scores'",
            "'margin'",
            "'model_version'",
            "'backend'",
        ):
            with self.subTest(token=token):
                self.assertIn(token, local_api)

        for token in (
            "'semantic_text_fusion'",
            "'keyword_score'",
            "'semantic_score'",
            "'final_text_score'",
            "'matched_text'",
        ):
            with self.subTest(token=token):
                self.assertIn(token, semantic_service)

        self.assertIn("scoreLandmarks", keyword_service)
        self.assertIn("LIKE", keyword_service)
        self.assertIn("display_score", result_screen)
        self.assertNotRegex(result_screen, re.compile(r"정답\\s*확률|확률"))

    def test_semantic_text_artifacts_are_contract_valid(self):
        manifest = load_json("assets/mobile_artifacts_fp16/manifest.json")
        info = load_json("assets/landmark_info.json")["items"]
        info_ids = {item["landmark_id"] for item in info}
        tokenizer_bundle = load_json("assets/mobile_artifacts_fp16/tokenizer_bundle.json")
        text_index = load_json("assets/mobile_artifacts_fp16/text_index.json")
        text_policy = load_json("assets/mobile_artifacts_fp16/text_search_policy.json")
        regression = load_json("assets/mobile_artifacts_fp16/text_query_regression_set.json")
        eval_report = load_json("assets/mobile_artifacts_fp16/text_search_eval_report.json")

        self.assertEqual(tokenizer_bundle["context_length"], 77)
        self.assertGreater(len(tokenizer_bundle["fixtures"]), 0)

        text_items = text_index["items"]
        self.assertGreater(len(text_items), 0)
        for item in text_items:
            with self.subTest(text_id=item["text_id"]):
                self.assertIn(item["landmark_id"], info_ids)
                self.assertEqual(len(item["embedding"]), manifest["embedding_dim"])

        for key in (
            "semantic_weight",
            "keyword_weight",
            "matched_threshold",
            "ambiguous_margin",
            "out_of_scope_threshold",
            "no_keyword_oos_margin",
            "no_keyword_match_threshold",
        ):
            with self.subTest(policy_key=key):
                self.assertIsInstance(text_policy[key], (int, float))

        self.assertGreater(len(regression["items"]), 0)
        for query in regression["items"]:
            expected = query.get("expected_landmark_id")
            if expected is not None:
                self.assertIn(expected, info_ids)

        self.assertEqual(eval_report["query_count"], len(regression["items"]))
        self.assertGreaterEqual(eval_report["top1_accuracy"], 0.95)
        self.assertGreaterEqual(eval_report["top3_recall"], 0.95)
        self.assertGreaterEqual(eval_report["out_of_scope_accuracy"], 0.8)

    def test_semantic_text_dart_services_are_wired(self):
        local_api = read_text("lib/api/local_api_client_impl.dart")
        semantic_service = read_text("lib/services/semantic_text_search_service.dart")
        tokenizer_service = read_text("lib/services/tokenizer_service.dart")
        text_index_repository = read_text("lib/data/text_index_repository.dart")
        onnx_service = read_text("lib/services/onnx_inference_service.dart")

        self.assertIn("SemanticTextSearchService(_onnxService)", local_api)
        self.assertIn("extractTextEmbedding(tokens)", semantic_service)
        self.assertIn("no_keyword_oos_margin", semantic_service)
        self.assertIn("no_keyword_match_threshold", semantic_service)
        self.assertIn("tokenizer_bundle.json", tokenizer_service)
        self.assertIn("text_index.json", text_index_repository)
        self.assertIn("text_search_policy.json", semantic_service)
        self.assertIn("Int64List.fromList(textTokens)", onnx_service)

    def test_confidence_policy_is_loaded_from_asset(self):
        policy = load_json("assets/mobile_artifacts_fp16/confidence_policy.json")
        local_api = read_text("lib/api/local_api_client_impl.dart")

        self.assertEqual(policy["model_id"], "mobileclip2_s3_server_full_ce_hardneg")
        self.assertEqual(policy["precision"], "fp16")
        for key in (
            "reject_threshold",
            "weak_reject_threshold",
            "weak_margin",
            "match_threshold",
            "match_floor",
            "match_margin",
        ):
            with self.subTest(key=key):
                self.assertIsInstance(policy[key], (int, float))
                self.assertIn(key, local_api)
        self.assertIn("confidence_policy.json", local_api)


if __name__ == "__main__":
    unittest.main()
