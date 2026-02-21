import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/flit_colors.dart';
import '../../data/providers/account_provider.dart';
import '../../data/services/auth_service.dart';
import '../home/home_screen.dart';

/// Login/signup screen shown on first launch.
///
/// Authentication strategy: Email + password via Supabase Auth.
/// All players must have accounts — no guest mode.
///
/// No Google Auth — email only, kept simple.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _authService = AuthService();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();

  bool _isLoading = false;
  String? _error;
  _AuthMode _mode = _AuthMode.welcome;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  /// Auto-login if there's a valid Supabase session from a previous launch.
  Future<void> _checkExistingSession() async {
    setState(() => _isLoading = true);

    final result = await _authService.checkExistingAuth();

    if (mounted) {
      setState(() => _isLoading = false);

      if (result.isAuthenticated && result.player != null) {
        final notifier = ref.read(accountProvider.notifier);
        notifier.switchAccount(result.player!);
        await notifier.loadFromSupabase(result.player!.id);
        if (mounted) _navigateToHome();
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        const _AuthBackground(),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.12),
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

                if (_mode == _AuthMode.welcome) _buildWelcome(),
                if (_mode == _AuthMode.signUp) _buildSignUp(),
                if (_mode == _AuthMode.signIn) _buildSignIn(),
                if (_mode == _AuthMode.confirmEmail) _buildConfirmEmail(),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _ErrorBanner(message: _error!),
                ],

                if (_isLoading) ...[
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(color: FlitColors.accent),
                ],

                const SizedBox(height: 40),
                const _PrivacyLink(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  // ── Welcome screen ──

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
        'Create an account or sign in to start exploring.',
        textAlign: TextAlign.center,
        style: TextStyle(color: FlitColors.textSecondary, fontSize: 14),
      ),
      const SizedBox(height: 32),

      _AuthButton(
        label: 'SIGN UP',
        isPrimary: true,
        icon: Icons.person_add_outlined,
        onTap: () => setState(() {
          _mode = _AuthMode.signUp;
          _error = null;
        }),
      ),
      const SizedBox(height: 12),

      _AuthButton(
        label: 'SIGN IN',
        icon: Icons.login,
        onTap: () => setState(() {
          _mode = _AuthMode.signIn;
          _error = null;
        }),
      ),

      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FlitColors.cardBackground.withOpacity(0.6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            Icon(Icons.shield_outlined, color: FlitColors.gold, size: 18),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Your progress is saved to your account. '
                'Sign in on any device to pick up where you left off.',
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

  // ── Sign Up form ──

  Widget _buildSignUp() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _BackButton(
        onTap: () => setState(() {
          _mode = _AuthMode.welcome;
          _error = null;
        }),
      ),
      const SizedBox(height: 16),

      const Text(
        'Create your account',
        style: TextStyle(
          color: FlitColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Choose a pilot name and set your password.',
        style: TextStyle(color: FlitColors.textSecondary, fontSize: 13),
      ),
      const SizedBox(height: 24),

      _AuthTextField(
        controller: _emailController,
        label: 'Email',
        hint: 'pilot@example.com',
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 12),

      _AuthTextField(
        controller: _passwordController,
        label: 'Password',
        hint: 'At least 6 characters',
        obscureText: _obscurePassword,
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: FlitColors.textMuted,
            size: 20,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      const SizedBox(height: 12),

      _AuthTextField(
        controller: _usernameController,
        label: 'Username',
        hint: 'e.g. SkyPilot42',
        prefix: '@',
      ),
      const SizedBox(height: 12),

      _AuthTextField(
        controller: _displayNameController,
        label: 'Display Name (optional)',
        hint: 'Your visible name',
      ),
      const SizedBox(height: 24),

      _AuthButton(
        label: 'CREATE ACCOUNT',
        isPrimary: true,
        icon: Icons.flight_takeoff,
        onTap: _signUp,
      ),

      const SizedBox(height: 16),
      const Text(
        'We only store your email for account recovery. '
        'No spam, no sharing.',
        textAlign: TextAlign.center,
        style: TextStyle(color: FlitColors.textMuted, fontSize: 11),
      ),
    ],
  );

  // ── Sign In form ──

  Widget _buildSignIn() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _BackButton(
        onTap: () => setState(() {
          _mode = _AuthMode.welcome;
          _error = null;
        }),
      ),
      const SizedBox(height: 16),

      const Text(
        'Welcome back',
        style: TextStyle(
          color: FlitColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Sign in to continue your adventure.',
        style: TextStyle(color: FlitColors.textSecondary, fontSize: 13),
      ),
      const SizedBox(height: 24),

      _AuthTextField(
        controller: _emailController,
        label: 'Email',
        hint: 'pilot@example.com',
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 12),

      _AuthTextField(
        controller: _passwordController,
        label: 'Password',
        hint: 'Your password',
        obscureText: _obscurePassword,
        suffixIcon: IconButton(
          icon: Icon(
            _obscurePassword ? Icons.visibility_off : Icons.visibility,
            color: FlitColors.textMuted,
            size: 20,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
      ),
      const SizedBox(height: 24),

      _AuthButton(
        label: 'SIGN IN',
        isPrimary: true,
        icon: Icons.login,
        onTap: _signIn,
      ),
    ],
  );

  // ── Email confirmation screen ──

  Widget _buildConfirmEmail() => Column(
    children: [
      const Icon(
        Icons.mark_email_read_outlined,
        color: FlitColors.gold,
        size: 64,
      ),
      const SizedBox(height: 24),
      const Text(
        'Check your email',
        style: TextStyle(
          color: FlitColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'We sent a confirmation link to\n${_emailController.text.trim()}',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: FlitColors.textSecondary,
          fontSize: 14,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Click the link in your email, then come back and sign in.',
        textAlign: TextAlign.center,
        style: TextStyle(color: FlitColors.textMuted, fontSize: 13),
      ),
      const SizedBox(height: 32),
      _AuthButton(
        label: 'SIGN IN',
        isPrimary: true,
        icon: Icons.login,
        onTap: () => setState(() {
          _mode = _AuthMode.signIn;
          _error = null;
        }),
      ),
      const SizedBox(height: 12),
      _AuthButton(
        label: 'BACK TO START',
        icon: Icons.arrow_back,
        onTap: () => setState(() {
          _mode = _AuthMode.welcome;
          _error = null;
        }),
      ),
    ],
  );

  // ── Actions ──

  Future<void> _signUp() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final username = _usernameController.text.trim();

    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
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
      password: password,
      username: username,
      displayName: _displayNameController.text.trim().isNotEmpty
          ? _displayNameController.text.trim()
          : null,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (result.needsEmailConfirmation) {
        setState(() => _mode = _AuthMode.confirmEmail);
      } else if (result.isAuthenticated && result.player != null) {
        final notifier = ref.read(accountProvider.notifier);
        notifier.switchAccount(result.player!);
        await notifier.loadFromSupabase(result.player!.id);
        if (mounted) _navigateToHome();
      } else if (result.error != null) {
        setState(() => _error = result.error);
      }
    }
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = 'Please enter your password');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final result = await _authService.signInWithEmail(
      email: email,
      password: password,
    );

    if (mounted) {
      setState(() => _isLoading = false);

      if (result.isAuthenticated && result.player != null) {
        final notifier = ref.read(accountProvider.notifier);
        notifier.switchAccount(result.player!);
        await notifier.loadFromSupabase(result.player!.id);
        if (mounted) _navigateToHome();
      } else if (result.error != null) {
        setState(() => _error = result.error);
      }
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (context) => const HomeScreen()),
    );
  }
}

