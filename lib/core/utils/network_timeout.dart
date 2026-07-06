import 'dart:async';

/// Default network timeout applied to Supabase / HTTP calls.
///
/// Without a timeout, a request made while offline (or against an unreachable
/// backend) hangs until the OS-level socket timeout — often 30-120s — during
/// which the UI spins forever. 8s is long enough for a slow-but-alive mobile
/// connection and short enough that "you're offline" surfaces quickly.
const Duration kNetworkTimeout = Duration(seconds: 8);

/// Thrown when a wrapped network call exceeds its timeout. Distinct from a
/// generic [TimeoutException] so UI code can show an "offline / try again"
/// state rather than a generic error.
class NetworkTimeoutException implements Exception {
  const NetworkTimeoutException([this.label]);

  /// Optional human-readable label of the operation that timed out.
  final String? label;

  @override
  String toString() =>
      'NetworkTimeoutException${label == null ? '' : ' ($label)'}: '
      'the network request took too long. Check your connection.';
}

/// Applies [kNetworkTimeout] (or [timeout]) to any [Future], including Supabase
/// Postgrest builders (which implement [Future]). On expiry it throws a
/// [NetworkTimeoutException] instead of hanging.
///
/// Usage:
/// ```dart
/// final rows = await withNetworkTimeout(
///   _client.from('scores').select(),
///   label: 'load scores',
/// );
/// ```
Future<T> withNetworkTimeout<T>(
  Future<T> future, {
  Duration timeout = kNetworkTimeout,
  String? label,
}) {
  return future.timeout(
    timeout,
    onTimeout: () => throw NetworkTimeoutException(label),
  );
}

/// Extension form for call sites that read more naturally fluent.
extension NetworkTimeoutExtension<T> on Future<T> {
  Future<T> withNetworkTimeout({
    Duration timeout = kNetworkTimeout,
    String? label,
  }) {
    return this.timeout(
      timeout,
      onTimeout: () => throw NetworkTimeoutException(label),
    );
  }
}
