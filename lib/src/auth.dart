import 'dart:convert';
import 'config.dart';
import 'constants.dart';
import 'request.dart';

/// This class is used to create an authenticator Object, responsible to send
/// needed Efi credentials (Client_Id and Client_Secret) to it's API.

class Auth {
  Config _config = new Config();
  Request? _request;
  String _clientId = '';
  String _clientSecret = '';
  String _accessToken = '';
  DateTime? _expires;

  Auth() {
    this._request = new Request();

    this._clientId = this._config.conf['clientId']?.toString() ?? '';

    this._clientSecret = this._config.conf['clientSecret']?.toString() ?? '';
  }

  authorize() async {
    // The credentials are only required here — endpoints that do not go
    // through this authenticator (e.g. the public `paymentToken`
    // tokenization, authorized by `account-code`) work without them.
    if (this._clientId.isEmpty || this._clientSecret.isEmpty) {
      throw Exception('Client id or secret not found');
    }

    // The token route follows the API family the current request targets
    // (`baseUri` was resolved by `Config.getEndpoint` for it): the
    // cobranças API authorizes on `/authorize`, the Pix/Open Finance/
    // Pagamentos hosts on `/oauth/token`. The certificate only enables
    // mTLS on the transport — it does not select the route.
    final defaultUri =
        CONSTANTS['DEFAULT']?['URL'][this._config.conf['sandbox'] == true
            ? 'sandbox'
            : 'production'];
    final isDefaultApi = this._config.conf['baseUri'] == defaultUri;
    Map endpoints = {
      'route': isDefaultApi ? '/authorize' : '/oauth/token',
      'method': 'post',
    };

    dynamic requestOptions = {
      'headers': {
        'Authorization':
            "Basic " +
            base64
                .encode(utf8.encode(this._clientId + ":" + this._clientSecret))
                .toString(),
      },
      'body': {'grant_type': 'client_credentials'},
      'timeout': this._config.conf['timeout'],
    };

    if (!this._config.conf.containsKey('headers'))
      this._config.conf['headers'] = {};

    dynamic response = await this._request?.send(
      endpoints['method'],
      endpoints['route'],
      requestOptions,
    );

    this._accessToken = response['access_token'];

    // The OAuth payload answers `expire_at` (epoch seconds) on the Pix
    // endpoints and `expires_in` (seconds from now) elsewhere — accept
    // both so the token is not re-minted on every call.
    if (response['expire_at'] != null) {
      this._expires = DateTime.fromMillisecondsSinceEpoch(
        int.parse(response['expire_at'].toString()) * 1000,
      );
    } else if (response['expires_in'] != null) {
      this._expires = DateTime.now().add(
        Duration(seconds: int.parse(response['expires_in'].toString())),
      );
    }

    return;
  }

  DateTime? getExpires() {
    return this._expires;
  }

  String getAccessToken() {
    return this._accessToken;
  }
}
