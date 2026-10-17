import 'package:efipay/efipay.dart';
import 'package:efipay/src/config.dart';
import 'package:test/test.dart';

/// The lazy-`Auth` contract: `EfiPay` built without `client_id`/
/// `client_secret` constructs fine (the mobile `paymentToken` flow runs
/// on `account-code` alone) and only fails when an OAuth-authenticated
/// endpoint is actually called.
void main() {
  setUp(() {
    Config().conf.clear();
  });

  test('EfiPay with only account_id constructs without credentials', () {
    final efi = EfiPay({'account_id': 'identificador', 'sandbox': true});
    expect(efi, isA<EfiPay>());
  });

  test('an authenticated call without credentials throws at call time',
      () async {
    final efi = EfiPay({'sandbox': true});

    await expectLater(
      () => efi.call('detailCharge', params: {'id': 1}),
      throwsA(
        predicate((e) => e.toString().contains('Client id or secret')),
      ),
    );
  });

  test('an unknown endpoint name throws', () async {
    final efi = EfiPay({'sandbox': true});

    await expectLater(
      () => efi.call('noSuchEndpoint'),
      throwsA(predicate((e) => e.toString().contains('nonexistent'))),
    );
  });
}
