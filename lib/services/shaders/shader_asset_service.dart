import 'dart:io';

import 'package:flutter/services.dart' show rootBundle, AssetManifest;
import 'package:flutter/foundation.dart' show listEquals;
import 'package:kazumi/services/logging/logger.dart';
import 'package:kazumi/pages/player/controller/player_super_resolution.dart';
import 'package:kazumi/services/shaders/fixed_scale_shaders.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class ShaderAssetService {
  late Directory shadersDirectory;

  Future<void> copyShadersToExternalDirectory() async {
    final assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = assetManifest.listAssets();
    final directory = await getApplicationSupportDirectory();
    shadersDirectory = Directory(path.join(directory.path, 'anime_shaders_v2'));

    if (!await shadersDirectory.exists()) {
      await shadersDirectory.create(recursive: true);
      KazumiLogger().i(
        'ShaderManager: Create GLSL Shader: ${shadersDirectory.path}',
      );
    }

    final shaderFiles = assets.where(
      (String asset) =>
          asset.startsWith('assets/shaders/') && asset.endsWith('.glsl'),
    );

    int copiedFilesCount = 0;

    for (var filePath in shaderFiles) {
      final fileName = filePath.split('/').last;
      final targetFile = File(path.join(shadersDirectory.path, fileName));
      try {
        final data = await rootBundle.load(filePath);
        final List<int> bytes = data.buffer.asUint8List();
        if (await targetFile.exists()) {
          final existing = await targetFile.readAsBytes();
          if (listEquals(existing, bytes)) {
            continue;
          }
        }
        await targetFile.writeAsBytes(bytes, flush: true);
        copiedFilesCount++;
        KazumiLogger().i('ShaderManager: Copy: ${targetFile.path}');
      } catch (e) {
        KazumiLogger().e('ShaderManager: Copy: ($filePath)', error: e);
      }
    }

    // Generate fixed variants from the bundled models to keep their weights
    // identical to auto mode. Always refresh generated files on startup.
    try {
      for (final size in ['S', 'M', 'VL']) {
        final source = await rootBundle.loadString(
          'assets/shaders/Anime4K_Upscale_CNN_x2_$size.glsl',
        );
        await File(
          path.join(shadersDirectory.path, fixedUpscaleName(size)),
        ).writeAsString(fixedUpscaleShader(source), flush: true);
      }
      for (final scale in [
        SuperResolutionScale.x1_5,
        SuperResolutionScale.x3,
      ]) {
        await File(
          path.join(shadersDirectory.path, fixedResizeName(scale)),
        ).writeAsString(fixedResizeShader(scale), flush: true);
      }
    } catch (e) {
      // A fixed-mode resource failure must not prevent normal playback/startup.
      // The controller checks files before applying a chain.
      KazumiLogger().e('ShaderManager: Generate fixed shaders', error: e);
    }

    KazumiLogger().i(
      'ShaderManager: $copiedFilesCount GLSL files copied to ${shadersDirectory.path}',
    );
  }
}
