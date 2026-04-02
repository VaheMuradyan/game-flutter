import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';

class ClassSelectionScreen extends StatelessWidget {
  const ClassSelectionScreen({super.key});

  static const Map<String, Map<String, String>> classInfo = {
    'Warrior': {'style': 'Tank, defensive', 'hint': 'Strong, protective, reliable', 'icon': '🛡️'},
    'Mage': {'style': 'Spells, clever combos', 'hint': 'Intellectual, creative, strategic', 'icon': '🔮'},
    'Archer': {'style': 'Fast, hit-and-run', 'hint': 'Adventurous, free-spirited', 'icon': '🏹'},
    'Rogue': {'style': 'Tricks, sneaky plays', 'hint': 'Mysterious, spontaneous', 'icon': '🗡️'},
    'Healer': {'style': 'Support, team-focused', 'hint': 'Caring, empathetic, nurturing', 'icon': '💚'},
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CHOOSE YOUR CLASS'),
        centerTitle: true,
        backgroundColor: Colors.transparent, elevation: 0,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text('Your class hints at your personality',
                    style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: AppConstants.characterClasses.length,
                    itemBuilder: (context, index) {
                      final cls = AppConstants.characterClasses[index];
                      final info = classInfo[cls]!;
                      final isSelected = auth.selectedClass == cls;
                      return GestureDetector(
                        onTap: () => auth.setSelectedClass(cls),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.primaryColor.withOpacity(0.2)
                                : AppTheme.surfaceColor,
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryColor : Colors.transparent,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Text(info['icon']!, style: const TextStyle(fontSize: 32)),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(cls, style: Theme.of(context).textTheme.bodyLarge),
                                    const SizedBox(height: 4),
                                    Text(info['style']!, style: Theme.of(context).textTheme.bodyMedium),
                                    Text(info['hint']!,
                                        style: Theme.of(context).textTheme.bodyMedium
                                            ?.copyWith(color: AppTheme.accentGold)),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle, color: AppTheme.primaryColor),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: auth.selectedClass.isEmpty
                        ? null
                        : () => context.go('/onboarding/profile'),
                    child: const Text('NEXT'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
