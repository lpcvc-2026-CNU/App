import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Python inference.py assess_image_quality() 와 동일한 로직
class ImageQualityService {
  Map<String, dynamic> assessImageQuality(Uint8List imageBytes) {
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      return {
        'ok': false,
        'reason_codes': ['invalid_image'],
        'metrics': {}
      };
    }

    final int w = image.width;
    final int h = image.height;
    final int minSide = w < h ? w : h;

    // Grayscale 변환
    final grayscale = img.grayscale(image);
    final int n = w * h;

    // Brightness: 픽셀 평균 (0~255)
    double sum = 0.0;
    final bytes = grayscale.getBytes(order: img.ChannelOrder.red);
    // getBytes(order: red) → grayscale 이미지의 경우 각 픽셀의 R 채널 = gray 값
    for (int i = 0; i < bytes.length; i += grayscale.numChannels) {
      sum += bytes[i];
    }
    final double brightness = sum / n;

    // Contrast: 표준편차 (Python: gray.std())
    double sumSq = 0.0;
    for (int i = 0; i < bytes.length; i += grayscale.numChannels) {
      final double d = bytes[i] - brightness;
      sumSq += d * d;
    }
    final double contrast = sqrt(sumSq / n);

    // Sharpness: Gradient magnitude 평균 (Python: np.gradient 근사)
    // Sobel 근사: 인접 픽셀 차이의 제곱합 평균
    double sharpnessSum = 0.0;
    int sharpnessCount = 0;
    for (int cy = 1; cy < h - 1; cy++) {
      for (int cx = 1; cx < w - 1; cx++) {
        // 간단한 x/y 그래디언트 (Python np.gradient 근사)
        final double gx = (grayscale.getPixel(cx + 1, cy).r - grayscale.getPixel(cx - 1, cy).r) / 2.0;
        final double gy = (grayscale.getPixel(cx, cy + 1).r - grayscale.getPixel(cx, cy - 1).r) / 2.0;
        sharpnessSum += gx * gx + gy * gy;
        sharpnessCount++;
      }
    }
    final double sharpness = sharpnessCount > 0 ? sharpnessSum / sharpnessCount : 0.0;

    // Python과 동일한 임계값 기준
    final List<String> reasons = [];
    if (minSide < 128) reasons.add('too_small');
    if (brightness < 25.0) reasons.add('too_dark');
    if (brightness > 245.0 && contrast < 10.0) reasons.add('too_bright');
    if (contrast < 5.0) reasons.add('low_contrast');
    if (sharpness < 1.5 && minSide >= 128) reasons.add('blur_detected');

    return {
      'ok': reasons.isEmpty,
      'reason_codes': reasons,
      'metrics': {
        'min_side': minSide,
        'brightness': brightness,
        'contrast': contrast,
        'sharpness': sharpness,
      }
    };
  }
}
