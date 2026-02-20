import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/player.dart';

/// Authentication method used by the player.
enum AuthMethod {
  /// Supabase email + password account
  email,

  /// Guest mode (local only, no persistence across devices)
  guest,
}

/// Current authentication state.
class AuthState {
  const AuthState({
    this.isAuthenticated = false,
    this.isLoading = false,
    this.player,
    this.authMethod = AuthMethod.guest,
    this.email,
    this.error,
    this.needsEmailConfirmation = false,
  });

  final bool isAuthenticated;
  final bool isLoading;
  final Player? player;
  final AuthMethod authMethod;
  final String? email;
  final String? error;

  /// True after sign-up when the user must verify their email before signing in.
  final bool needsEmailConfirmation;

  AuthState copyWith({
    bool? isAuthenticated,
    bool? isLoading,
    Player? player,
    AuthMethod? authMethod,
    String? email,
    String? error,
    bool? needsEmailConfirmation,
  }) => AuthState(
    isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    isLoading: isLoading ?? this.isLoading,
    player: player ?? this.player,
    authMethod: authMethod ?? this.authMethod,
    email: email ?? this.email,
    error: error,
    needsEmailConfirmation:
        needsEmailConfirmation ?? this.needsEmailConfirmation,
  );
}

/// Supabase-backed authentication service.
///
/// Strategy: Email + password accounts via Supabase Auth.
/// Profiles are auto-created by a database trigger on sign-up.
/// Guest mode remains local-only for trying the game.
class AuthService {
  AuthState _state = const AuthState();

  AuthState get state => _state;

  SupabaseClient get _client => Supabase.instance.client;

  /// Check for an existing Supabase session (auto-restored on app start).
  Future<AuthState> checkExistingAuth() async {
    _state = _state.copyWith(isLoading: true);

    try {
      final session = _client.auth.currentSession;
      final user = _client.auth.currentUser;

      if (session != null && user != null) {
        final player = await _fetchOrCreateProfile(user);
        _state = AuthState(
          isAuthenticated: true,
          isLoading: false,
          player: player,
          authMethod: AuthMethod.email,
          email: user.email,
        );
      } else {
        _state = _state.copyWith(isLoading: false);
      }
    } on AuthException catch (e) {
      _state = _state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      _state = _state.copyWith(isLoading: false, error: e.toString());
    }

    return _state;
  }

  /// Sign up with email + password.
  ///
  /// Creates a Supabase auth user and updates the auto-created profile
  /// with the chosen username. Returns a state with
  /// [needsEmailConfirmation] = true so the UI can show a confirmation message.
  Future<AuthState> signUpWithEmail({
    required String email,
    required String password,
    required String username,
    String? displayName,
  }) async {
    _state = _state.copyWith(isLoading: true, error: null);

    // Client-side validation
    if (!_isValidEmail(email)) {
      _state = _state.copyWith(
        isLoading: false,
        error: 'Please enter a valid email address',
      );
      return _state;
    }
    if (username.length < 3) {
      _state = _state.copyWith(
        isLoading: false,
        error: 'Username must be at least 3 characters',
      );
      return _state;
    }
    if (password.length < 6) {
      _state = _state.copyWith(
        isLoading: false,
        error: 'Password must be at least 6 characters',
      );
      return _state;
    }

    try {
      // Check username uniqueness before creating the auth user.
      final existing = await _client
          .from('profiles')
          .select('id')
          .eq('username', username)
          .maybeSingle();
      if (existing != null) {
        _state = _state.copyWith(
          isLoading: false,
          error: 'Username @$username is already taken',
        );
        return _state;
      }

      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'username': username, 'display_name': displayName ?? username},
      );

