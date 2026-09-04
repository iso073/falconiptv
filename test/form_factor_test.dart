import 'package:falconiptv/core/device/form_factor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Leanback TV is television even without other flags', () {
    expect(
      classifyDevice(const DeviceSignals(leanback: true)),
      DeviceKind.television,
    );
  });

  test('UI mode television covers OEM boxes without Leanback', () {
    expect(
      classifyDevice(const DeviceSignals(uiModeTelevision: true)),
      DeviceKind.television,
    );
  });

  test('deprecated television feature is television', () {
    expect(
      classifyDevice(const DeviceSignals(televisionFeature: true)),
      DeviceKind.television,
    );
  });

  test('Fire TV feature is television', () {
    expect(
      classifyDevice(const DeviceSignals(fireTv: true)),
      DeviceKind.television,
    );
  });

  test('phone and tablet have no TV signals', () {
    expect(classifyDevice(const DeviceSignals()), DeviceKind.phone);
  });

  test('watch is never television', () {
    expect(
      classifyDevice(const DeviceSignals(watch: true, leanback: true)),
      DeviceKind.phone,
    );
  });

  test('automotive is never television', () {
    expect(
      classifyDevice(const DeviceSignals(automotive: true, uiModeTelevision: true)),
      DeviceKind.phone,
    );
  });

  test('channel map with Leanback classifies as television', () {
    expect(
      DeviceSignals.tryParse({
        'leanback': true,
        'leanbackOnly': false,
        'televisionFeature': false,
        'uiModeTelevision': true,
        'fireTv': false,
        'watch': false,
        'automotive': false,
      }),
      isNotNull,
    );
    expect(
      classifyDevice(
        DeviceSignals.tryParse({
          'leanback': true,
          'uiModeTelevision': true,
        })!,
      ),
      DeviceKind.television,
    );
  });
}
