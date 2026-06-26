import 'package:flutter/material.dart';
import '../theme.dart';
import '../constants.dart';

class ProfileModal extends StatefulWidget {
  final Map<String, dynamic> profileData;
  final VoidCallback? onLike;
  final VoidCallback? onPass;

  const ProfileModal({
    super.key,
    required this.profileData,
    this.onLike,
    this.onPass,
  });

  static void show({
    required BuildContext context,
    required Map<String, dynamic> profile,
    VoidCallback? onLike,
    VoidCallback? onPass,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.voidBackground,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => ProfileModal(profileData: profile, onLike: onLike, onPass: onPass),
    );
  }

  @override
  State<ProfileModal> createState() => _ProfileModalState();
}

class _ProfileModalState extends State<ProfileModal> {
  final PageController _pageController = PageController();
  int _activePhoto = 0;

  @override
  Widget build(BuildContext context) {
    final p = widget.profileData;
    final List images = p['images'] ?? [];
    final List interests = p['interests'] ?? ['Design', 'Coffee', 'Travel'];

    // Dynamically calculate 45% of the screen height for images
    final double galleryHeight = MediaQuery.of(context).size.height * 0.45;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.88,
      child: Stack(
        children: [
          Column(
            children: [
              // Modal Grab Bar
              Container(margin: const EdgeInsets.symmetric(vertical: 12), height: 4, width: 40, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
              
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✅ FIX: Dynamic Photo Swipe Gallery Height
                      SizedBox(
                        height: galleryHeight,
                        child: Stack(
                          children: [
                            PageView.builder(
                              controller: _pageController,
                              itemCount: images.isEmpty ? 1 : images.length,
                              onPageChanged: (idx) => setState(() => _activePhoto = idx),
                              itemBuilder: (context, idx) {
                                if (images.isEmpty) return Container(color: Colors.white10, child: const Icon(Icons.person, size: 80, color: Colors.white24));
                                return Image.network(images[idx], fit: BoxFit.cover, width: double.infinity);
                              },
                            ),
                            if (images.length > 1)
                              Positioned(
                                bottom: 12, left: 0, right: 0,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(images.length, (i) => AnimatedContainer(
                                    duration: AppConstants.imageTransitionDuration,
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    width: _activePhoto == i ? 20 : 6, height: 6,
                                    decoration: BoxDecoration(color: _activePhoto == i ? AppTheme.electricCyan : Colors.white38, borderRadius: BorderRadius.circular(3)),
                                  )),
                                ),
                              )
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(child: Text('${p['first_name'] ?? 'User'}, ${p['age'] ?? 24}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Colors.white))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: AppTheme.electricCyan.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.electricCyan)),
                                  child: Text('${p['distance'] ?? 3} km away', style: const TextStyle(color: AppTheme.electricCyan, fontWeight: FontWeight.bold, fontSize: 12)),
                                )
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(p['location'] ?? 'Unknown Location', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                            
                            if (p['current_date_bid'] != null && p['current_date_bid'].toString().isNotEmpty) ...[
                              const SizedBox(height: 20),
                              Container(
                                width: double.infinity, padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(color: AppTheme.primaryRose.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.primaryRose.withValues(alpha: 0.5))),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('TONIGHT\'S BID', style: TextStyle(color: AppTheme.primaryRose, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                                    const SizedBox(height: 4),
                                    Text('"${p['current_date_bid']}"', style: const TextStyle(color: Colors.white, fontSize: 15, fontStyle: FontStyle.italic)),
                                  ],
                                ),
                              )
                            ],

                            const SizedBox(height: 24),
                            const Text('ABOUT ME', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                            const SizedBox(height: 8),
                            Text(
                              p['bio'] ?? 'No bio written yet.', 
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.87), fontSize: 16, height: 1.4)
                            ),

                            const SizedBox(height: 24),
                            const Text('INTERESTS', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8, runSpacing: 8,
                              children: interests.map((tag) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white12)),
                                child: Text(tag.toString(), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                              )).toList(),
                            ),
                            const SizedBox(height: 120), // Spacing for floating footer
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ✅ FIX: SafeArea on Action Buttons Footer
          if (widget.onLike != null && widget.onPass != null)
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                decoration: BoxDecoration(color: AppTheme.voidBackground, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 20, offset: const Offset(0, -10))]),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), side: const BorderSide(color: AppTheme.primaryRose, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                            onPressed: () { Navigator.pop(context); widget.onPass!(); },
                            child: const Text('PASS', style: TextStyle(color: AppTheme.primaryRose, fontWeight: FontWeight.w900, letterSpacing: 2)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.electricCyan, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                            onPressed: () { Navigator.pop(context); widget.onLike!(); },
                            child: const Text('ALIGN', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, letterSpacing: 2)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
        ],
      ),
    );
  }
}