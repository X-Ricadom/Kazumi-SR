import 'package:kazumi/pages/player/controller/player_super_resolution.dart';

/// Fixed variants retain the trained x2 reconstruction, but do not let the
/// viewport decide whether a CNN stage runs. Original assets remain untouched.
String fixedUpscaleShader(String source) => source
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//!WHEN'))
    .join('\n');

String fixedUpscaleName(String size) => 'Kazumi_Fixed_Upscale_x2_$size.glsl';

String fixedResizeName(SuperResolutionScale scale) =>
    'Kazumi_Fixed_Resize_${scale.storageValue}.glsl';

String fixedResizeShader(SuperResolutionScale scale) {
  final factor = scale.factor;
  if (factor == null) throw ArgumentError('Auto has no fixed target size');
  return '''//!DESC Kazumi fixed processing size ${scale.label}
//!HOOK MAIN
//!BIND HOOKED
//!BIND NATIVE
//!SAVE MAIN
//!WIDTH NATIVE.w $factor *
//!HEIGHT NATIVE.h $factor *

vec4 hook() {
    return HOOKED_tex(HOOKED_pos);
}
''';
}

List<String> fixedScaleShaderChain(
  SuperResolutionMode mode,
  SuperResolutionScale scale,
) {
  if (mode == SuperResolutionMode.off) return const [];
  if (scale == SuperResolutionScale.auto) {
    throw ArgumentError('Use the original chain for auto');
  }
  final quality = mode == SuperResolutionMode.quality;
  return [
    'Anime4K_Clamp_Highlights.glsl',
    if (quality) 'Anime4K_Restore_CNN_VL.glsl',
    if (!quality) ...[
      'Anime4K_Restore_CNN_M.glsl',
      'Anime4K_Restore_CNN_S.glsl',
    ],
    fixedUpscaleName(quality ? 'VL' : 'M'),
    if (scale.factor! > 2) fixedUpscaleName(quality ? 'M' : 'S'),
    // For 2x and 4x the CNN already produces the requested size.
    if (scale == SuperResolutionScale.x1_5 || scale == SuperResolutionScale.x3)
      fixedResizeName(scale),
  ];
}
