import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:rxdart/rxdart.dart';

export 'package:dio_cache_interceptor/dio_cache_interceptor.dart';

/// An LRU and TTL Cache where entries with active listeners are kept indefinitely.
class ValueCache<K, V> extends MapBase<K, V> {
  ValueCache({
    this.size = 1000,
    this.maxAge,
  });

  /// The amount of children with no active listeners that remain in the cache.
  ///
  /// If null, the cache is unbounded.
  final int? size;

  /// The maximum amount of time a value is kept without being re-requested.
  ///
  /// If null, values are never stale.
  final Duration? maxAge;

  /// The internal cache.
  final Map<K, ValueCacheEntry<V>> _cache = {};

  /// Used to create a new cache entry.
  ///
  /// Can be overridden to use a custom entry type.
  @protected
  ValueCacheEntry<V> createEntry(V? value) => ValueCacheEntry(value);

  ValueCacheEntry<V> _create(V? value) {
    _trim();
    ValueCacheEntry<V> entry = createEntry(value);
    entry.maxAge = maxAge;
    return entry;
  }

  @override
  V? operator [](Object? key) => _cache[key]?.value;

  @override
  void operator []=(K key, V value) => _cache.update(
        key,
        (entry) => entry..value = value,
        ifAbsent: () => _create(value),
      );

  /// Returns a stream for the value corresponding to [key].
  /// If the value is updated, the new value will be emitted.
  ///
  /// Listening to this stream enables the value to be kept in memory.
  /// Once the stream listener is removed, the value may be removed by the LRU / TTL evicting strategy.
  ///
  /// Also see [ValueCacheEntry.stream].
  Stream<V> stream(
    K key, {
    FutureOr<V> Function()? ifAbsent,
    Duration? maxAge,
  }) {
    _cache.putIfAbsent(key, () => _create(null));
    return _cache[key]!.stream(
      ifAbsent: ifAbsent,
      maxAge: maxAge ?? this.maxAge,
    );
  }

  /// Optimistically updates a value.
  /// If [callback] throws, the value is rolled back.
  /// [update] must therefore not modify the value, but return a copy.
  ///
  /// Will not add the value if it is not already present.
  Future<void> optimistic(
    K key,
    V Function(V value) update,
    FutureOr<void> Function() callback,
  ) async {
    V? old = this[key];
    try {
      if (old != null) {
        this[key] = update(old);
      }
      await callback();
    } on Exception {
      if (old != null) {
        this[key] = old;
      }
      rethrow;
    }
  }

  /// Removes entries with no listeners.
  ///
  /// Checks against both [size] and [maxAge].
  void _trim() {
    List<MapEntry<K, ValueCacheEntry<V>>> orphaned =
        _cache.entries.whereNot((e) => e.value.hasListeners).toList();
    orphaned.sortBy((e) => e.value);
    List<MapEntry<K, ValueCacheEntry<V>>> removing = [];
    int? size = this.size;
    if (size != null) {
      int taking = max(0, orphaned.length + 1 - size);
      removing.addAll(orphaned.take(taking));
      orphaned.removeWhere(removing.contains);
    }
    Duration? maxAge = this.maxAge;
    if (maxAge != null) {
      removing.addAll(orphaned.where((e) => e.value.stale));
      orphaned.removeWhere(removing.contains);
    }
    for (final entry in removing) {
      remove(entry.key);
    }
  }

  @override
  void clear() {
    for (final entry in _cache.entries) {
      entry.value.dispose();
    }
    _cache.clear();
  }

  @override
  Iterable<K> get keys => _cache.keys;

  @override
  V? remove(Object? key) {
    ValueCacheEntry<V>? entry = _cache.remove(key);
    V? value = entry?.value;
    entry?.dispose();
    return value;
  }

  /// Frees all resources associated with this cache.
  /// All streams will be closed and all values will be removed.
  void dispose() => clear();
}

