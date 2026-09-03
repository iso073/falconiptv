import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

abstract final class IptvDioClient {
  static const String userAgent = 'IPTVSmarters/1.0.0';

  static Dio create() {
    final Dio dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 90),
        sendTimeout: const Duration(seconds: 20),
        followRedirects: true,
        headers: const <String, String>{
          'User-Agent': userAgent,
          'Accept': '*/*',
        },
        validateStatus: (int? status) => status != null && status < 500,
      ),
    );

    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final HttpClient client = HttpClient();
        client.userAgent = userAgent;
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
        return client;
      },
    );
    return dio;
  }
}
