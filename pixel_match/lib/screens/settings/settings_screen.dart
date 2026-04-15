import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/audio_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _loading = true;
  bool _music = true;
  bool _sfx = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await AudioService.instance.init();
    setState(() {
      _music = AudioService.instance.musicEnabled;
      _sfx = AudioService.instance.sfxEnabled;
      _loading = false;
    });
  }

  Future<void> _setMusic(bool value) async {
    setState(() => _music = value);
    await AudioService.instance.setMusicEnabled(value);
  }

  Future<void> _setSfx(bool value) async {
    setState(() => _sfx = value);
    await AudioService.instance.setSfxEnabled(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SETTINGS'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const _SectionHeader(text: 'AUDIO'),
                _ToggleTile(
                  label: 'MUSIC',
                  icon: Icons.music_note,
                  value: _music,
                  onChanged: _setMusic,
                ),
                _ToggleTile(
                  label: 'SOUND EFFECTS',
                  icon: Icons.graphic_eq,
                  value: _sfx,
                  onChanged: _setSfx,
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Audio respects your device mute switch.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: AppTheme.accentGold, fontSize: 10),
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.surfaceColor,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: SwitchListTile.adaptive(
        secondary: Icon(icon, color: AppTheme.accentGold),
        title: Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(fontSize: 12),
        ),
        value: value,
        activeThumbColor: AppTheme.primaryColor,
        onChanged: onChanged,
      ),
    );
  }
}