/// A class for storing values in a [ValueCache].
///
/// Takes care of holding various metadata about the value.
/// This includes the time it was created, the last time it was accessed, and the maximum age.
abstract class ValueCacheEntry<V> implements Comparable<ValueCacheEntry<V>> {
  /// Creates a [SingleValueCacheEntry].
  factory ValueCacheEntry(V? value) = SingleValueCacheEntry<V>;

  /// Constructor for subclasses.
  ValueCacheEntry.raw();

  /// The value of this cache entry.
  ///
  /// Accessing or updating this value will update the last accessed time.
  /// If the value is stale according to [maxAge], this will return null.
  /// Updating the value will reset its created time.
  V? get value;
  set value(V? value);

  /// The time this value was created.
  /// This is reset when the value is updated.
  DateTime get created;

  /// The last time this value was accessed.
  DateTime get accessed;

  /// The maximum age of this value.
  /// If null, the value will not expire.
  Duration? get maxAge;
  set maxAge(Duration? maxAge);

  /// Whether this value is stale.
  ///
  /// If [maxAge] is null, this will always return false.
  /// A value is stale if it has been created more than [maxAge] ago.
  bool get stale;

  /// Whether this value has active listeners.
  bool get hasListeners;

  /// Returns a stream of this value.
  /// If the value is updated, the new value will be emitted.
  ///
  /// If [value] is null, [ifAbsent] will be called to populate it, if provided.
  /// If [ifAbsent] is called, [maxAge] will be used as the time to live for the value.
  Stream<V> stream({
    FutureOr<V> Function()? ifAbsent,
    Duration? maxAge,
  });

  /// Frees all resources associated with this cache entry.
  /// All streams will be closed and the value will be removed.
  void dispose() {}

  @override
  int compareTo(ValueCacheEntry<V> other) {
    if (stale && !other.stale) {
      return -1;
    } else if (!stale && other.stale) {
      return 1;
    } else {
      return accessed.compareTo(other.accessed);
    }
  }
}

class SingleValueCacheEntry<V> extends ValueCacheEntry<V> {
  /// Holds a [ValueCache] value.
  SingleValueCacheEntry(V? value)
      : _value = value,
        super.raw();

  V? _value;

  @override
  V? get value {
    _accessed = DateTime.now();
    if (_maxAge != null && _accessed.difference(_created) > _maxAge!) {
      return null;
    }
    return _value;
  }

  @override
  set value(V? value) {
    if (value == null) return;
    _accessed = DateTime.now();
    _created = _accessed;
    if (_value == value) return;
    _value = value;
    for (final stream in _streams) {
      stream.add(value);
    }
  }

  DateTime _created = DateTime.now();

  @override
  DateTime get created => _created;

  DateTime _accessed = DateTime.now();

  @override
  DateTime get accessed => _accessed;

  Duration? _maxAge;

  @override
  Duration? get maxAge => _maxAge;

  @override
  set maxAge(Duration? value) {
    _accessed = DateTime.now();
    _maxAge = value;
  }

  @override
  bool get stale =>
      _maxAge != null && DateTime.now().difference(_created) > _maxAge!;

  final List<StreamController<V>> _streams = [];

  @override
  bool get hasListeners => _streams.any((e) => e.hasListener);

  @override
  Stream<V> stream({
    FutureOr<V> Function()? ifAbsent,
    Duration? maxAge,
  }) {
    _accessed = DateTime.now();
    late BehaviorSubject<V> controller;
    controller = BehaviorSubject<V>(
      onListen: () async {
        _streams.add(controller);
        if (ifAbsent != null && !controller.hasValue) {
          value = await ifAbsent();
          this.maxAge = maxAge;
        }
      },
      onCancel: () {
        _streams.remove(controller);
        controller.close();
      },
    );

    V? initial = value;
    if (initial != null) {
      controller.add(initial);
    }

    return controller.stream;
  }

  @override
  void dispose() {
    _value = null;
    for (final stream in _streams) {
      stream.close();
    }
    _streams.clear();
  }
}

