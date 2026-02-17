import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/providers/account_provider.dart';
import '../../data/services/auth_service.dart';
import '../home/home_screen.dart';

/// Login/signup screen shown on first launch.
///
/// Authentication strategy:
/// 1. Primary: Device-bound account (auto-tied to this install)
/// 2. Optional: Email upgrade for cross-device recovery
/// 3. Fallback: Guest mode (limited features)
///
/// Anti-multi-account: One account per device install.
/// Revenue protection: Free tier locked to device, can't create
/// unlimited accounts without new device/reinstall.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _authService = AuthService();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _displayNameController = TextEditingController();

  bool _isLoading = false;
  String? _error;
  _AuthMode _mode = _AuthMode.welcome;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Background
            const _AuthBackground(),

            // Content
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    SizedBox(height: MediaQuery.of(context).size.height * 0.12),
                    // Logo
                    const Text(
                      'FLIT',
                      style: TextStyle(
                        color: FlitColors.textPrimary,
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'A GEOGRAPHICAL ADVENTURE',
                      style: TextStyle(
                        color: FlitColors.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 48),

                    // Auth content based on mode
                    if (_mode == _AuthMode.welcome) _buildWelcome(),
                    if (_mode == _AuthMode.createAccount) _buildCreateAccount(),
                    if (_mode == _AuthMode.emailSignup) _buildEmailSignup(),

                    // Error display
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: FlitColors.error.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: FlitColors.error.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: FlitColors.error, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: FlitColors.error,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Loading indicator
                    if (_isLoading) ...[
                      const SizedBox(height: 24),
                      const CircularProgressIndicator(
                        color: FlitColors.accent,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildWelcome() => Column(
        children: [
          const Text(
            'Welcome, Pilot',
            style: TextStyle(
              color: FlitColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create your account to start exploring the world.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),

          // Continue as guest (primary CTA — account creation coming soon)
          _AuthButton(
            label: 'PLAY AS GUEST',
            isPrimary: true,
            icon: Icons.flight_takeoff,
            onTap: _continueAsGuest,
          ),
          const SizedBox(height: 12),

          // Create account (coming soon)
          _AuthButton(
            label: 'CREATE ACCOUNT',
            icon: Icons.person_add_outlined,
            isDisabled: true,
            onTap: () {},
          ),
          const SizedBox(height: 12),

          // Sign up with email (coming soon)
          _AuthButton(
            label: 'SIGN UP WITH EMAIL',
            icon: Icons.email_outlined,
            isDisabled: true,
            onTap: () {},
          ),

          const SizedBox(height: 24),

          // Info text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FlitColors.cardBackground.withOpacity(0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined,
                    color: FlitColors.gold, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your account is tied to this device for security. '
                    'Add an email later to recover across devices.',
                    style: TextStyle(
                      color: FlitColors.textMuted,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );

  Widget _buildCreateAccount() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Back button
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => setState(() {
                _mode = _AuthMode.welcome;
                _error = null;
              }),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, color: FlitColors.textSecondary, size: 18),
                  SizedBox(width: 4),
                  Text(
                    'Back',
                    style: TextStyle(color: FlitColors.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Choose your pilot name',
            style: TextStyle(
              color: FlitColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This is how other pilots will see you.',
            style: TextStyle(color: FlitColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Username field
          _AuthTextField(
            controller: _usernameController,
            label: 'Username',
            hint: 'e.g. SkyPilot42',
            prefix: '@',
          ),
          const SizedBox(height: 12),

          // Display name (optional)
          _AuthTextField(
            controller: _displayNameController,
            label: 'Display Name (optional)',
            hint: 'Your visible name',
          ),
          const SizedBox(height: 24),

          // Create button
          _AuthButton(
            label: 'TAKE OFF',
            isPrimary: true,
            icon: Icons.flight_takeoff,
            onTap: _createDeviceAccount,
          ),
        ],
      );

  Widget _buildEmailSignup() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Back button
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => setState(() {
                _mode = _AuthMode.welcome;
                _error = null;
              }),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, color: FlitColors.textSecondary, size: 18),
                  SizedBox(width: 4),
                  Text(
                    'Back',
                    style: TextStyle(color: FlitColors.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Sign up with email',
            style: TextStyle(
              color: FlitColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Recover your account on any device.',
            style: TextStyle(color: FlitColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Email field
          _AuthTextField(
            controller: _emailController,
            label: 'Email',
            hint: 'pilot@example.com',
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),

          // Username field
          _AuthTextField(
            controller: _usernameController,
            label: 'Username',
            hint: 'e.g. SkyPilot42',
            prefix: '@',
          ),
          const SizedBox(height: 12),

          // Display name
          _AuthTextField(
            controller: _displayNameController,
            label: 'Display Name (optional)',
            hint: 'Your visible name',
          ),
          const SizedBox(height: 24),

          // Create button
          _AuthButton(
            label: 'CREATE ACCOUNT',
            isPrimary: true,
            icon: Icons.email_outlined,
            onTap: _signUpWithEmail,
          ),

          const SizedBox(height: 16),

          // Privacy note
          const Text(
            'We only store your email for account recovery. '
            'No spam, no sharing.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: FlitColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      );

  Future<void> _createDeviceAccount() async {
    final username = _usernameController.text.trim();
    if (username.length < 3) {
      setState(() => _error = 'Username must be at least 3 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _authService.createDeviceAccount(
      username: username,
      displayName: _displayNameController.text.trim().isNotEmpty
          ? _displayNameController.text.trim()
          : null,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (result.isAuthenticated) {
        if (result.player != null) {
          ref.read(accountProvider.notifier).switchAccount(result.player!);
        }
        _navigateToHome();
      } else if (result.error != null) {
        setState(() => _error = result.error);
      }
    }
  }

  Future<void> _signUpWithEmail() async {
    final email = _emailController.text.trim();
    final username = _usernameController.text.trim();

    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email');
      return;
    }
    if (username.length < 3) {
      setState(() => _error = 'Username must be at least 3 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _authService.signUpWithEmail(
      email: email,
      username: username,
      displayName: _displayNameController.text.trim().isNotEmpty
          ? _displayNameController.text.trim()
          : null,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (result.isAuthenticated) {
        if (result.player != null) {
          ref.read(accountProvider.notifier).switchAccount(result.player!);
        }
        _navigateToHome();
      } else if (result.error != null) {
        setState(() => _error = result.error);
      }
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    await _authService.continueAsGuest();

    if (mounted) {
      setState(() => _isLoading = false);
      final guestState = _authService.state;
      if (guestState.player != null) {
        ref.read(accountProvider.notifier).switchAccount(guestState.player!);
      }
      _navigateToHome();
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => const HomeScreen(),
      ),
    );
  }
}

enum _AuthMode {
  welcome,
  createAccount,
  emailSignup,
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              FlitColors.oceanDeep,
              FlitColors.backgroundDark,
              FlitColors.oceanDeep,
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
      );
}

class _AuthTextField extends StatelessWidget {
  const _AuthTextField({
    required this.controller,
    required this.label,
    required this.hint,
    this.prefix,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String? prefix;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: FlitColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(
              color: FlitColors.textPrimary,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: FlitColors.textMuted),
              prefixText: prefix,
              prefixStyle: const TextStyle(
                color: FlitColors.textSecondary,
                fontSize: 16,
              ),
              filled: true,
              fillColor: FlitColors.cardBackground,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: FlitColors.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: FlitColors.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: FlitColors.accent, width: 1.5),
              ),
            ),
          ),
        ],
      );
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.label,
    required this.onTap,
    this.icon,
    this.isPrimary = false,
    this.isSubtle = false,
    this.isDisabled = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool isPrimary;
  final bool isSubtle;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isDisabled
        ? FlitColors.cardBackground.withOpacity(0.5)
        : isPrimary
            ? FlitColors.accent
            : isSubtle
                ? Colors.transparent
                : FlitColors.cardBackground.withOpacity(0.8);
    final textColor = isDisabled
        ? FlitColors.textMuted
        : isSubtle
            ? FlitColors.textSecondary
            : FlitColors.textPrimary;

    return Material(
      color: effectiveColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: isDisabled ? null : onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: isSubtle
                ? Border.all(color: FlitColors.cardBorder.withOpacity(0.4))
                : isPrimary && !isDisabled
                    ? null
                    : Border.all(
                        color: FlitColors.cardBorder.withOpacity(
                          isDisabled ? 0.2 : 1.0,
                        ),
                      ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: textColor, size: 20),
                const SizedBox(width: 10),
              ],
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
              if (isDisabled) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: FlitColors.textMuted.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'SOON',
                    style: TextStyle(
                      color: FlitColors.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
