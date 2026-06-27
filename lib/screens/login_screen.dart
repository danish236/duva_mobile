import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'register_screen.dart';
import '../theme.dart';
import '../messages.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  late AnimationController _btnController;
  late Animation<double> _btnScale;

  @override
  void initState() {
    super.initState();
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

  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(), 
        password: _passwordController.text.trim()
      );
    } on AuthException catch (e) {
      String msg;
      switch (e.message) {
        case 'Invalid login credentials':
          msg = Messages.invalidEmailOrPassword;
          break;
        default:
          msg = Messages.authFailed;
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(Messages.somethingWentWrong)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.voidBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              
              // --- YOUR CUSTOM GLOWING LOGO ---
              Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryRose.withValues(alpha: 0.05),
                    boxShadow: [BoxShadow(color: AppTheme.electricCyan.withValues(alpha: 0.15), blurRadius: 60, spreadRadius: 10)],
                  ),
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [AppTheme.electricCyan, AppTheme.primaryRose],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    // Using your transparent white logo!
                    child: Image.asset(
                      'assets/logo_nobg.png', 
                      height: 100, 
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              const Text(Messages.loginTitle, textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 4)),
              
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
              const SizedBox(height: 48),
              
              GestureDetector(
                onTapDown: (_) => _btnController.forward(),
                onTapUp: (_) {
                  _btnController.reverse();
                  if (!_isLoading) _signIn();
                },
                onTapCancel: () => _btnController.reverse(),
                child: ScaleTransition(
                  scale: _btnScale,
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppTheme.primaryRose, AppTheme.electricCyan]),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [BoxShadow(color: AppTheme.primaryRose.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    child: Center(
                      child: _isLoading 
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) 
                        : const Text('LOGIN', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              TextButton(
                onPressed: () => Navigator.push(context, PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => const RegisterScreen(),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(opacity: animation, child: child),
                )), 
                child: const Text('NEW HERE? INITIALIZE PROFILE', style: TextStyle(color: AppTheme.electricCyan, fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 12))
              ),
            ],
          ),
        ),
      ),
    );
  }
}