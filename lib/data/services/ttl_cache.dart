/// Lightweight in-memory TTL cache for reducing redundant Supabase reads.
///
/// Each entry expires after [ttl]. Designed for caching leaderboard and
/// friends-list results where a few seconds of staleness is acceptable.
class TtlCache<T> {
  TtlCache(this.ttl);

  final Duration ttl;
  final _entries = <String, _CacheEntry<T>>{};

  /// Returns the cached value for [key], or `null` if missing/expired.
  T? get(String key) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (DateTime.now().isAfter(entry.expiry)) {
      _entries.remove(key);
      return null;
    }
    return entry.value;
  }

  /// Stores [value] under [key] with a fresh TTL.
  void set(String key, T value) {
    _entries[key] = _CacheEntry(value, DateTime.now().add(ttl));
  }

  /// Invalidate a single [key], or all entries if [key] is null.
  void invalidate([String? key]) {
    if (key != null) {
      _entries.remove(key);
    } else {
      _entries.clear();
    }
  }
}

class _CacheEntry<T> {
  _CacheEntry(this.value, this.expiry);
  final T value;
  final DateTime expiry;
}
