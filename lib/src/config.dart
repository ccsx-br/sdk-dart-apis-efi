import 'constants.dart';

/// This class is used to create an Object with all needed configurations used in
/// Efi API. This configurations include the Endpoints and URLs of
/// Efi API, and credential data of Efi client.

class Config {
  static final String version = '1.1.0';
  Map conf = {};

  static final Config _singleton = Config._internal();

  factory Config() {
    return _singleton;
  }

  Config._internal();

  set(Map options) {
    this.conf['sandbox'] =
        options.containsKey('sandbox') ? options['sandbox'] : false;

    this.conf['debug'] =
        options.containsKey('debug') ? options['debug'] : false;

    this.conf['clientId'] = options['client_id'];

    this.conf['clientSecret'] = options['client_secret'];

    this.conf['timeout'] =
        options.containsKey('timeout') ? options['timeout'] : 30.0;

    // Optional settings are CLEARED when absent — the singleton `conf`
    // is shared, so a later client that omits them must not inherit a
    // previous client's certificate, headers or account code.
    conf['accountId'] = options['account_id'];
    conf['certificate'] = options['certificate'];
    conf['certificateBase64'] = options['certificate_base64'];
    conf['privateKey'] = options['private_key'];
    conf['partnerToken'] = options['partner_token'];
    conf['headers'] = options['headers'];
    conf.removeWhere((_, v) => v == null);
  }

  getEndpoint(endpointName) {
    if (CONSTANTS['DEFAULT']?['ENDPOINTS'][endpointName] != null) {
      this.setBaseURL('DEFAULT');
      return CONSTANTS['DEFAULT']?['ENDPOINTS'][endpointName];
    } else if (CONSTANTS['PIX']?['ENDPOINTS'][endpointName] != null) {
      this.setBaseURL('PIX');
      return CONSTANTS['PIX']?['ENDPOINTS'][endpointName];
    } else if (CONSTANTS['OPEN-FINANCE']?['ENDPOINTS'][endpointName] != null) {
      this.setBaseURL('OPEN-FINANCE');
      return CONSTANTS['OPEN-FINANCE']?['ENDPOINTS'][endpointName];
    } else if (CONSTANTS['PAGAMENTOS']?['ENDPOINTS'][endpointName] != null) {
      this.setBaseURL('PAGAMENTOS');
      return CONSTANTS['PAGAMENTOS']?['ENDPOINTS'][endpointName];
    } else if (endpointName == 'paymentToken') {
      this.setBaseURL('DEFAULT');
    } else {
      throw new Exception("nonexistent endpoint");
    }
  }

  setBaseURL(api) {
    if (this.conf['sandbox']) {
      this.conf['baseUri'] = CONSTANTS[api]?['URL']['sandbox'];
    } else {
      this.conf['baseUri'] = CONSTANTS[api]?['URL']['production'];
    }
  }
}
