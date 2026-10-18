import 'config.dart';
import 'auth.dart';
import 'exception/authorization_exception.dart';
import 'request.dart';

/// This class instance a Auth Object, to authenticate client credentials in
/// Efi API. After client's credentials are validated a client Object
/// send a given request body to a given endpoint throw a given route.

class ApiRequest {
  Request? _request;
  Auth? _auth;
  Config _config = new Config();

  ApiRequest() {
    this._request = new Request();
    // `Auth` is built lazily (see [_requireAuth]) — endpoints that do not
    // need OAuth credentials (the public `paymentToken` tokenization
    // runs on `account-code` alone) must work in a process that never
    // configured `client_id`/`client_secret`, e.g. a Flutter app.
  }

  /// The authenticator — created on the first authenticated call so the
  /// credentials check only fires when an endpoint actually needs it.
  Auth _requireAuth() {
    this._auth ??= new Auth();
    return this._auth!;
  }

  Future<dynamic> send(
    String method,
    String route,
    Map<String, dynamic> requestOptions,
  ) async {
    try {
      final auth = _requireAuth();
      DateTime? expireDate = auth.getExpires();

      if (expireDate == null || expireDate.compareTo(new DateTime.now()) <= 0)
        await auth.authorize();

      requestOptions['headers'] = {
        'Authorization': 'Bearer ${auth.getAccessToken()}',
      };

      requestOptions['timeout'] = this._config.conf.containsKey('timeout')
          ? double.parse(this._config.conf['timeout'].toString())
          : 30.0;

      dynamic response = await this._request?.send(
        method,
        route,
        requestOptions,
      );

      return response;
    } on AuthorizationException {
      final auth = _requireAuth();
      await auth.authorize();
      requestOptions['headers'] = {
        'Authorization': 'Bearer ${auth.getAccessToken()}',
      };
      return this._request?.send(method, route, requestOptions);
    }
  }
}