class PagedValueCache<K, I, V> extends ValueCache<K, List<V>> {
  PagedValueCache({
    required this.toId,
    super.size = 100,
    int? pageSize,
    super.maxAge,
  }) : items = ValueCache<I, V>(
          size: size != null ? size * (pageSize ?? 10) : null,
          maxAge: maxAge,
        );

  /// Maps items to ids.
  final I Function(V value) toId;

  /// The cache of items that backs this page cache.
  ///
  /// This is shared by all pages.
  final ValueCache<I, V> items;

  @override
  @protected
  ValueCacheEntry<List<V>> createEntry(List<V>? value) {
    return PagedValueCacheEntry<I, V>(
      value: value,
      items: items,
      toId: toId,
    );
  }

  @override
  void dispose() {
    items.dispose();
    super.dispose();
  }
}

class PagedValueCacheEntry<I, V> extends ValueCacheEntry<List<V>> {
  PagedValueCacheEntry({
    List<V>? value,
    required this.items,
    required this.toId,
  }) : super.raw() {
    this.value = value;
  }

  /// The cache of items that backs this page cache.
  final ValueCache<I, V> items;

  /// Maps items to ids.
  final I Function(V value) toId;

  /// A stream of the page's items.
  ///
  /// This is necessary to keep all the page's items alive in the item cache.
  final BehaviorSubject<List<V>> _stream = BehaviorSubject();

  /// The subscription to the combined stream of the page's items.
  StreamSubscription<List<V>>? _subscription;

  @override
  List<V>? get value {
    _accessed = DateTime.now();
    if (_maxAge != null && _accessed.difference(_created) > _maxAge!) {
      return null;
    }
    return _stream.valueOrNull;
  }

  @override
  set value(List<V>? value) {
    if (value == null) return;
    _accessed = DateTime.now();
    _created = _accessed;
    List<I> ids = [];
    List<StreamSubscription<V>> keepAlives = [];
    for (final item in value) {
      final itemId = toId(item);
      // Freshly created items are immediately marked as orphaned,
      // if they have no listeners. We therefore add a no-op listener
      // to keep them alive until we actually subscribe to them.
      keepAlives.add(items.stream(itemId).listen((_) {}));
      items[itemId] = item;
      ids.add(itemId);
    }
    Stream<List<V>> source;
    if (ids.isNotEmpty) {
      source = CombineLatestStream.list<V>(ids.map(items.stream)).map(List.of);
    } else {
      // If there are no items, we need to emit an empty list.
      // Otherwise, the stream will never emit.
      source = Stream.value([]);
    }
    _subscription?.cancel();
    _subscription = source.listen(
      _stream.add,
      onError: _stream.addError,
      onDone: () => _subscription?.cancel(),
    );
    keepAlives.forEach((e) => e.cancel());
  }

  DateTime _created = DateTime.now();

  @override
  DateTime get created => _created;

  DateTime _accessed = DateTime.now();

  @override
  DateTime get accessed => _accessed;

  Duration? _maxAge;

  @override
  Duration? get maxAge => _maxAge;

  @override
  set maxAge(Duration? value) {
    _accessed = DateTime.now();
    _maxAge = value;
  }

  @override
  bool get stale =>
      _maxAge != null && DateTime.now().difference(_created) > _maxAge!;

  @override
  bool get hasListeners => _stream.hasListener;

  @override
  Stream<List<V>> stream({
    FutureOr<List<V>> Function()? ifAbsent,
    Duration? maxAge,
  }) {
    _accessed = DateTime.now();
    late BehaviorSubject<List<V>> controller;
    late StreamSubscription<List<V>> subscription;
    controller = BehaviorSubject<List<V>>(
      onListen: () async {
        if (ifAbsent != null && value == null) {
          value = await ifAbsent();
          this.maxAge = maxAge;
        }
        subscription = _stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: () {
            subscription.cancel();
            controller.close();
          },
        );
      },
      onCancel: () {
        subscription.cancel();
        controller.close();
      },
    );
    return controller.stream;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _stream.close();
  }
}
