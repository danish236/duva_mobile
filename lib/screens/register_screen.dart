import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'onboarding_screen.dart';
import '../theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  int _passwordStrength = 0; 

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_checkPasswordStrength);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _checkPasswordStrength() {
    String password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _passwordStrength = 0);
    } else if (password.length < 6) {
      setState(() => _passwordStrength = 1);
    } else if (password.length >= 6 && password.length < 10 && !password.contains(RegExp(r'[0-9]'))) {
      setState(() => _passwordStrength = 2);
    } else {
      setState(() => _passwordStrength = 3);
    }
  }

  Color _getStrengthColor() {
    if (_passwordStrength == 1) return Colors.redAccent;
    if (_passwordStrength == 2) return Colors.orangeAccent;
    if (_passwordStrength == 3) return Colors.green;
    return Theme.of(context).colorScheme.surface;
  }

  String _getStrengthText() {
    if (_passwordStrength == 1) return 'Too short (Min 6 chars)';
    if (_passwordStrength == 2) return 'Good (Add numbers/symbols to make it stronger)';
    if (_passwordStrength == 3) return 'Strong password';
    return 'Minimum 6 characters';
  }

  Future<void> _signUp() async {
    if (_passwordStrength == 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password is too weak.')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signUp(email: _emailController.text.trim(), password: _passwordController.text.trim());
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OnboardingScreen()));
    } on AuthException catch (e) {
      if (!mounted) return;
      if (e.message.toLowerCase().contains('rate limit')) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Too many attempts. Please try again in an hour.'), backgroundColor: Colors.orange));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Create an Account', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
              const SizedBox(height: 8),
              Text('Join Duva to find your perfect alignment.', style: TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 16)),
              const SizedBox(height: 48),
              
              TextField(
                controller: _emailController, 
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email Address')
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: colorScheme.onSurface.withValues(alpha: 0.6)),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              Row(
                children: [
                  Expanded(child: AnimatedContainer(duration: const Duration(milliseconds: 300), height: 4, decoration: BoxDecoration(color: _passwordStrength >= 1 ? _getStrengthColor() : colorScheme.surface, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(width: 4),
                  Expanded(child: AnimatedContainer(duration: const Duration(milliseconds: 300), height: 4, decoration: BoxDecoration(color: _passwordStrength >= 2 ? _getStrengthColor() : colorScheme.surface, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(width: 4),
                  Expanded(child: AnimatedContainer(duration: const Duration(milliseconds: 300), height: 4, decoration: BoxDecoration(color: _passwordStrength >= 3 ? _getStrengthColor() : colorScheme.surface, borderRadius: BorderRadius.circular(2)))),
                ],
              ),
              const SizedBox(height: 8),
              Text(_getStrengthText(), style: TextStyle(color: _passwordStrength == 0 ? colorScheme.onSurface.withValues(alpha: 0.6) : _getStrengthColor(), fontSize: 12, fontWeight: FontWeight.bold)),
              
              const SizedBox(height: 48),
              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signUp,
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Register'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}