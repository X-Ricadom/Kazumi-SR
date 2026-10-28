import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kazumi/pages/player/controller/player_super_resolution.dart';
import 'package:kazumi/services/shaders/fixed_scale_shaders.dart';

void main() {
  test('old or unknown scale settings keep automatic behavior', () {
    expect(
      SuperResolutionScale.fromStorageValue('unknown'),
      SuperResolutionScale.auto,
    );
    for (final scale in SuperResolutionScale.values) {
      expect(SuperResolutionScale.fromStorageValue(scale.storageValue), scale);
    }
  });

  test('fixed targets use source dimensions, not viewport dimensions', () {
    for (final scale in [SuperResolutionScale.x1_5, SuperResolutionScale.x3]) {
      final shader = fixedResizeShader(scale);
      expect(shader, contains('//!WIDTH NATIVE.w ${scale.factor} *'));
      expect(shader, contains('//!HEIGHT NATIVE.h ${scale.factor} *'));
      expect(shader, isNot(contains('OUTPUT')));
    }
    expect(
      () => fixedResizeShader(SuperResolutionScale.auto),
      throwsArgumentError,
    );
  });

  test('fixed variants preserve CNN weights and x2 reconstruction', () {
    for (final size in ['S', 'M', 'VL']) {
      final source = File(
        'assets/shaders/Anime4K_Upscale_CNN_x2_$size.glsl',
      ).readAsStringSync();
      final fixed = fixedUpscaleShader(source);
      expect(source, contains('//!WHEN OUTPUT'));
      expect(fixed, isNot(contains('//!WHEN')));
      expect(fixed, contains('//!WIDTH conv2d_last_tf.w 2 *'));
      expect(fixed, contains('//!HEIGHT conv2d_last_tf.h 2 *'));
      // Only conditional metadata may change; executable model code is identical.
      String code(String text) => text
          .split('\n')
          .where((line) => !line.trimLeft().startsWith('//!'))
          .join('\n');
      expect(code(fixed), code(source));
    }
  });

  test(
    'every fixed chain has the required stages and available source models',
    () {
      for (final mode in SuperResolutionMode.values) {
        for (final scale in SuperResolutionScale.values.skip(1)) {
          final chain = fixedScaleShaderChain(mode, scale);
          if (mode == SuperResolutionMode.off) {
            expect(chain, isEmpty);
            continue;
          }
          final cnn = chain.where(
            (name) => name.startsWith('Kazumi_Fixed_Upscale'),
          );
          expect(cnn.length, scale.factor! > 2 ? 2 : 1);
          expect(
            chain.where((name) => name.contains('Resize')).length,
            [SuperResolutionScale.x1_5, SuperResolutionScale.x3].contains(scale)
                ? 1
                : 0,
          );
          expect(chain.any((name) => name.contains('AutoDownscale')), isFalse);
          for (final name in chain) {
            if (name.startsWith('Anime4K')) {
              expect(File('assets/shaders/$name').existsSync(), isTrue);
            }
          }
          expect(
            cnn.first,
            fixedUpscaleName(mode == SuperResolutionMode.quality ? 'VL' : 'M'),
          );
        }
      }
      expect(
        () => fixedScaleShaderChain(
          SuperResolutionMode.quality,
          SuperResolutionScale.auto,
        ),
        throwsArgumentError,
      );
    },
  );
}
