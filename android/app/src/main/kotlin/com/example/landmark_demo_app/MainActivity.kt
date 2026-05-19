package com.example.landmark_demo_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.FlutterInjector
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "landmark_demo_app/onnx_assets"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "prepareOnnxAssets" -> {
                    try {
                        val paths = prepareOnnxAssets()
                        result.success(paths)
                    } catch (e: Exception) {
                        result.error(
                            "onnx_asset_copy_failed",
                            e.message,
                            null
                        )
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun prepareOnnxAssets(): Map<String, String> {
        val flutterLoader = FlutterInjector.instance().flutterLoader()
        val modelAssetPath = flutterLoader.getLookupKeyForAsset(
            "assets/mobile_artifacts_int8/landmark_encoder.onnx"
        )
        val dataAssetPath = flutterLoader.getLookupKeyForAsset(
            "assets/mobile_artifacts_int8/landmark_encoder.onnx.data"
        )

        val targetDir = File(filesDir, "onnx_assets")
        if (!targetDir.exists()) {
            targetDir.mkdirs()
        }

        val modelFile = File(targetDir, "landmark_encoder.onnx")
        val dataFile = File(targetDir, "landmark_encoder.onnx.data")
        val readyFile = File(targetDir, ".ready")

        if (!readyFile.exists() || !modelFile.exists() || !dataFile.exists()) {
            copyAssetStream(modelAssetPath, modelFile)
            copyAssetStream(dataAssetPath, dataFile)
            readyFile.writeText("ready")
        }

        return mapOf(
            "modelPath" to modelFile.absolutePath,
            "dataPath" to dataFile.absolutePath
        )
    }

    private fun copyAssetStream(assetPath: String, destination: File) {
        assets.open(assetPath).use { input ->
            destination.outputStream().use { output ->
                input.copyTo(output, DEFAULT_BUFFER_SIZE)
                output.flush()
            }
        }
    }
}
