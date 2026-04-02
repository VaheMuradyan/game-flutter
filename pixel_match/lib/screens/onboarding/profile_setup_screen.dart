import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameCtrl = TextEditingController();

  Future<void> _finish() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final success = await auth.completeOnboarding(name);
    if (success && mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SET UP PROFILE'),
        centerTitle: true,
        backgroundColor: Colors.transparent, elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 56,
              backgroundColor: AppTheme.surfaceColor,
              child: const Icon(Icons.person, size: 48, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Text('Photo upload coming soon',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                hintText: 'What should others call you?',
              ),
              maxLength: 20,
            ),
            const Spacer(),
            Consumer<AuthProvider>(
              builder: (context, auth, _) {
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : _finish,
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('START BATTLING'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
