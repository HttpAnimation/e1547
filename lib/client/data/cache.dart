import 'package:dio/dio.dart';
import 'package:e1547/client/client.dart';
import 'package:e1547/interface/interface.dart';

class DioPagedValueCache<I, V> extends PagedValueCache<String, I, V> {
  DioPagedValueCache({
    required this.dio,
    required super.toId,
    super.size,
    super.pageSize,
    super.maxAge,
    this.pageQueryKey,
  });

  /// The dio client to use for fetching.
  final Dio dio;

  /// The key used in query parameters for the page number.
  ///
  /// This is used to clear all cached pages with the same path.
  final String? pageQueryKey;

  /// Composes the request options for the given parameters.
  ///
  /// See also [Dio.request].
  RequestOptions _compose(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
  }) =>
      (options ?? Options()).compose(
        dio.options,
        path,
        data: data,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        sourceStackTrace: StackTrace.current,
      );

  /// Returns a stream wrapped in a future of an item for the given request.
  ///
  /// See also
  /// - [stream]
  /// - [StreamFuture]
  StreamFuture<V> request(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
    required V Function(Response) parse,
    required I key,
  }) {
    RequestOptions request = _compose(
      path,
      data: data,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: options,
    );
    if (request.isForceRefresh) {
      items.remove(key);
    }
    return items.stream(
      key,
      ifAbsent: () async {
        Response response = await dio.fetch(request);
        return parse(response);
      },
    ).future;
  }

  /// Returns a stream of a page for the given request.
  ///
  /// See also [stream].
  StreamFuture<List<V>> requestPage(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
    Options? options,
    required List<V> Function(Response) parse,
  }) {
    RequestOptions request = _compose(
      path,
      data: data,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: options,
    );
    if (request.isForceRefresh) {
      if (pageQueryKey != null) {
        Uri source = request.uri;
        source.replace(
          queryParameters: Map.from(source.queryParameters)
            ..removeWhere((key, value) => key == pageQueryKey),
        );
        removeWhere((key, value) {
          Uri target = Uri.parse(key);
          target.replace(
            queryParameters: Map.from(target.queryParameters)
              ..removeWhere((key, value) => key == pageQueryKey),
          );
          return target == source;
        });
      } else {
        remove(request.uri.toString());
      }
    }
    return stream(
      request.uri.toString(),
      ifAbsent: () async {
        Response response = await dio.fetch(request);
        return parse(response);
      },
    ).future;
  }
}

int deepHash(dynamic value) {
  if (value is Iterable) {
    return Object.hashAll(value.map((e) => deepHash(e)));
  } else if (value is Map) {
    return deepHash(value.entries);
  } else if (value is MapEntry) {
    return deepHash([value.key, value.value]);
  } else {
    return value.hashCode;
  }
}
