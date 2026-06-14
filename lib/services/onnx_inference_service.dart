import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path_provider/path_provider.dart';

class OnnxInferenceService {
  static const _assetChannel = MethodChannel(
    'landmark_demo_app/onnx_assets',
  );

  double _resizeScale = 1.15;
  int _imageSize = 224;
  List<double> _mean = const [0.48145466, 0.4578275, 0.40821073];
  List<double> _std = const [0.26862954, 0.26130258, 0.27577711];

  static const String _manifestAssetPath =
      'assets/mobile_artifacts_fp16/manifest.json';
  static const String _assetDir = 'assets/mobile_artifacts_fp16';

  OrtSession? _imageSession;
  OrtSession? _textSession;
  Future<void>? _initializing;
  String? _lastInitError;
  String? _modelSpecWarning;

  String? get modelSpecWarning => _modelSpecWarning;

  Future<void> initializeOnnxModel() async {
    if (_imageSession != null) return;
    if (_initializing != null) return _initializing!;

    _initializing = _initializeInternal();
    try {
      await _initializing!;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _initializeInternal() async {
    OrtSessionOptions? imageSessionOptions;
    OrtSessionOptions? textSessionOptions;
    try {
      _lastInitError = null;
      OrtEnv.instance.init();

      // preprocessing.json 동적 파싱 로드 (P2)
      await _loadPreprocessingConfig();

      imageSessionOptions = OrtSessionOptions();
      imageSessionOptions.setInterOpNumThreads(1);
      imageSessionOptions.setIntraOpNumThreads(2);
      imageSessionOptions.setSessionGraphOptimizationLevel(
        GraphOptimizationLevel.ortEnableAll,
      );

      textSessionOptions = OrtSessionOptions();
      textSessionOptions.setInterOpNumThreads(1);
      textSessionOptions.setIntraOpNumThreads(2);
      textSessionOptions.setSessionGraphOptimizationLevel(
        GraphOptimizationLevel.ortEnableAll,
      );

      final preparedFiles = await _prepareModelFiles();

      _imageSession = OrtSession.fromFile(
        File(preparedFiles['modelPath']!),
        imageSessionOptions,
      );

      // text encoder 세션 로드 준비
      _textSession = OrtSession.fromFile(
        File(preparedFiles['textModelPath']!),
        textSessionOptions,
      );

      print(
          'ONNX sessions initialized: Image=${preparedFiles['modelPath']}, Text=${preparedFiles['textModelPath']}');

      // 모델 메타데이터 스펙 정합성 검증 레이어 탑재 (P2)
      await _verifyModelMetadata();
    } catch (e, stackTrace) {
      _lastInitError = e.toString();
      print('ONNX initialization failed: $e');
      print(stackTrace);
      rethrow;
    } finally {
      imageSessionOptions?.release();
      textSessionOptions?.release();
    }
  }

  Future<Map<String, String>> _prepareModelFiles() async {
    if (Platform.isAndroid) {
      final result = await _assetChannel.invokeMapMethod<String, String>(
            'prepareOnnxAssets',
          ) ??
          const {};

      final modelPath = result['modelPath'];
      final dataPath = result['dataPath'];
      final textModelPath = result['textModelPath'];
      final textDataPath = result['textDataPath'];

      if (modelPath == null ||
          modelPath.isEmpty ||
          dataPath == null ||
          dataPath.isEmpty ||
          textModelPath == null ||
          textModelPath.isEmpty ||
          textDataPath == null ||
          textDataPath.isEmpty) {
        throw Exception('Android asset preparation returned incomplete paths');
      }

      if (!await File(modelPath).exists() ||
          !await File(dataPath).exists() ||
          !await File(textModelPath).exists() ||
          !await File(textDataPath).exists()) {
        throw Exception(
            'Prepared ONNX files are missing on Android filesystem');
      }

      return {
        'modelPath': modelPath,
        'dataPath': dataPath,
        'textModelPath': textModelPath,
        'textDataPath': textDataPath,
      };
    }

    // iOS or Desktop fallback path using manifest
    final manifestContent = await rootBundle.loadString(_manifestAssetPath);
    final manifest = json.decode(manifestContent) as Map<String, dynamic>;

    final imageInfo = manifest['image_encoder'] as Map<String, dynamic>;
    final imgOnnxName = imageInfo['onnx'] as String;
    final imgDataName = imageInfo['external_data'] as String;

    final textInfo = manifest['text_encoder'] as Map<String, dynamic>;
    final txtOnnxName = textInfo['onnx'] as String;
    final txtDataName = textInfo['external_data'] as String;

    final appDir = await getApplicationDocumentsDirectory();

    final imgModelFile = File('${appDir.path}/$imgOnnxName');
    final imgDataFile = File('${appDir.path}/$imgDataName');
    final txtModelFile = File('${appDir.path}/$txtOnnxName');
    final txtDataFile = File('${appDir.path}/$txtDataName');

    if (!await imgModelFile.exists()) {
      await _copyAsset('$_assetDir/$imgOnnxName', imgModelFile);
    }
    if (!await imgDataFile.exists()) {
      await _copyAsset('$_assetDir/$imgDataName', imgDataFile);
    }
    if (!await txtModelFile.exists()) {
      await _copyAsset('$_assetDir/$txtOnnxName', txtModelFile);
    }
    if (!await txtDataFile.exists()) {
      await _copyAsset('$_assetDir/$txtDataName', txtDataFile);
    }

    return {
      'modelPath': imgModelFile.path,
      'dataPath': imgDataFile.path,
      'textModelPath': txtModelFile.path,
      'textDataPath': txtDataFile.path,
    };
  }

  Future<void> _copyAsset(String assetPath, File destination) async {
    try {
      final data = await rootBundle.load(assetPath);
      final bytes = data.buffer.asUint8List();
      await destination.writeAsBytes(bytes, flush: true);
    } catch (e) {
      throw Exception('Missing or unreadable model artifact asset: $assetPath');
    }
  }

  void release() {
    _imageSession?.release();
    _imageSession = null;
    _textSession?.release();
    _textSession = null;
    OrtEnv.instance.release();
  }

  bool get isInitialized => _imageSession != null;
  String? get lastInitError => _lastInitError;

  Future<List<double>> extractEmbedding(Uint8List imageBytes) async {
    await initializeOnnxModel();
    if (_imageSession == null) {
      throw Exception(_lastInitError ?? 'Session not initialized');
    }

    final srcImage = img.decodeImage(imageBytes);
    if (srcImage == null) {
      throw Exception('Failed to decode image');
    }

    final rgbImage = srcImage.convert(
      format: img.Format.uint8,
      numChannels: 3,
    );

    final w = rgbImage.width;
    final h = rgbImage.height;
    final scale = _resizeScale * _imageSize / min(w, h).toDouble();
    final newW = (w * scale).round();
    final newH = (h * scale).round();

    final resized = img.copyResize(
      rgbImage,
      width: newW,
      height: newH,
      interpolation: img.Interpolation.cubic,
    );

    final left = (newW - _imageSize) ~/ 2;
    final top = (newH - _imageSize) ~/ 2;
    final cropped = img.copyCrop(
      resized,
      x: left,
      y: top,
      width: _imageSize,
      height: _imageSize,
    );

    final numPixels = _imageSize * _imageSize;
    final float32Data = Float32List(3 * numPixels);

    for (var cy = 0; cy < _imageSize; cy++) {
      for (var cx = 0; cx < _imageSize; cx++) {
        final pixel = cropped.getPixel(cx, cy);
        final r = (pixel.rNormalized - _mean[0]) / _std[0];
        final g = (pixel.gNormalized - _mean[1]) / _std[1];
        final b = (pixel.bNormalized - _mean[2]) / _std[2];
        final index = cy * _imageSize + cx;
        float32Data[index] = r;
        float32Data[numPixels + index] = g;
        float32Data[2 * numPixels + index] = b;
      }
    }

    final shape = [1, 3, _imageSize, _imageSize];
    final tensor = OrtValueTensor.createTensorWithDataList(float32Data, shape);
    final runOptions = OrtRunOptions();

    final outputs = _imageSession!.run(runOptions, {'image': tensor});
    final outputTensor = outputs[0]?.value as List<dynamic>;

    tensor.release();
    runOptions.release();
    for (final output in outputs) {
      output?.release();
    }

    final List<double> raw;
    if (outputTensor.isNotEmpty && outputTensor[0] is List) {
      raw =
          (outputTensor[0] as List).map((e) => (e as num).toDouble()).toList();
    } else {
      raw = outputTensor.map((e) => (e as num).toDouble()).toList();
    }

    return _l2Normalize(raw);
  }

  Future<List<double>> extractTextEmbedding(List<int> textTokens) async {
    await initializeOnnxModel();
    if (_textSession == null) {
      throw Exception(_lastInitError ?? 'Text session not initialized');
    }

    final tokenData = Int64List.fromList(textTokens);
    final shape = [1, textTokens.length];
    final tensor = OrtValueTensor.createTensorWithDataList(tokenData, shape);
    final runOptions = OrtRunOptions();

    final outputs = _textSession!.run(
      runOptions,
      {'text_tokens': tensor},
    );
    final outputTensor = outputs[0]?.value as List<dynamic>;

    tensor.release();
    runOptions.release();
    for (final output in outputs) {
      output?.release();
    }

    final List<double> raw;
    if (outputTensor.isNotEmpty && outputTensor[0] is List) {
      raw =
          (outputTensor[0] as List).map((e) => (e as num).toDouble()).toList();
    } else {
      raw = outputTensor.map((e) => (e as num).toDouble()).toList();
    }

    return _l2Normalize(raw);
  }

  List<double> _l2Normalize(List<double> values) {
    var norm = 0.0;
    for (final value in values) {
      norm += value * value;
    }
    norm = sqrt(norm);
    if (norm < 1e-12) {
      return values;
    }
    return values.map((value) => value / norm).toList();
  }

  Future<void> _loadPreprocessingConfig() async {
    try {
      final jsonString = await rootBundle
          .loadString('assets/mobile_artifacts_fp16/preprocessing.json');
      final Map<String, dynamic> config = json.decode(jsonString);

      _imageSize = config['image_size'] as int? ?? 224;

      final meanList = config['image_mean'] ?? config['mean'];
      if (meanList is List) {
        _mean = meanList.map((e) => (e as num).toDouble()).toList();
      }

      final stdList = config['image_std'] ?? config['std'];
      if (stdList is List) {
        _std = stdList.map((e) => (e as num).toDouble()).toList();
      }

      _resizeScale =
          (config['resize_short_side_scale'] ?? config['resize_scale'] as num?)
                  ?.toDouble() ??
              1.15;

      print(
          'ONNX preprocessing configured: Size=$_imageSize, Mean=$_mean, Std=$_std, Scale=$_resizeScale');
    } catch (e) {
      print('Failed to load preprocessing config, using fallback: $e');
    }
  }

  Future<void> _verifyModelMetadata() async {
    try {
      final manifestContent = await rootBundle.loadString(_manifestAssetPath);
      final manifest = json.decode(manifestContent) as Map<String, dynamic>;

      final String modelId = manifest['model_id'] as String? ?? '';
      final String precision = manifest['precision'] as String? ?? '';
      final int classCount = manifest['class_count'] as int? ?? 0;

      // 앱이 기대하는 스펙 (classes.json 기준 23개 클래스 ID)
      const String expectedModelId = 'mobileclip2_s3_server_full_ce_hardneg';
      const String expectedPrecision = 'fp16';
      const int expectedClassCount = 23;

      List<String> mismatches = [];

      if (modelId != expectedModelId) {
        mismatches
            .add('Model ID Mismatch: Expected $expectedModelId, Got $modelId');
      }
      if (precision != expectedPrecision) {
        mismatches.add(
            'Precision Mismatch: Expected $expectedPrecision, Got $precision');
      }
      if (classCount != expectedClassCount) {
        mismatches.add(
            'Class Count Mismatch: Expected $expectedClassCount, Got $classCount');
      }

      if (mismatches.isNotEmpty) {
        final warningMsg = 'Model Spec Mismatch: ${mismatches.join(", ")}';
        print('⚠️ [WARNING] ONNX MODEL SPECS MISMATCH DETECTED:');
        for (var m in mismatches) {
          print('  - $m');
        }
        _modelSpecWarning = warningMsg;
      } else {
        _modelSpecWarning = null;
        print(
            '✅ ONNX model metadata verified successfully. Spec matches: $expectedModelId, $expectedPrecision, $expectedClassCount classes.');
      }
    } catch (e) {
      print('Failed to verify model metadata: $e');
    }
  }
}