enum _AuthMode { welcome, signUp, signIn, confirmEmail }

// ── Shared widgets ──

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

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: GestureDetector(
      onTap: onTap,
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
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: FlitColors.error.withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: FlitColors.error.withOpacity(0.3)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: FlitColors.error, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: FlitColors.error, fontSize: 13),
          ),
        ),
      ],
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
    this.obscureText = false,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String? prefix;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;

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
        obscureText: obscureText,
        style: const TextStyle(color: FlitColors.textPrimary, fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: FlitColors.textMuted),
          prefixText: prefix,
          prefixStyle: const TextStyle(
            color: FlitColors.textSecondary,
            fontSize: 16,
          ),
          suffixIcon: suffixIcon,
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
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final bgColor = isPrimary
        ? FlitColors.accent
        : FlitColors.cardBackground.withOpacity(0.8);

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: isPrimary ? null : Border.all(color: FlitColors.cardBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: FlitColors.textPrimary, size: 20),
                const SizedBox(width: 10),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: FlitColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tappable "Privacy Policy" footer link.
///
/// Opens a dialog with the full URL since url_launcher is not in the
/// dependency tree. Users can copy the URL or open it manually.
class _PrivacyLink extends StatelessWidget {
  const _PrivacyLink();

  static const String _privacyUrl = 'https://flit-olive.vercel.app/privacy';

  void _showPrivacyDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: FlitColors.cardBackground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: FlitColors.cardBorder),
        ),
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            color: FlitColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Read our full privacy policy at:',
              style: TextStyle(color: FlitColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: FlitColors.backgroundDark,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: FlitColors.cardBorder),
              ),
              child: const SelectableText(
                _privacyUrl,
                style: TextStyle(
                  color: FlitColors.oceanHighlight,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Copy the link above and open it in your browser.',
              style: TextStyle(
                color: FlitColors.textMuted,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Close',
              style: TextStyle(color: FlitColors.accent),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => _showPrivacyDialog(context),
    child: const Text(
      'Privacy Policy',
      style: TextStyle(
        color: FlitColors.textMuted,
        fontSize: 11,
        decoration: TextDecoration.underline,
        decorationColor: FlitColors.textMuted,
      ),
    ),
  );
}
