import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme.dart';

class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.voidBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background ambient glow
          Positioned(
            top: -100, right: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryRose.withValues(alpha: 0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -100, left: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.electricCyan.withValues(alpha: 0.15),
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: Container(color: Colors.transparent),
          ),

          // Content
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(colors: [AppTheme.electricCyan, AppTheme.primaryRose]).createShader(bounds),
                  child: const Icon(Icons.diamond, size: 120, color: Colors.white),
                ),
                const SizedBox(height: 32),
                const Text(
                  'ELEVATE YOUR\nALIGNMENT',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: 2, height: 1.1),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Text(
                    'See who likes you, undo accidental passes, and get priority visibility in the pool.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.8), fontSize: 16, height: 1.5),
                  ),
                ),
                const SizedBox(height: 48),
                
                // Animated Premium Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(color: AppTheme.primaryRose.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 10))
                      ]
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        backgroundColor: Colors.transparent, // Let gradient show
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ).copyWith(
                        backgroundColor: WidgetStateProperty.all(Colors.transparent),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Premium features coming soon.')));
                      },
                      child: Ink(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppTheme.primaryRose, AppTheme.electricCyan]),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Container(
                          alignment: Alignment.center,
                          child: const Text('UNLOCK DUVA BLACK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}