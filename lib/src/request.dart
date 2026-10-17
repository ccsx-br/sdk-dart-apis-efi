import 'dart:convert';
import 'dart:io';
import 'config.dart';
import 'exception/authorization_exception.dart';

/// This class is responsible to create an HttpClient Object, generate the
/// request body and send it to a given endpoint. The send method return a
/// response for that request
class Request {
  HttpClient? _client;
  final Config _config = Config();
  bool _initialized = false;

  /// Lazily builds the [HttpClient] on the first [send] — including the
  /// mTLS `SecurityContext` when a `certificate` (path to a PEM bundle
  /// with the chain and the private key) or `certificate_base64` (the
  /// same PEM encoded in base64, materialized to a temporary file so
  /// `SecurityContext` can read it) is configured. Awaiting it here
  /// removes the race the previous constructor-based initialization
  /// created — the async certificate load could still be in flight when
  /// the first mTLS request fired.
  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    _initialized = true;
    if (_config.conf.containsKey('certificate') ||
        _config.conf.containsKey('certificateBase64')) {
      await _addCerts();
    }
    _client ??= HttpClient();
  }

  Future<dynamic> send(
    String method,
    String route,
    dynamic requestOptions,
  ) async {
    await _ensureInitialized();
    HttpClientRequest request = await _client!.openUrl(
      method,
      Uri.parse(_config.conf['baseUri'] + route),
    );

    if (requestOptions.containsKey('headers'))
      requestOptions['headers'].keys.forEach(
        (k) => request.headers.add(k, requestOptions['headers'][k]),
      );

    if (_config.conf.containsKey('headers'))
      _config.conf['headers'].keys.forEach(
        (k) => request.headers.add(k, _config.conf['headers'][k]),
      );

    request.headers.add('Content-Type', 'application/json');
    request.headers.add('api-sdk', 'dart-${Config.version}');

    if (_config.conf['partnerToken'] != null &&
        _config.conf['partnerToken'] != '')
      request.headers.add('partner-token', _config.conf['partnerToken']);

    String bodyEncode = json.encode(requestOptions['body']);

    List<int> bodyutf = utf8.encode(bodyEncode);

    request.contentLength = bodyutf.length;

    request.add(bodyutf);

    HttpClientResponse response = await request.close();

    if (response.statusCode == 401)
      throw AuthorizationException(response.statusCode.toString());

    String reply = await response.transform(utf8.decoder).join();

    if (reply != "") {
      Map responseDecode = json.decode(reply);

      if (response.statusCode > 299 || response.statusCode < 200) {
        throw Exception(
          "Erro ao realizar requisição. \n code: " +
              response.statusCode.toString() +
              " \n message: " +
              _errorMessage(responseDecode),
        );
      }
      return responseDecode;
    }
  }

  /// Extracts the most informative message of an Efi error payload — the
  /// API answers different shapes per endpoint family: `error_description`
  /// (OAuth/API errors), `mensagem` or `nome`/`violacoes` (Pix API errors)
  /// and the plain `error`/`message` keys.
  String _errorMessage(Map responseDecode) {
    for (final key in const [
      'error_description',
      'mensagem',
      'nome',
      'message',
      'error',
    ]) {
      if (responseDecode[key] != null) {
        return responseDecode[key].toString();
      }
    }
    // Pix-style violation list — surface the first detail when present.
    final violations = responseDecode['violacoes'];
    if (violations is List && violations.isNotEmpty) {
      return violations.first.toString();
    }
    return responseDecode.toString();
  }

  Future<void> _addCerts() async {
    SecurityContext context = SecurityContext.defaultContext;

    // `certificate` points to a PEM file; `certificate_base64` carries the
    // same PEM bundle encoded — handy for secrets stored as a single
    // base64 string (Cloud Run/CI) — it is materialized on a temporary
    // file so the SecurityContext can load the chain and the key.
    String? certificatePath = _config.conf['certificate'];
    String? materializedPath;
    try {
      if (certificatePath == null || certificatePath.isEmpty) {
        final encoded = _config.conf['certificateBase64']?.toString() ?? '';
        final pemBytes = base64.decode(encoded);
        final tempFile = await File(
          '${Directory.systemTemp.path}/efi_certificate_${encoded.hashCode.abs()}.pem',
        ).writeAsBytes(pemBytes, flush: true);
        certificatePath = tempFile.path;
        materializedPath = tempFile.path;
      }

      final certificateFile = File(certificatePath);
      final certificateBytes = await certificateFile.readAsBytes();

      context.useCertificateChainBytes(certificateBytes);
      context.usePrivateKeyBytes(certificateBytes);
    } catch (e) {
      // A failed materialization must not leave a half-written PEM
      // behind — clean it up so the next attempt writes it again.
      if (materializedPath != null) {
        try {
          await File(materializedPath).delete();
        } catch (_) {}
      }
      rethrow;
    }

    _client = HttpClient(context: context);
  }
}
