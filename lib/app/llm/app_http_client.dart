import 'package:dio/dio.dart';

class AppHttpClient {
  static Dio? _instance;

  AppHttpClient._();

  static Dio get shared {
    _instance ??= _create();
    return _instance!;
  }

  static Dio _create() {
    return Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 120),
      sendTimeout: const Duration(seconds: 30),
      responseType: ResponseType.stream,
      validateStatus: (_) => true,
      headers: {'Content-Type': 'application/json'},
    ));
  }

  static void addInterceptor(Interceptor interceptor) {
    final type = interceptor.runtimeType;
    shared.interceptors.removeWhere((i) => i.runtimeType == type);
    shared.interceptors.add(interceptor);
  }

  static void reset() {
    _instance?.close(force: true);
    _instance = null;
  }
}
