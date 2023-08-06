import 'package:e1547/interface/interface.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/mock_item.dart';

void main() {
  group('ValueCache', () {
    late ValueCache<int, MockItem> cache;

    setUp(() => cache = ValueCache(size: 3));

    tearDown(() => cache.dispose());

    test('adds values to the cache', () async {
      const key = 1;
      const value = MockItem(1);
      cache[key] = value;
      expect(cache[key], equals(value));
    });

    test('deletes values from the cache', () async {
      const key = 1;
      const value = MockItem(1);
      cache[key] = value;
      expect(cache.remove(key), equals(value));
      expect(cache[key], isNull);
    });

    test('creates values with ifAbsent', () async {
      final stream =
          cache.stream(1, ifAbsent: () => Future.value(const MockItem(1)));
      await expectLater(stream, emits(const MockItem(1)));
    });

    test('streams values', () async {
      const key = 1;
      const value = MockItem(1);
      const updatedValue = MockItem(2);
      final stream = cache.stream(key);
      List<MockItem> values = [];
      stream.listen((value) => values.add(value));
      cache[key] = value;
      await Future.value();
      cache[key] = updatedValue;
      await Future.value();
      expect(values, equals([value, updatedValue]));
    });

    test('keeps values with active listeners', () async {
      const key = 1;
      const value = MockItem(1);
      cache = ValueCache(size: 0);
      cache[key] = value;
      final stream = cache.stream(key);
      final subscription = stream.listen((_) {});
      List.generate(3, (index) => index + 1).forEach(
        (e) => cache[e] = MockItem(e),
      );
      expect(cache[key], equals(value));
      expect(cache[2], isNull);
      subscription.cancel();
      List.generate(3, (index) => index + 4).forEach(
        (e) => cache[e] = MockItem(e),
      );
      expect(cache[key], isNull);
    });

    test('updates value optimistically', () async {
      const key = 1;
      const value = MockItem(1);
      const updatedValue = MockItem(2);
      cache[key] = value;
      await cache.optimistic(key, (_) => updatedValue, () => Future.value());
      expect(cache[key], equals(updatedValue));
    });

    test('resets value if optimistic update fails', () async {
      const key = 1;
      const value = MockItem(1);
      const updatedValue = MockItem(2);
      cache[key] = value;
      expect(
        () async => cache.optimistic(
          key,
          (_) => updatedValue,
          () => Future.error(Exception('Failed update')),
        ),
        throwsException,
      );
      await Future.value();
      expect(cache[key], equals(value));
    });

    test('removes orphaned values which are stale', () async {
      const key = 1;
      const value = MockItem(1);
      cache = ValueCache(size: null, maxAge: Duration.zero);
      cache[key] = value;
      await Future.delayed(const Duration(milliseconds: 1));
      expect(cache[key], isNull);
    });

    test('removes orphaned values which exceed cache size', () async {
      const values = [
        MockItem(1),
        MockItem(2),
        MockItem(3),
        MockItem(4),
      ];
      for (final value in values) {
        cache[value.id as int] = value;
      }
      expect(cache[1], isNull);
    });
  });
}
