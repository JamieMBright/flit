/// Lightweight in-memory TTL cache for reducing redundant Supabase reads.
///
/// Each entry expires after [ttl]. Designed for caching leaderboard and
/// friends-list results where a few seconds of staleness is acceptable.
///
/// [maxSize] caps the number of entries in the cache (default 500). When a
/// new entry would exceed the cap, the oldest-inserted entry is evicted first.
class TtlCache<T> {
  TtlCache(this.ttl, {this.maxSize = 500});

  final Duration ttl;
  final int maxSize;

  // LinkedHashMap preserves insertion order, enabling O(1) oldest-entry eviction.
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
  ///
  /// If the cache is at [maxSize] capacity, the oldest-inserted entry is
  /// evicted before inserting the new one.
  void set(String key, T value) {
    // Remove existing entry first so the new insertion goes to the end
    // (preserving correct eviction order on re-insertion).
    _entries.remove(key);

    if (_entries.length >= maxSize) {
      // Evict the oldest entry (first key in insertion-order map).
      _entries.remove(_entries.keys.first);
    }

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
