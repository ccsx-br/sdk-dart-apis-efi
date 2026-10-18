import 'dart:convert';
import 'dart:io';

import 'package:efipay/src/config.dart';
import 'package:efipay/src/request.dart';
import 'package:test/test.dart';

/// `Request` tests against a loopback `HttpServer` — `Config` is a
/// process-wide singleton, so each test resets the shared `conf` map and
/// points `baseUri` at the ephemeral port.
void main() {
  late HttpServer server;
  late String baseUri;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUri = 'http://127.0.0.1:${server.port}';
    Config().conf.clear();
    Config().conf['baseUri'] = baseUri;
    Config().conf['timeout'] = 30.0;
  });

  tearDown(() async {
    await server.close();
  });

  void respondWith(int statusCode, Object body) {
    server.listen((request) {
      request.response
        ..statusCode = statusCode
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body))
        ..close();
    });
  }

  test('send returns the decoded body on a 2xx response', () async {
    respondWith(200, {'ok': true});

    final response = await Request().send('get', '/foo', {'body': {}});

    expect(response['ok'], isTrue);
  });

  test('send posts the JSON body with the sdk header', () async {
    Map<String, dynamic>? receivedBody;
    String? sdkHeader;
    server.listen((request) async {
      sdkHeader = request.headers['api-sdk']?.first;
      receivedBody =
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>;
      request.response
        ..statusCode = 200
        ..write(jsonEncode({}))
        ..close();
    });

    await Request().send('post', '/foo', {
      'body': {'hello': 'world'},
    });

    expect(receivedBody, {'hello': 'world'});
    expect(sdkHeader, startsWith('dart-'));
  });

  for (final entry in const {
    'error_description': 'oauth-style message',
    'mensagem': 'pix-style message',
    'nome': 'pix nome field',
    'message': 'generic message',
  }.entries) {
    test('a non-2xx response surfaces `${entry.key}`', () async {
      respondWith(400, {entry.key: entry.value});

      await expectLater(
        () => Request().send('get', '/foo', {'body': {}}),
        throwsA(predicate((e) => e.toString().contains(entry.value))),
      );
    });
  }

  test('a non-2xx response falls back to the violacoes list', () async {
    respondWith(400, {
      'violacoes': [
        {'razao': 'invalid field'},
      ],
    });

    await expectLater(
      () => Request().send('get', '/foo', {'body': {}}),
      throwsA(predicate((e) => e.toString().contains('invalid field'))),
    );
  });

  test('an invalid certificate_base64 fails lazily at send time', () async {
    Config().conf['certificateBase64'] = 'not-a-pem!!!';

    final request = Request();
    await expectLater(
      () => request.send('get', '/foo', {'body': {}}),
      throwsA(isA<Exception>()),
    );
  });
}
