import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:dio_http/dio_http.dart';

class DioClient {
  /// example of accessToken
  static String? _accessToken;
  /// `setter` and `getter`
  static set setAccessToken(String newToken) => _accessToken = newToken;
  static String? get accessToken => _accessToken;

  /// methods to manage Dio
  static Dio init() {
    var _dio = Dio();

    /// example baseURL
    _dio.options.baseUrl = 'http://3.36.120.200:8002';
    _dio.options.headers = {'Content-Type': 'application/json; charset=utf-8'};

    return _dio;
  }

  static Future<String> updateToken(Dio dio) async {
    /// create tokenDio to fetch new token
    var tokenDio = Dio();
    tokenDio.options = dio.options;

    /// make a request with example
    final res = await tokenDio.post('/obtain-token/',
        data: jsonEncode({'id': 'SB', 'password': '123'}));
    print('updateToken : ' + res.statusMessage!);

    /// check response
    if (res.statusCode == 200) {
      final parsedRes = res.data;
      final newAccessToken = parsedRes['result']['access'];
      // refreshToken = parsedRes['result']['refresh'];
      return newAccessToken;
    } else {
      return 'none';
    }
  }

  static Dio addInterceptor(Dio dio) {
    return dio
      ..interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) async {
          /// check if the token is null
          if (accessToken == null) {
            /// lock dio first
            dio.lock();
            final newAccessToken = await updateToken(dio);
            if (newAccessToken != 'none') {
              setAccessToken = newAccessToken;
              log('set accessToken', name: 'onRequest');

              /// change the header
              options.headers['Authorization'] = 'Bearer $newAccessToken';
              handler.next(options);
            } else {
              handler.reject(DioError(requestOptions: options));
            }
            dio.unlock();
          }

          /// already have token
          else {
            log('access token is not null', name: 'onRequest');
            options.headers['Authorization'] = 'Bearer $accessToken';
            handler.next(options);
          }
        },
        onError: (error, handler) async {
          /// status code 401 is expected when token is expired
          if (error.response?.statusCode == 401) {
            print('onError' + error.message);
            var options = error.response!.requestOptions;
            // If the token has been updated, repeat directly.
            if ('Bearer $accessToken' != options.headers['Authorization']) {
              options.headers['Authorization'] = 'Bearer $accessToken';
              //repeat
              try {
                final response = await dio.fetch(options);
                handler.resolve(response);
              } on DioError catch (e) {
                handler.reject(e);
              }
              return;
            }
            // update token and repeat
            // Lock to block the incoming request until the token updated
            dio.lock();
            dio.interceptors.responseLock.lock();
            dio.interceptors.errorLock.lock();

            final newAccessToken = await updateToken(dio);
            if (newAccessToken != 'none') {
              setAccessToken = newAccessToken;

              /// change the header
              options.headers['Authorization'] = 'Bearer $newAccessToken';
            } else {
              handler.reject(error);
            }

            dio.unlock();
            dio.interceptors.responseLock.unlock();
            dio.interceptors.errorLock.unlock();

            //repeat
            try {
              final response = await dio.fetch(options);
              handler.resolve(response);
            } on DioError catch (e) {
              handler.reject(e);
            }
            return;
          }
          return handler.next(error);
        },
      ));
  }

  /// example
  static final exampleDio = init();
  static final exampleAPI = addInterceptor(exampleDio);

  /// example API
  Future<int> httpGet(path) async {
    try {
      final res =
          await exampleAPI.get(path);
      return res.statusCode!;
    } catch (e) {
      rethrow;
    }
  }
}

void main() async {
  var _client = DioClient();

  await Future.wait([
    _client
        .httpGet('/all-stores/')
        .then((value) => print('1 success response ? $value'))
        .then((value) => Duration(seconds: 10))
        .whenComplete(() => log('completed', name: '1 request')),
    _client
        .httpGet('/all-stores/')
        .then((value) => print('1 success response ? $value'))
        .then((value) => Duration(seconds: 10))
        .whenComplete(() => log('completed', name: '2 request')),
    _client
        .httpGet('/all-stores/')
        .then((value) => print('1 success response ? $value'))
        .then((value) => Duration(seconds: 10))
        .whenComplete(() => log('completed', name: '3 request')),
    _client
        .httpGet('/all-stores/')
        .then((value) => print('1 success response ? $value'))
        .then((value) => Duration(seconds: 10))
        .whenComplete(() => log('completed', name: '4 request')),
  ]);
}
