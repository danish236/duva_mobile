import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'onboarding_screen.dart';
import 'info_screen.dart';
import '../theme.dart';
import '../messages.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _consentAge = false;
  bool _consentTerms = false;
  bool _consentPrivacy = false;
  bool _consentGuidelines = false;
  bool _consentDataProcessing = false;
  int _passwordStrength = 0; 

  late AnimationController _btnController;
  late Animation<double> _btnScale;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_checkPasswordStrength);
    _btnController = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _btnScale = Tween<double>(begin: 1.0, end: 0.95).animate(CurvedAnimation(parent: _btnController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _btnController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength() {
    String password = _passwordController.text;
    final hasUpperCase = password.contains(RegExp(r'[A-Z]'));
    final hasLowerCase = password.contains(RegExp(r'[a-z]'));
    final hasDigit = password.contains(RegExp(r'[0-9]'));
    final hasSpecial = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    if (password.isEmpty) setState(() => _passwordStrength = 0);
    else if (password.length < 8) setState(() => _passwordStrength = 1);
    else if (password.length >= 8 && !(hasUpperCase && hasLowerCase && hasDigit)) setState(() => _passwordStrength = 2);
    else if (password.length >= 8 && hasUpperCase && hasLowerCase && hasDigit && !hasSpecial) setState(() => _passwordStrength = 3);
    else setState(() => _passwordStrength = 4);
  }

  Color _getStrengthColor() {
    if (_passwordStrength == 1) return Colors.redAccent;
    if (_passwordStrength == 2) return Colors.orangeAccent;
    if (_passwordStrength == 3) return AppTheme.electricCyan;
    if (_passwordStrength == 4) return Colors.greenAccent;
    return AppTheme.surfaceGlass;
  }

  String _getStrengthText() {
    if (_passwordStrength == 1) return Messages.passwordStrengthTooShort;
    if (_passwordStrength == 2) return Messages.passwordStrengthWeak;
    if (_passwordStrength == 3) return Messages.passwordStrengthGood;
    if (_passwordStrength == 4) return Messages.passwordStrengthSecure;
    return Messages.passwordStrengthHint;
  }

  List<Widget> _buildConsentCheckbox({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required TextSpan text,
  }) {
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 24, width: 24,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: AppTheme.electricCyan,
              checkColor: Colors.black,
              side: const BorderSide(color: Colors.white38),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.8), fontSize: 12, height: 1.5),
                children: [text],
              ),
            ),
          ),
        ],
      ),
    ];
  }

  Future<void> _saveConsent() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      await Supabase.instance.client.from('user_consents').upsert({
        'user_id': user.id,
        'age_consent': true,
        'terms_accepted': true,
        'privacy_accepted': true,
        'guidelines_accepted': true,
        'data_processing_accepted': true,
        'terms_accepted_at': DateTime.now().toUtc().toIso8601String(),
        'privacy_accepted_at': DateTime.now().toUtc().toIso8601String(),
        'guidelines_accepted_at': DateTime.now().toUtc().toIso8601String(),
        'data_processing_accepted_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<void> _signUp() async {
    if (_passwordStrength < 3) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Messages.weakPassword)));
      return;
    }

    if (!(_consentAge && _consentTerms && _consentPrivacy && _consentGuidelines && _consentDataProcessing)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Messages.mustAcceptAll)));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signUp(email: _emailController.text.trim(), password: _passwordController.text.trim());
      await _saveConsent();
      if (!mounted) return;
      Navigator.pushReplacement(context, PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const OnboardingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
      ));
    } on AuthException catch (e) {
      String msg;
      switch (e.message) {
        case 'User already registered':
          msg = Messages.emailAlreadyExists;
          break;
        case 'Password should be at least 6 characters':
          msg = Messages.passwordTooShort;
          break;
        default:
          msg = Messages.authFailed;
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(Messages.somethingWentWrong)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.voidBackground,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(colors: [AppTheme.electricCyan, AppTheme.primaryRose]).createShader(bounds),
                child: Text(Messages.registerTitle, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
              ),
              const SizedBox(height: 8),
              Text(Messages.registerSubtitle, style: TextStyle(color: AppTheme.textSecondary.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              const SizedBox(height: 60),
              
              TextField(
                controller: _emailController, 
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(labelText: 'Email Address', prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textSecondary))
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textSecondary),
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: AppTheme.textSecondary),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Neon Strength Bars
              Row(
                children: [
                  Expanded(child: AnimatedContainer(duration: const Duration(milliseconds: 300), height: 4, decoration: BoxDecoration(color: _passwordStrength >= 1 ? _getStrengthColor() : AppTheme.surfaceGlass, borderRadius: BorderRadius.circular(2), boxShadow: _passwordStrength >= 1 ? [BoxShadow(color: _getStrengthColor().withValues(alpha: 0.5), blurRadius: 4)] : []))),
                  const SizedBox(width: 4),
                  Expanded(child: AnimatedContainer(duration: const Duration(milliseconds: 300), height: 4, decoration: BoxDecoration(color: _passwordStrength >= 2 ? _getStrengthColor() : AppTheme.surfaceGlass, borderRadius: BorderRadius.circular(2), boxShadow: _passwordStrength >= 2 ? [BoxShadow(color: _getStrengthColor().withValues(alpha: 0.5), blurRadius: 4)] : []))),
                  const SizedBox(width: 4),
                  Expanded(child: AnimatedContainer(duration: const Duration(milliseconds: 300), height: 4, decoration: BoxDecoration(color: _passwordStrength >= 3 ? _getStrengthColor() : AppTheme.surfaceGlass, borderRadius: BorderRadius.circular(2), boxShadow: _passwordStrength >= 3 ? [BoxShadow(color: _getStrengthColor().withValues(alpha: 0.5), blurRadius: 4)] : []))),
                  const SizedBox(width: 4),
                  Expanded(child: AnimatedContainer(duration: const Duration(milliseconds: 300), height: 4, decoration: BoxDecoration(color: _passwordStrength >= 4 ? _getStrengthColor() : AppTheme.surfaceGlass, borderRadius: BorderRadius.circular(2), boxShadow: _passwordStrength >= 4 ? [BoxShadow(color: _getStrengthColor().withValues(alpha: 0.5), blurRadius: 4)] : []))),
                ],
              ),
              const SizedBox(height: 12),
              Text(_getStrengthText(), style: TextStyle(color: _passwordStrength == 0 ? AppTheme.textSecondary.withValues(alpha: 0.6) : _getStrengthColor(), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2)),

              const SizedBox(height: 24),

              // Multi-checkbox Consent Form
              ..._buildConsentCheckbox(
                value: _consentAge,
                onChanged: (v) => setState(() => _consentAge = v),
                text: TextSpan(text: Messages.consentAgeCheck),
              ),
              const SizedBox(height: 8),
              ..._buildConsentCheckbox(
                value: _consentTerms,
                onChanged: (v) => setState(() => _consentTerms = v),
                text: TextSpan(
                  children: [
                    TextSpan(text: Messages.consentTerms),
                    TextSpan(
                      text: Messages.termsLink,
                      style: const TextStyle(color: AppTheme.electricCyan, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                      recognizer: TapGestureRecognizer()..onTap = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InfoScreen(docType: 'terms'))),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ..._buildConsentCheckbox(
                value: _consentPrivacy,
                onChanged: (v) => setState(() => _consentPrivacy = v),
                text: TextSpan(
                  children: [
                    TextSpan(text: Messages.consentPrivacy),
                    TextSpan(
                      text: Messages.privacyLink,
                      style: const TextStyle(color: AppTheme.electricCyan, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                      recognizer: TapGestureRecognizer()..onTap = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InfoScreen(docType: 'privacy'))),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ..._buildConsentCheckbox(
                value: _consentGuidelines,
                onChanged: (v) => setState(() => _consentGuidelines = v),
                text: TextSpan(
                  children: [
                    TextSpan(text: Messages.consentGuidelines),
                    TextSpan(
                      text: Messages.guidelinesLink,
                      style: const TextStyle(color: AppTheme.electricCyan, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                      recognizer: TapGestureRecognizer()..onTap = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InfoScreen(docType: 'guidelines'))),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ..._buildConsentCheckbox(
                value: _consentDataProcessing,
                onChanged: (v) => setState(() => _consentDataProcessing = v),
                text: TextSpan(text: Messages.consentDataProcessing),
              ),

              const SizedBox(height: 36),

              // Tactile Animated Register Button
              GestureDetector(
                onTapDown: (_) => _btnController.forward(),
                onTapUp: (_) {
                  _btnController.reverse();
                  if (!_isLoading) _signUp();
                },
                onTapCancel: () => _btnController.reverse(),
                child: ScaleTransition(
                  scale: _btnScale,
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppTheme.electricCyan, AppTheme.primaryRose]),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [BoxShadow(color: AppTheme.electricCyan.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    child: Center(
                      child: _isLoading 
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) 
                        : Text(Messages.registerButton, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}