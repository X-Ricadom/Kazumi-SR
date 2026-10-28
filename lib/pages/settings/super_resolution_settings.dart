import 'package:flutter/material.dart';
import 'package:kazumi/bean/settings/settings_detail_scaffold.dart';
import 'package:kazumi/pages/player/controller/player_super_resolution.dart';
import 'package:kazumi/services/storage/storage.dart';
import 'package:kazumi/bean/settings/settings_list.dart';

class SuperResolutionSettings extends StatefulWidget {
  const SuperResolutionSettings({super.key});

  @override
  State<SuperResolutionSettings> createState() =>
      _SuperResolutionSettingsState();
}

class _SuperResolutionSettingsState extends State<SuperResolutionSettings> {
  late bool disableWarning;
  late SuperResolutionMode superResolutionMode;
  late SuperResolutionScale superResolutionScale;

  @override
  void initState() {
    super.initState();
    disableWarning = GStorage.getSetting<bool>(
      SettingsKeys.disableSuperResolutionWarning,
    );
    superResolutionScale = SuperResolutionScale.fromStorageValue(
      GStorage.getSetting(SettingsKeys.defaultSuperResolutionScale),
    );
    superResolutionMode = SuperResolutionMode.fromStorageValue(
      GStorage.getSetting<int>(SettingsKeys.defaultSuperResolutionMode),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsDetailScaffold(
      title: const Text('超分辨率'),
      body: SettingsList(
        sections: [
          SettingsRadioSection<SuperResolutionMode>(
            title: Text('超分辨率需要启用硬件解码, 若启用硬件解码后仍然不生效, 尝试切换视频渲染器为 gpu'),
            groupValue: superResolutionMode,
            onChanged: (SuperResolutionMode? value) {
              if (value == null) return;
              GStorage.putSetting<int>(
                SettingsKeys.defaultSuperResolutionMode,
                value.storageValue,
              );
              setState(() {
                superResolutionMode = value;
              });
            },
            tiles: [
              for (final mode in SuperResolutionMode.values)
                SettingsTile<SuperResolutionMode>.radioTile(
                  title: Text(mode.label),
                  description: Text(mode.description),
                  radioValue: mode,
                ),
            ],
          ),
          SettingsRadioSection<SuperResolutionScale>(
            title: const Text('默认处理倍率（启用超分后生效）'),
            groupValue: superResolutionScale,
            onChanged: (value) async {
              if (value == null) return;
              await GStorage.putSetting(
                SettingsKeys.defaultSuperResolutionScale,
                value.storageValue,
              );
              if (mounted) setState(() => superResolutionScale = value);
            },
            tiles: [
              for (final scale in SuperResolutionScale.values)
                SettingsTile<SuperResolutionScale>.radioTile(
                  title: Text(scale.label),
                  description: Text(switch (scale) {
                    SuperResolutionScale.auto => '根据实际显示尺寸自动处理，保持原有行为',
                    SuperResolutionScale.x1_5 => '720p → 1080p：先 2× 超分，再缩小',
                    SuperResolutionScale.x2 => '720p → 1440p：一次 2× 超分',
                    SuperResolutionScale.x3 =>
                      '720p → 2160p：两次 2× 超分，再缩小，开销接近 4×',
                    SuperResolutionScale.x4 => '720p → 2880p：两次 2× 超分，GPU 开销较高',
                  }),
                  radioValue: scale,
                ),
            ],
          ),
          SettingsSection(
            title: Text('默认行为'),
            tiles: [
              SettingsTile.switchTile(
                leading: Icons.notifications_off_rounded,
                title: Text('关闭提示'),
                description: Text('关闭每次启用超分辨率时的提示'),
                initialValue: disableWarning,
                onToggle: (value) async {
                  disableWarning = value ?? !disableWarning;
                  await GStorage.putSetting<bool>(
                    SettingsKeys.disableSuperResolutionWarning,
                    disableWarning,
                  );
                  if (mounted) setState(() {});
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
