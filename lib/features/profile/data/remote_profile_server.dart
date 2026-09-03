import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'remote_profile_draft.dart';
import 'remote_profile_form_html.dart';

typedef RemoteProfileSubmit = Future<String?> Function(RemoteProfileDraft draft);

class RemoteProfileSession {
  const RemoteProfileSession({
    required this.uri,
    required this.token,
    required this.stop,
  });

  final Uri uri;
  final String token;
  final Future<void> Function() stop;
}

abstract final class RemoteProfileServer {
  static Future<RemoteProfileSession> start({
    required RemoteProfileSubmit onSubmit,
  }) async {
    final String token = _token();
    HttpServer server;
    try {
      server = await HttpServer.bind(InternetAddress.anyIPv4, 18787);
    } on SocketException {
      server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    }
    server.listen((HttpRequest request) {
      unawaited(_handle(request, token: token, onSubmit: onSubmit));
    });

    final String? ip = await localIPv4();
    if (ip == null) {
      await server.close(force: true);
      throw const SocketException(
        'Yerel ağ adresi alınamadı. Telefon ile televizyonun aynı kablosuz ağda olduğundan emin olunuz.',
      );
    }

    return RemoteProfileSession(
      uri: Uri(scheme: 'http', host: ip, port: server.port, queryParameters: <String, String>{'t': token}),
      token: token,
      stop: () => server.close(force: true),
    );
  }

  static Future<String?> localIPv4() async {
    String? fallback;
    for (final NetworkInterface interface in await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    )) {
      for (final InternetAddress address in interface.addresses) {
        if (address.isLoopback) {
          continue;
        }
        final String ip = address.address;
        fallback ??= ip;
        if (ip.startsWith('192.168.') || ip.startsWith('10.') || _isPrivate172(ip)) {
          return ip;
        }
      }
    }
    return fallback;
  }

  static bool _isPrivate172(String ip) {
    final List<String> parts = ip.split('.');
    if (parts.length != 4 || parts[0] != '172') {
      return false;
    }
    final int? second = int.tryParse(parts[1]);
    return second != null && second >= 16 && second <= 31;
  }

  static String _token() {
    const String alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final Random random = Random.secure();
    return List<String>.generate(8, (_) => alphabet[random.nextInt(alphabet.length)]).join();
  }

  static Future<void> _handle(
    HttpRequest request, {
    required String token,
    required RemoteProfileSubmit onSubmit,
  }) async {
    try {
      if (request.method == 'GET') {
        _write(
          request.response,
          status: HttpStatus.ok,
          contentType: ContentType('text', 'html', charset: 'utf-8'),
          body: RemoteProfileFormHtml.page(),
        );
        return;
      }
      if (request.method == 'POST' && request.uri.path == '/api/add') {
        final String body = await utf8.decoder.bind(request).join();
        try {
          final RemoteProfileDraft draft = RemoteProfileDraft.parse(body, expectedToken: token);
          final String? error = await onSubmit(draft);
          if (error == null) {
            _writeJson(request.response, <String, Object?>{'ok': true});
          } else {
            _writeJson(request.response, <String, Object?>{'ok': false, 'error': error}, status: HttpStatus.badRequest);
          }
        } on FormatException catch (error) {
          _writeJson(
            request.response,
            <String, Object?>{'ok': false, 'error': error.message},
            status: HttpStatus.badRequest,
          );
        } catch (_) {
          _writeJson(
            request.response,
            <String, Object?>{
              'ok': false,
              'error': 'Profil kaydedilemedi. Lütfen bilgilerinizi kontrol ediniz.',
            },
            status: HttpStatus.internalServerError,
          );
        }
        return;
      }
      _writeJson(request.response, <String, Object?>{'ok': false, 'error': 'Bulunamadı.'}, status: HttpStatus.notFound);
    } catch (_) {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  static void _write(
    HttpResponse response, {
    required int status,
    required ContentType contentType,
    required String body,
  }) {
    response
      ..statusCode = status
      ..headers.contentType = contentType
      ..write(body);
    unawaited(response.close());
  }

  static void _writeJson(HttpResponse response, Map<String, Object?> body, {int status = HttpStatus.ok}) {
    response
      ..statusCode = status
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(body));
    unawaited(response.close());
  }
}
