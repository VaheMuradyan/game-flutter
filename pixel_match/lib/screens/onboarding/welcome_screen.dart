import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _checkedAutoLogin = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_checkedAutoLogin) {
      _checkedAutoLogin = true;
      Provider.of<AuthProvider>(context, listen: false).tryAutoLogin();
    }
  }

  void _showAuthSheet(BuildContext context, {required bool isSignUp}) {
    _emailCtrl.clear();
    _passCtrl.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isSignUp ? 'CREATE ACCOUNT' : 'LOG IN',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 24),
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passCtrl,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  if (auth.isLoading) return const CircularProgressIndicator();
                  return Column(
                    children: [
                      if (auth.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(auth.errorMessage!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                        ),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            final email = _emailCtrl.text.trim();
                            final pass = _passCtrl.text.trim();
                            bool success;
                            if (isSignUp) {
                              success = await auth.register(email, pass);
                            } else {
                              success = await auth.login(email, pass);
                            }
                            if (success && context.mounted) {
                              Navigator.of(context).pop();
                              if (auth.isOnboarded) {
                                context.go('/home');
                              } else {
                                context.go('/onboarding/class');
                              }
                            }
                          },
                          child: Text(isSignUp ? 'SIGN UP' : 'LOG IN'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  width: 128,
                  height: 128,
                  filterQuality: FilterQuality.none,
                ),
                const SizedBox(height: 16),
                Text('PIXELMATCH',
                    style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 8),
                Text('Level up your love life',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _showAuthSheet(context, isSignUp: true),
                    child: const Text('SIGN UP'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _showAuthSheet(context, isSignUp: false),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.secondaryColor),
                      foregroundColor: AppTheme.secondaryColor,
                    ),
                    child: const Text('LOG IN'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
