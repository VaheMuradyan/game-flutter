import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../config/api_client.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});
  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _isPremium = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      final resp = await ApiClient.get('/api/premium/status');
      if (!mounted) return;
      setState(() {
        _isPremium = resp['isPremium'] as bool? ?? false;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _activate() async {
    try {
      await ApiClient.post(
        '/api/premium/activate',
        {'activationCode': 'PREMIUM2024'},
      );
      if (!mounted) return;
      setState(() => _isPremium = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Activation failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('PREMIUM')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    _isPremium ? Icons.star : Icons.star_border,
                    size: 64,
                    color: AppTheme.accentGold,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isPremium ? 'You are Premium!' : 'Go Premium',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  _featureRow(Icons.all_inclusive, 'Unlimited daily swipes'),
                  _featureRow(Icons.speed, 'Priority battle queue'),
                  _featureRow(Icons.verified, 'Premium profile badge'),
                  const SizedBox(height: 32),
                  if (!_isPremium)
                    ElevatedButton(
                      onPressed: _activate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentGold,
                        foregroundColor: Colors.black,
                        minimumSize: const Size(double.infinity, 56),
                      ),
                      child: const Text('ACTIVATE PREMIUM'),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _featureRow(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(icon, color: AppTheme.accentGold, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ]),
      );
}
