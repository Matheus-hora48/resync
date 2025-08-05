import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:ui' as ui;

/// Utilitário para compressão de imagens
class ImageCompressor {
  /// Comprime uma imagem mantendo qualidade aceitável
  static Future<File> compressImage(
    File imageFile, {
    int maxWidth = 1920,
    int maxHeight = 1080,
    int quality = 85,
    String? outputPath,
  }) async {
    try {
      // Lê os bytes da imagem
      final imageBytes = await imageFile.readAsBytes();

      // Decodifica a imagem
      final ui.Codec codec = await ui.instantiateImageCodec(
        imageBytes,
        targetWidth: maxWidth,
        targetHeight: maxHeight,
      );

      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      // Converte para PNG com compressão
      final ByteData? pngBytes = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (pngBytes == null) {
        throw Exception('Falha ao comprimir imagem');
      }

      // Define o caminho de saída
      final outputFile =
          outputPath != null
              ? File(outputPath)
              : File('${imageFile.path.split('.').first}_compressed.png');

      // Salva a imagem comprimida
      await outputFile.writeAsBytes(pngBytes.buffer.asUint8List());

      if (kDebugMode) {
        final originalSize = await imageFile.length();
        final compressedSize = await outputFile.length();
        final compressionRatio =
            ((originalSize - compressedSize) / originalSize * 100).round();

        debugPrint('Imagem comprimida:');
        debugPrint('Original: ${(originalSize / 1024).round()}KB');
        debugPrint('Comprimida: ${(compressedSize / 1024).round()}KB');
        debugPrint('Economia: $compressionRatio%');
      }

      return outputFile;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Erro ao comprimir imagem: $e');
      }
      // Retorna arquivo original se falhar na compressão
      return imageFile;
    }
  }

  /// Verifica se um arquivo é uma imagem
  static bool isImage(String filePath) {
    final extension = filePath.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png', 'webp', 'bmp', 'gif'].contains(extension);
  }

  /// Calcula o tamanho ideal baseado nas dimensões máximas
  static Map<String, int> calculateOptimalSize(
    int originalWidth,
    int originalHeight,
    int maxWidth,
    int maxHeight,
  ) {
    double ratio = 1.0;

    if (originalWidth > maxWidth) {
      ratio = maxWidth / originalWidth;
    }

    if (originalHeight * ratio > maxHeight) {
      ratio = maxHeight / originalHeight;
    }

    return {
      'width': (originalWidth * ratio).round(),
      'height': (originalHeight * ratio).round(),
    };
  }

  /// Comprime múltiplas imagens em lote
  static Future<List<File>> compressImages(
    List<File> imageFiles, {
    int maxWidth = 1920,
    int maxHeight = 1080,
    int quality = 85,
    void Function(int current, int total)? onProgress,
  }) async {
    final compressedFiles = <File>[];

    for (int i = 0; i < imageFiles.length; i++) {
      final file = imageFiles[i];

      if (isImage(file.path)) {
        final compressed = await compressImage(
          file,
          maxWidth: maxWidth,
          maxHeight: maxHeight,
          quality: quality,
        );
        compressedFiles.add(compressed);
      } else {
        compressedFiles.add(file); // Não é imagem, mantém original
      }

      onProgress?.call(i + 1, imageFiles.length);
    }

    return compressedFiles;
  }
}
