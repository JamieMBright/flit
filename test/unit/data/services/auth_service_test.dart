import 'package:flutter_test/flutter_test.dart';

import 'package:flit/data/models/player.dart';
import 'package:flit/data/services/auth_service.dart';

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------
//
// AuthService talks directly to Supabase, so network-dependent paths
// (signIn, signUp network calls) are not exercised here. Instead the suite
// focuses on:
//
//   • AuthState defaults and immutability via copyWith
//   • Pure validation logic (_isValidEmail / username rules) exercised
//     through the pre-flight validation that runs *before* any network call
//   • AuthMethod and needsEmailConfirmation flag semantics
//   • State transitions that do not require a live Supabase client
//
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // AuthState – defaults
  // -------------------------------------------------------------------------

  group('AuthState - defaults', () {
    test('isAuthenticated is false by default', () {
      const state = AuthState();
      expect(state.isAuthenticated, isFalse);
    });

    test('isLoading is false by default', () {
      const state = AuthState();
      expect(state.isLoading, isFalse);
    });

    test('player is null by default', () {
      const state = AuthState();
      expect(state.player, isNull);
    });

    test('authMethod defaults to email', () {
      const state = AuthState();
      expect(state.authMethod, equals(AuthMethod.email));
    });

    test('email is null by default', () {
      const state = AuthState();
      expect(state.email, isNull);
    });

    test('error is null by default', () {
      const state = AuthState();
      expect(state.error, isNull);
    });

    test('needsEmailConfirmation is false by default', () {
      const state = AuthState();
      expect(state.needsEmailConfirmation, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // AuthState.copyWith
  // -------------------------------------------------------------------------

  group('AuthState.copyWith', () {
    test('copies with isAuthenticated override', () {
      const state = AuthState();
      final updated = state.copyWith(isAuthenticated: true);
      expect(updated.isAuthenticated, isTrue);
    });

    test('copies with isLoading override', () {
      const state = AuthState();
      final updated = state.copyWith(isLoading: true);
      expect(updated.isLoading, isTrue);
    });

    test('copies with error override', () {
      const state = AuthState();
      final updated = state.copyWith(error: 'something went wrong');
      expect(updated.error, equals('something went wrong'));
    });

    test('error is set to null when passed explicitly as null', () {
      const state = AuthState(error: 'old error');
      // copyWith passes error: null, which should clear it
      final updated = state.copyWith(error: null);
      expect(updated.error, isNull);
    });

    test('copies with player override', () {
      const state = AuthState();
      const player = Player(id: 'p1', username: 'flyer');
      final updated = state.copyWith(player: player);
      expect(updated.player, equals(player));
    });

    test('copies with email override', () {
      const state = AuthState();
      final updated = state.copyWith(email: 'pilot@example.com');
      expect(updated.email, equals('pilot@example.com'));
    });

    test('copies with needsEmailConfirmation override', () {
      const state = AuthState();
      final updated = state.copyWith(needsEmailConfirmation: true);
      expect(updated.needsEmailConfirmation, isTrue);
    });

    test('unchanged fields are preserved after copyWith', () {
      const player = Player(id: 'p1', username: 'flyer');
      const state = AuthState(
        isAuthenticated: true,
        player: player,
        email: 'pilot@example.com',
      );
      final updated = state.copyWith(isLoading: true);

      expect(updated.isAuthenticated, isTrue);
      expect(updated.player, equals(player));
      expect(updated.email, equals('pilot@example.com'));
      expect(updated.isLoading, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // AuthMethod enum
  // -------------------------------------------------------------------------

  group('AuthMethod enum', () {
    test('email is a valid AuthMethod value', () {
      expect(AuthMethod.values, contains(AuthMethod.email));
    });

    test('AuthMethod has exactly one value', () {
      // The service supports email-only auth; confirm no extra methods were
      // silently added.
      expect(AuthMethod.values, hasLength(1));
    });
  });

  // -------------------------------------------------------------------------
  // Email validation via signUpWithEmail
  // -------------------------------------------------------------------------
  //
  // The AuthService validates email before making any network call. We invoke
  // signUpWithEmail with an invalid email and check that:
  //   • The returned state is NOT loading (validation ran synchronously)
  //   • The error message indicates an invalid email
  //
  // Because the client calls `Supabase.instance.client` lazily (only after
  // validation passes), these tests never actually hit the Supabase client.
  // ---------------------------------------------------------------------------

  group('AuthService - email validation (pre-network guard)', () {
    late AuthService service;

    setUp(() {
      service = AuthService();
    });

    test('empty email string is rejected', () async {
      final state = await service.signUpWithEmail(
        email: '',
        password: 'password123',
        username: 'validuser',
      );

      expect(state.isLoading, isFalse);
      expect(state.error, isNotNull);
      expect(
        state.error,
        contains('valid email'),
        reason: 'Error should mention email validity',
      );
    });

    test('email missing @ symbol is rejected', () async {
      final state = await service.signUpWithEmail(
        email: 'notanemail.com',
        password: 'password123',
        username: 'validuser',
      );

      expect(state.isLoading, isFalse);
      expect(state.error, isNotNull);
    });

    test('email missing domain extension is rejected', () async {
      final state = await service.signUpWithEmail(
        email: 'user@domain',
        password: 'password123',
        username: 'validuser',
      );

      expect(state.isLoading, isFalse);
      expect(state.error, isNotNull);
    });

    test('email with spaces is rejected', () async {
      final state = await service.signUpWithEmail(
        email: 'user name@domain.com',
        password: 'password123',
        username: 'validuser',
      );

      expect(state.isLoading, isFalse);
      expect(state.error, isNotNull);
    });

    test(
      'well-formed email passes validation and proceeds to network phase',
      () async {
        // A valid email clears the email validation guard. The call will then
        // reach the username check. Since username is valid and password is
        // valid, the Supabase network call would be next — which will throw in
        // the test environment. AuthService catches all generic exceptions and
        // maps them to a user-facing "Something went wrong" error, so the state
        // will have an error but it will NOT be the email validation error.
        final state = await service.signUpWithEmail(
          email: 'pilot@example.com',
          password: 'password123',
          username: 'validuser',
        );

        // The email guard did NOT fire — no email-specific error message.
        expect(
          state.error,
          isNot(contains('valid email')),
          reason: 'A well-formed email should not trigger the email error',
        );
      },
    );
  });

  // -------------------------------------------------------------------------
  // Username validation via signUpWithEmail
  // -------------------------------------------------------------------------

  group('AuthService - username validation (pre-network guard)', () {
    late AuthService service;

    setUp(() {
      service = AuthService();
    });

    test('username shorter than 3 characters is rejected', () async {
      final state = await service.signUpWithEmail(
        email: 'pilot@example.com',
        password: 'password123',
        username: 'ab',
      );

      expect(state.isLoading, isFalse);
      expect(state.error, contains('3 characters'));
    });

    test('single character username is rejected', () async {
      final state = await service.signUpWithEmail(
        email: 'pilot@example.com',
        password: 'password123',
        username: 'x',
      );

      expect(state.isLoading, isFalse);
      expect(state.error, isNotNull);
    });

    test('username longer than 20 characters is rejected', () async {
      final state = await service.signUpWithEmail(
        email: 'pilot@example.com',
        password: 'password123',
        username: 'a' * 21,
      );

      expect(state.isLoading, isFalse);
      expect(state.error, contains('20 characters'));
    });

    test('username with spaces is rejected', () async {
      final state = await service.signUpWithEmail(
        email: 'pilot@example.com',
        password: 'password123',
        username: 'invalid user',
      );

      expect(state.isLoading, isFalse);
      expect(state.error, contains('letters, numbers, and underscores'));
    });

    test('username with special characters is rejected', () async {
      final state = await service.signUpWithEmail(
        email: 'pilot@example.com',
        password: 'password123',
        username: 'user@name',
      );

      expect(state.isLoading, isFalse);
      expect(state.error, contains('letters, numbers, and underscores'));
    });

    test('username with hyphens is rejected', () async {
      final state = await service.signUpWithEmail(
        email: 'pilot@example.com',
        password: 'password123',
        username: 'user-name',
      );

      expect(state.isLoading, isFalse);
      expect(state.error, contains('letters, numbers, and underscores'));
    });

    test('valid 3-character username passes the username guard', () async {
      final state = await service.signUpWithEmail(
        email: 'pilot@example.com',
        password: 'password123',
        username: 'ace',
      );

      // Username guard did not fire. The error (if any) comes from Supabase
      // network failure, not from our validation rules.
      expect(state.error, isNot(contains('3 characters')));
      expect(state.error, isNot(contains('20 characters')));
      expect(state.error, isNot(contains('letters, numbers')));
    });

    test('valid 20-character username passes the username guard', () async {
      final state = await service.signUpWithEmail(
        email: 'pilot@example.com',
        password: 'password123',
        username: 'a' * 20,
      );

      expect(state.error, isNot(contains('20 characters')));
    });
  });

  // -------------------------------------------------------------------------
  // Password validation via signUpWithEmail
  // -------------------------------------------------------------------------

  group('AuthService - password validation (pre-network guard)', () {
    late AuthService service;

    setUp(() {
      service = AuthService();
    });

    test('password shorter than 6 characters is rejected', () async {
      final state = await service.signUpWithEmail(
        email: 'pilot@example.com',
        password: 'abc',
        username: 'validuser',
      );

      expect(state.isLoading, isFalse);
      expect(state.error, contains('6 characters'));
    });

    test('5-character password is rejected', () async {
      final state = await service.signUpWithEmail(
        email: 'pilot@example.com',
        password: 'passw',
        username: 'validuser',
      );

      expect(state.isLoading, isFalse);
      expect(state.error, isNotNull);
    });

    test('6-character password passes the password guard', () async {
      final state = await service.signUpWithEmail(
        email: 'pilot@example.com',
        password: 'pass12',
        username: 'validuser',
      );

      expect(state.error, isNot(contains('6 characters')));
    });
  });

  // -------------------------------------------------------------------------
  // AuthService.signOut
  // -------------------------------------------------------------------------

  group('AuthService - signOut', () {
    test('signOut resets state to default (unauthenticated)', () async {
      final service = AuthService();

      // signOut may throw if Supabase is not initialised, but AuthService
      // silently swallows sign-out errors and always resets state.
      final state = await service.signOut();

      expect(state.isAuthenticated, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.player, isNull);
      expect(state.error, isNull);
      expect(state.needsEmailConfirmation, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // AuthService initial state
  // -------------------------------------------------------------------------

  group('AuthService - initial state', () {
    test('service starts in an unauthenticated, idle state', () {
      final service = AuthService();
      final state = service.state;

      expect(state.isAuthenticated, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.player, isNull);
      expect(state.error, isNull);
    });

    test('two separate AuthService instances each have their own state', () async {
      final a = AuthService();
      final b = AuthService();

      expect(a.state.isLoading, isFalse);
      expect(b.state.isLoading, isFalse);

      // Trigger a local validation failure on only one service instance.
      await a.signInWithEmail(email: 'invalid-email', password: 'password123');

      expect(a.state.error, isNotNull);
      expect(b.state.error, isNull);
    });
  });
}
