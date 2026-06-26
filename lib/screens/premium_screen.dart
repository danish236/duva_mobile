import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme.dart';
import '../constants.dart'; // Make sure you created this file!

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  // 1 = 1 Month, 3 = 3 Months. Default to 1 Month selected.
  int _selectedPlan = 1; 

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.voidBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // --- Ambient Background Glow ---
          Positioned(
            top: -100, right: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.primaryRose.withValues(alpha: 0.15)),
            ),
          ),
          Positioned(
            bottom: -100, left: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.electricCyan.withValues(alpha: 0.15)),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
            child: Container(color: Colors.transparent),
          ),

          // --- Main Content ---
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 120, top: 20), // Padding for the fixed button
              child: Column(
                children: [
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(colors: [AppTheme.electricCyan, AppTheme.primaryRose]).createShader(bounds),
                    child: const Icon(Icons.diamond, size: 80, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'DUVA BLACK',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 3),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Elevate your alignment.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16, letterSpacing: 1.5),
                  ),
                  
                  const SizedBox(height: 40),

                  // --- Feature List ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Column(
                      children: [
                        _buildFeatureRow(Icons.visibility, 'See Who Likes You', 'Unlock the Admirers Lounge.'),
                        _buildFeatureRow(Icons.replay, 'Unlimited Rewinds', 'Undo accidental passes instantly.'),
                        _buildFeatureRow(Icons.done_all, 'Read Receipts', 'Know when they read your messages.'),
                        _buildFeatureRow(Icons.tune, 'Advanced Filters', 'Filter by height, zodiac & lifestyle.'),
                        _buildFeatureRow(Icons.all_inclusive, 'Infinite Alignments', 'Swipe without daily limits.'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // --- Selectable Pricing Cards ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildPricingCard(
                            months: 1, 
                            price: AppConstants.premium1MonthPrice, 
                            title: '1 Month', 
                            badge: null
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildPricingCard(
                            months: 3, 
                            price: AppConstants.premium3MonthsPrice, 
                            title: '3 Months', 
                            badge: 'SAVE 33%'
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- Fixed Bottom Action Button ---
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [AppTheme.voidBackground, AppTheme.voidBackground.withValues(alpha: 0.8), Colors.transparent],
                )
              ),
              child: SafeArea(
                top: false,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [BoxShadow(color: AppTheme.primaryRose.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 5))]
                  ),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      backgroundColor: Colors.transparent, 
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ).copyWith(backgroundColor: WidgetStateProperty.all(Colors.transparent)),
                    onPressed: _processPayment,
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppTheme.primaryRose, AppTheme.electricCyan]),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: Text(
                          'CONTINUE WITH ${_selectedPlan == 1 ? "1 MONTH" : "3 MONTHS"}', 
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.5)
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget to build the feature rows
  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.surfaceGlass, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.white12)),
            child: Icon(icon, color: AppTheme.electricCyan, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
              ],
            ),
          )
        ],
      ),
    );
  }

  // Helper widget to build the side-by-side pricing cards
  Widget _buildPricingCard({required int months, required double price, required String title, String? badge}) {
    final bool isSelected = _selectedPlan == months;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlan = months;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryRose.withValues(alpha: 0.1) : AppTheme.surfaceGlass,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.primaryRose : Colors.white12, width: isSelected ? 2 : 1),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                Text(title, style: TextStyle(color: isSelected ? AppTheme.primaryRose : Colors.white70, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                const SizedBox(height: 12),
                Text('${AppConstants.currencySymbol}${price.toInt()}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text('billed total', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11)),
              ],
            ),
            if (badge != null)
              Positioned(
                top: -32, left: 0, right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: AppTheme.electricCyan, borderRadius: BorderRadius.circular(10)),
                    child: Text(badge, style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900)),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }

  // Dummy function for future payment gateway
  void _processPayment() {
    final double priceToCharge = _selectedPlan == 1 ? AppConstants.premium1MonthPrice : AppConstants.premium3MonthsPrice;
    
    // TODO: Implement Razorpay / Stripe / RevenueCat here
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Initializing gateway for ${AppConstants.currencySymbol}${priceToCharge.toInt()}...'))
    );
  }
}