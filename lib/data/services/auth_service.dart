import 'dart:math';

import '../models/player.dart';

/// Authentication method used by the player.
enum AuthMethod {
  /// Anonymous device-bound account (auto-created on first launch)
  device,

  /// Email + password account
  email,

  /// Guest mode (no persistence, for trying the game)
  guest,
}

/// Current authentication state.
class AuthState {
  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.player,
    this.authMethod = AuthMethod.guest,
    this.deviceId,
    this.email,
    this.error,
  });

  final bool isAuthenticated;
  final bool isLoading;
  final Player? player;
  final AuthMethod authMethod;
  final String? deviceId;
  final String? email;
  final String? error;

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    Player? player,
    AuthMethod? authMethod,
    String? deviceId,
    String? email,
    String? error,
  }) => AuthState(
    isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    isLoading: isLoading ?? this.isLoading,
    player: player ?? this.player,
    authMethod: authMethod ?? this.authMethod,
    deviceId: deviceId ?? this.deviceId,
    email: email ?? this.email,
    error: error,
  );
}

/// Authentication service.
///
/// Strategy: Device-bound anonymous accounts with optional email upgrade.
///
/// Why this approach:
/// - **Minimal friction**: Auto-creates account on first launch
/// - **Anti-multi-account**: Ties to device ID (vendor ID on iOS, Android ID)
/// - **Low data storage**: Just device ID + optional email
/// - **Revenue protection**: One free account per device install
/// - **Upgrade path**: Add email later to recover across devices
///
/// For production, this would integrate with:
/// - Firebase Auth (anonymous + email link) or
/// - Supabase Auth (anonymous + magic link) or
/// - Custom backend with device attestation (DeviceCheck on iOS, SafetyNet on Android)
///
/// The device attestation APIs prevent emulator abuse and verify real devices.
class AuthService {
  /// Simulated auth state (in production: SharedPreferences + backend)
  AuthState _state = const AuthState();
  bool _hasExistingAccount = false;

  AuthState get state => _state;

  /// Check if there's an existing device-bound account.
  /// Called on app startup.
  Future<AuthState> checkExistingAuth() async {
    _state = _state.copyWith(isLoading: true);

    // Simulate checking local storage for existing account
    await Future<void>.delayed(const Duration(milliseconds: 300));

    if (_hasExistingAccount) {
      // Found existing device-bound account
      _state = _state.copyWith(
        isAuthenticated: true,
        isLoading: false,
        authMethod: AuthMethod.device,
      );
    } else {
      _state = _state.copyWith(isLoading: false);
    }

    return _state;
  }

  /// Create a new device-bound account.
  /// This is the primary account creation method.
  Future<AuthState> createDeviceAccount({
    required String username,
    String? displayName,
  }) async {
    _state = _state.copyWith(isLoading: true, error: null);

    // Simulate network call
    await Future<void>.delayed(const Duration(milliseconds: 500));

    // Generate a device-bound player ID
    final deviceId = _generateDeviceId();
    final playerId = 'device-$deviceId';

    final player = Player(
      id: playerId,
      username: username,
      displayName: displayName ?? username,
      level: 1,
      xp: 0,
      coins: 100, // Starting bonus
      gamesPlayed: 0,
      createdAt: DateTime.now(),
    );

    _hasExistingAccount = true;
    _state = AuthState(
      isAuthenticated: true,
      isLoading: false,
      player: player,
      authMethod: AuthMethod.device,
      deviceId: deviceId,
    );

    return _state;
  }

  /// Sign up with email (upgrade from device account or fresh).
  Future<AuthState> signUpWithEmail({
    required String email,
    required String username,
    String? displayName,
  }) async {
    _state = _state.copyWith(isLoading: true, error: null);

    await Future<void>.delayed(const Duration(milliseconds: 500));

    // Validate email format
    if (!_isValidEmail(email)) {
      _state = _state.copyWith(
        isLoading: false,
        error: 'Please enter a valid email address',
      );
      return _state;
    }

    // Validate username
    if (username.length < 3) {
      _state = _state.copyWith(
        isLoading: false,
        error: 'Username must be at least 3 characters',
      );
      return _state;
    }

    final player =
        _state.player?.copyWith(
          username: username,
          displayName: displayName ?? username,
        ) ??
        Player(
          id: 'email-${email.hashCode}',
          username: username,
          displayName: displayName ?? username,
          level: 1,
          xp: 0,
          coins: 100,
          gamesPlayed: 0,
          createdAt: DateTime.now(),
        );

    _hasExistingAccount = true;
    _state = AuthState(
      isAuthenticated: true,
      isLoading: false,
      player: player,
      authMethod: AuthMethod.email,
      email: email,
    );

    return _state;
  }

  /// Continue as guest (limited features, no persistence).
  Future<AuthState> continueAsGuest() async {
    _state = _state.copyWith(isLoading: true, error: null);

    await Future<void>.delayed(const Duration(milliseconds: 200));

    _state = AuthState(
      isAuthenticated: true,
      isLoading: false,
      player: Player.guest(),
      authMethod: AuthMethod.guest,
    );

    return _state;
  }

  /// Sign out.
  Future<AuthState> signOut() async {
    _hasExistingAccount = false;
    _state = const AuthState();
    return _state;
  }

  /// Link email to existing device account (account upgrade).
  Future<AuthState> linkEmail(String email) async {
    if (!_isValidEmail(email)) {
      _state = _state.copyWith(error: 'Please enter a valid email address');
      return _state;
    }

    _state = _state.copyWith(
      authMethod: AuthMethod.email,
      email: email,
      error: null,
    );
    return _state;
  }

  String _generateDeviceId() {
    // In production: use platform-specific device ID
    // iOS: UIDevice.identifierForVendor (resets on reinstall)
    // Android: Settings.Secure.ANDROID_ID
    // Web: fingerprint or localStorage UUID
    final random = Random.secure();
    return List.generate(
      16,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }
}
