import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../shared/widgets/auth_text_field.dart';
import '../../../core/utils/post_auth_navigator.dart';
import '../application/auth_provider.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  static const Color _navy = Color(0xFF102A43);
  static const Color _subGrey = Color(0xFF5A6B7B);
  static const Color _background = Color(0xFFFAFAF7);
  static const Color _blue = Color(0xFF2E5FA3);
  static const Color _gold = Color(0xFFC79A3D);

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authProvider.notifier).signUp(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (mounted) {
      final state = ref.read(authProvider);
      if (state.status == AuthStatus.authenticated) {
        await navigateAfterAuthentication(context, ref, isFreshAuth: true);
      } else if (state.status == AuthStatus.initial) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully! Please log in.'),
            backgroundColor: Color(0xFF3F7D4F), // CredNest Green
            duration: Duration(seconds: 3),
          ),
        );
        context.go('/login');
      }
    }
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your full name';
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email address';
    }
    final emailRegex = RegExp(r'^[\w.-]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Smaller Logo for Signup screen
                  Center(
                    child: Image.asset(
                      'assets/images/crednest_logo.png',
                      width: 60,
                      height: 60,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Heading
                  const Text(
                    'Create your account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _navy,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subsubtitle
                  const Text(
                    'Start building your financial identity.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: _subGrey,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Name Field
                  AuthTextField(
                    controller: _nameController,
                    labelText: 'Full Name',
                    hintText: 'e.g. John Doe',
                    prefixIcon: Icons.person_outline,
                    validator: _validateName,
                  ),
                  const SizedBox(height: 18),

                  // Email Field
                  AuthTextField(
                    controller: _emailController,
                    labelText: 'Email Address',
                    hintText: 'e.g. name@example.com',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email_outlined,
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 18),

                  // Password Field
                  AuthTextField(
                    controller: _passwordController,
                    labelText: 'Password',
                    hintText: 'Create a strong password',
                    isPassword: true,
                    prefixIcon: Icons.lock_outline,
                    validator: _validatePassword,
                  ),
                  const SizedBox(height: 18),

                  // Confirm Password Field
                  AuthTextField(
                    controller: _confirmPasswordController,
                    labelText: 'Confirm Password',
                    hintText: 'Re-enter password',
                    isPassword: true,
                    prefixIcon: Icons.lock_clock_outlined,
                    textInputAction: TextInputAction.done,
                    validator: _validateConfirmPassword,
                  ),
                  const SizedBox(height: 24),

                  // Error Banner
                  if (authState.status == AuthStatus.error) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEEEE),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFFFCCCC)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFD32F2F), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              authState.errorMessage ?? 'An error occurred during registration.',
                              style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Action Button
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: authState.isLoading ? null : _signUp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: _blue.withValues(alpha: 0.55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: authState.isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Login Prompt
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(
                          color: _subGrey,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.go('/login'),
                        child: const Text(
                          'Log In',
                          style: TextStyle(
                            color: _gold,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
