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

  static const double _resizeScale = 1.15;
  static const int _imageSize = 224;
  static const List<double> _mean = [0.48145466, 0.4578275, 0.40821073];
  static const List<double> _std = [0.26862954, 0.26130258, 0.27577711];

  static const String _modelAssetPath =
      'assets/mobile_artifacts_int8/landmark_encoder.onnx';
  static const String _dataAssetPath =
      'assets/mobile_artifacts_int8/landmark_encoder.onnx.data';
  static const String _modelFileName = 'landmark_encoder.onnx';
  static const String _dataFileName = 'landmark_encoder.onnx.data';

  OrtSession? _session;
  Future<void>? _initializing;
  String? _lastInitError;

  Future<void> initializeOnnxModel() async {
    if (_session != null) return;
    if (_initializing != null) return _initializing!;

    _initializing = _initializeInternal();
    try {
      await _initializing!;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _initializeInternal() async {
    OrtSessionOptions? sessionOptions;
    try {
      _lastInitError = null;
      OrtEnv.instance.init();

      sessionOptions = OrtSessionOptions();
      sessionOptions.setInterOpNumThreads(1);
      sessionOptions.setIntraOpNumThreads(2);
      sessionOptions.setSessionGraphOptimizationLevel(
        GraphOptimizationLevel.ortEnableAll,
      );

      final modelFile = await _prepareModelFiles();
      _session = OrtSession.fromFile(modelFile, sessionOptions);
      print('ONNX session initialized: ${modelFile.path}');
    } catch (e, stackTrace) {
      _lastInitError = e.toString();
      print('ONNX initialization failed: $e');
      print(stackTrace);
      rethrow;
    } finally {
      sessionOptions?.release();
    }
  }

  Future<File> _prepareModelFiles() async {
    if (Platform.isAndroid) {
      final result =
          await _assetChannel.invokeMapMethod<String, String>(
            'prepareOnnxAssets',
          ) ??
          const {};
      final modelPath = result['modelPath'];
      if (modelPath == null || modelPath.isEmpty) {
        throw Exception('Android asset preparation returned no model path');
      }

      final modelFile = File(modelPath);
      final dataPath = result['dataPath'];
      if (!await modelFile.exists()) {
        throw Exception('Prepared ONNX model file is missing: $modelPath');
      }
      if (dataPath == null || !(await File(dataPath).exists())) {
        throw Exception('Prepared ONNX external data file is missing');
      }
      return modelFile;
    }

    final appDir = await getApplicationDocumentsDirectory();
    final modelFile = File('${appDir.path}/$_modelFileName');
    final dataFile = File('${appDir.path}/$_dataFileName');

    if (!await modelFile.exists()) {
      await _copyAsset(_modelAssetPath, modelFile);
    }
    if (!await dataFile.exists()) {
      await _copyAsset(_dataAssetPath, dataFile);
    }
    return modelFile;
  }

  Future<void> _copyAsset(String assetPath, File destination) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    await destination.writeAsBytes(bytes, flush: true);
  }

  void release() {
    _session?.release();
    _session = null;
    OrtEnv.instance.release();
  }

  bool get isInitialized => _session != null;
  String? get lastInitError => _lastInitError;

  Future<List<double>> extractEmbedding(Uint8List imageBytes) async {
    await initializeOnnxModel();
    if (_session == null) {
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

    const numPixels = _imageSize * _imageSize;
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

    final outputs = _session!.run(runOptions, {'image': tensor});
    final outputTensor = outputs[0]?.value as List<dynamic>;

    tensor.release();
    runOptions.release();
    for (final output in outputs) {
      output?.release();
    }

    final List<double> raw;
    if (outputTensor.isNotEmpty && outputTensor[0] is List) {
      raw = (outputTensor[0] as List)
          .map((e) => (e as num).toDouble())
          .toList();
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
}
