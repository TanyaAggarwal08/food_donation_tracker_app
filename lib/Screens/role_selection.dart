import 'package:flutter/material.dart';
import 'package:test1/services/NotificationService.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class RoleSelectionScreen extends StatelessWidget {const RoleSelectionScreen({super.key});

@override
Widget build(BuildContext context) {
  return Scaffold(
    // --- Enhancement 1: Gradient Background ---
    body: Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.green.shade50,
            Colors.grey.shade200,
          ],
        ),
      ),
      child: SafeArea(
        child: AnimationLimiter( // Wrapper for animations
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: AnimationConfiguration.toStaggeredList(
              duration: const Duration(milliseconds: 400),
              childAnimationBuilder: (widget) => SlideAnimation(
                verticalOffset: 50.0,
                child: FadeInAnimation(child: widget),
              ),
              children: [
                const Spacer(flex: 2),
                // --- App Logo and Title Section ---
                Icon(
                  Icons.food_bank_rounded,
                  size: 80,
                  color: Colors.green.shade800,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Food Donation Tracker',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    // You can experiment with Google Fonts for a more custom feel
                    // fontFamily: 'Poppins',
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Monitor Donations, Maximize Use',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Please select your role to continue',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black54,
                  ),
                ),
                const Spacer(flex: 1),

                // --- Role Selection Cards ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: RoleCard(
                    label: 'Volunteer',
                    description: 'Collect and deliver donations',
                    icon: Icons.delivery_dining_rounded,
                    color: Colors.blue.shade700,
                    routeRole: 'Volunteer',
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: RoleCard(
                    label: 'Store Owner',
                    description: 'Manage your store and donations',
                    icon: Icons.store_mall_directory_rounded,
                    color: Colors.orange.shade800,
                    routeRole: 'StoreOwner',
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: RoleCard(
                    label: 'Admin',
                    description: 'Oversee operations and data',
                    icon: Icons.admin_panel_settings_rounded,
                    color: Colors.green.shade800,
                    routeRole: 'Admin',
                  ),
                ),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}

/// A custom, reusable widget for the role selection cards.
class RoleCard extends StatelessWidget {
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final String routeRole;

  const RoleCard({
    super.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.routeRole,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      // --- Enhancement 2: Better Shadows and Border ---
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pushNamed(context, '/auth', arguments: {'role': routeRole});
        },
        borderRadius: BorderRadius.circular(16),
        splashColor: color.withOpacity(0.2),
        highlightColor: color.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 30),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600, // Slightly less heavy than bold
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