      if (response.user != null) {
        // Update the profile row (created by trigger) with username.
        // This may fail if the user hasn't confirmed email yet and RLS
        // blocks unauthenticated writes — that's fine, we'll update on
        // first sign-in instead.
        try {
          await _client
              .from('profiles')
              .update({
                'username': username,
                'display_name': displayName ?? username,
              })
              .eq('id', response.user!.id);
        } catch (_) {
          // Profile update will happen on first sign-in.
        }

        // If Supabase returned a session, the user is already confirmed
        // (e.g. confirm-email is disabled or auto-confirmed).
        if (response.session != null) {
          final player = Player(
            id: response.user!.id,
            username: username,
            displayName: displayName ?? username,
            level: 1,
            xp: 0,
            coins: 100,
            gamesPlayed: 0,
            createdAt: DateTime.now(),
          );
          _state = AuthState(
            isAuthenticated: true,
            isLoading: false,
            player: player,
            authMethod: AuthMethod.email,
            email: email,
          );
        } else {
          // Email confirmation required.
          _state = AuthState(
            isAuthenticated: false,
            isLoading: false,
            authMethod: AuthMethod.email,
            email: email,
            needsEmailConfirmation: true,
          );
        }
      } else {
        _state = _state.copyWith(
          isLoading: false,
          error: 'Sign-up failed. Please try again.',
        );
      }
    } on AuthException catch (e) {
      _state = _state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      _state = _state.copyWith(isLoading: false, error: e.toString());
    }

    return _state;
  }

  /// Sign in with email + password.
  Future<AuthState> signInWithEmail({
    required String email,
    required String password,
  }) async {
    _state = _state.copyWith(isLoading: true, error: null);

    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        final player = await _fetchOrCreateProfile(response.user!);
        _state = AuthState(
          isAuthenticated: true,
          isLoading: false,
          player: player,
          authMethod: AuthMethod.email,
          email: email,
        );
      } else {
        _state = _state.copyWith(
          isLoading: false,
          error: 'Sign-in failed. Please try again.',
        );
      }
    } on AuthException catch (e) {
      _state = _state.copyWith(isLoading: false, error: e.message);
    } catch (e) {
      _state = _state.copyWith(isLoading: false, error: e.toString());
    }

    return _state;
  }

  /// Continue as guest (local only, no Supabase interaction).
  Future<AuthState> continueAsGuest() async {
    _state = _state.copyWith(isLoading: true, error: null);

    _state = AuthState(
      isAuthenticated: true,
      isLoading: false,
      player: Player.guest(),
      authMethod: AuthMethod.guest,
    );

    return _state;
  }

  /// Sign out. Clears the Supabase session.
  Future<AuthState> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (_) {
      // Ignore sign-out errors (network offline, etc.)
    }
    _state = const AuthState();
    return _state;
  }

  /// Fetch the player profile from Supabase, or build one from user metadata
  /// if the profile row doesn't exist yet.
  Future<Player> _fetchOrCreateProfile(User user) async {
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (data != null) {
        // Ensure username is set (may be null if trigger created row
        // before the profile update succeeded).
        final username =
            data['username'] as String? ??
            user.userMetadata?['username'] as String? ??
            user.email?.split('@').first ??
            'Pilot';

        final displayName =
            data['display_name'] as String? ??
            user.userMetadata?['display_name'] as String? ??
            username;

        // Backfill username if it was missing in the DB.
        if (data['username'] == null) {
          try {
            await _client
                .from('profiles')
                .update({'username': username, 'display_name': displayName})
                .eq('id', user.id);
          } catch (_) {}
        }

        return Player(
          id: user.id,
          username: username,
          displayName: displayName,
          avatarUrl: data['avatar_url'] as String?,
          level: 1,
          xp: 0,
          coins: 100,
          gamesPlayed: 0,
          createdAt: data['created_at'] != null
              ? DateTime.tryParse(data['created_at'] as String)
              : null,
        );
      }
    } catch (_) {
      // Profile fetch failed — fall back to user metadata.
    }

    // Fallback: build Player from auth user metadata.
    final username =
        user.userMetadata?['username'] as String? ??
        user.email?.split('@').first ??
        'Pilot';

    return Player(
      id: user.id,
      username: username,
      displayName: user.userMetadata?['display_name'] as String? ?? username,
      level: 1,
      xp: 0,
      coins: 100,
      gamesPlayed: 0,
      createdAt: DateTime.now(),
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }
}
