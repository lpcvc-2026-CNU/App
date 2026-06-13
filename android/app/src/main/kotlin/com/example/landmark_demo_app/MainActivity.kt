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
        val manifestAssetKey = flutterLoader.getLookupKeyForAsset(
            "assets/mobile_artifacts_fp16/manifest.json"
        )

        // Read manifest.json from assets
        val manifestContent = assets.open(manifestAssetKey).bufferedReader().use { it.readText() }
        val json = org.json.JSONObject(manifestContent)
        
        val imageEncoderObj = json.getJSONObject("image_encoder")
        val imgOnnxName = imageEncoderObj.getString("onnx")
        val imgDataName = imageEncoderObj.getString("external_data")
        
        val textEncoderObj = json.getJSONObject("text_encoder")
        val txtOnnxName = textEncoderObj.getString("onnx")
        val txtDataName = textEncoderObj.getString("external_data")

        val targetDir = File(filesDir, "onnx_assets")
        if (!targetDir.exists()) {
            targetDir.mkdirs()
        }

        // Define files to copy
        val filesToCopy = listOf(
            imgOnnxName,
            imgDataName,
            txtOnnxName,
            txtDataName
        )

        val pathsMap = mutableMapOf<String, String>()
        
        for (fileName in filesToCopy) {
            val assetPath = "assets/mobile_artifacts_fp16/$fileName"
            val assetKey = flutterLoader.getLookupKeyForAsset(assetPath)
            val destinationFile = File(targetDir, fileName)
            
            // Check if file needs copying (check existence and size mismatch for cache invalidation)
            val assetFd = try {
                assets.openFd(assetKey)
            } catch (e: Exception) {
                null
            }

            val needsCopy = if (assetFd != null) {
                !destinationFile.exists() || destinationFile.length() != assetFd.length
            } else {
                !destinationFile.exists()
            }
            
            assetFd?.close()

            if (needsCopy) {
                copyAssetStream(assetKey, destinationFile)
            }
        }

        pathsMap["modelPath"] = File(targetDir, imgOnnxName).absolutePath
        pathsMap["dataPath"] = File(targetDir, imgDataName).absolutePath
        pathsMap["textModelPath"] = File(targetDir, txtOnnxName).absolutePath
        pathsMap["textDataPath"] = File(targetDir, txtDataName).absolutePath

        return pathsMap
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
