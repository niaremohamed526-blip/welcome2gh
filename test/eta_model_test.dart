import 'package:flutter_test/flutter_test.dart';
import 'package:welcome2gh/core/eta_model.dart';

void main() {
  group('EtaModel', () {
    test('walking time is realistic (~4.7 km/h)', () {
      // 1 km on foot should be ~12–14 min, never an absurd value.
      final m = EtaModel.minutes(
          profile: 'foot', distanceMeters: 1000, apiDurationSec: 0, turns: 0);
      expect(m, inInclusiveRange(12, 14));
    });

    test('cycling time is realistic (~15 km/h)', () {
      // 3 km by bike ~12 min.
      final m = EtaModel.minutes(
          profile: 'cycling', distanceMeters: 3000, apiDurationSec: 0, turns: 0);
      expect(m, inInclusiveRange(11, 14));
    });

    test('modes are ordered sanely: walking slowest, car fastest', () {
      const d = 3000.0;
      final walk = EtaModel.minutes(
          profile: 'foot', distanceMeters: d, apiDurationSec: d / 1.4, turns: 5);
      final bike = EtaModel.minutes(
          profile: 'cycling', distanceMeters: d, apiDurationSec: d / 4, turns: 5);
      final car = EtaModel.minutes(
          profile: 'driving', distanceMeters: d, apiDurationSec: d / 8, turns: 5);
      expect(walk > bike, isTrue, reason: 'walking must be slower than cycling');
      expect(bike >= car, isTrue, reason: 'cycling not faster than driving free-flow');
    });

    test('car ETA is never absurdly fast (speed floor)', () {
      // Engine claims 1 min for 5 km (absurd). Model floors to ~5km/40km/h.
      final m = EtaModel.minutes(
          profile: 'driving', distanceMeters: 5000, apiDurationSec: 60, turns: 0);
      expect(m, greaterThanOrEqualTo(7));
    });

    test('car ETA pads the engine duration for urban congestion', () {
      // 10 min free-flow -> ~13 min after the 1.3x congestion factor.
      final m = EtaModel.minutes(
          profile: 'driving', distanceMeters: 6000, apiDurationSec: 600, turns: 0);
      expect(m, inInclusiveRange(13, 15));
    });

    test('detourRatio flags long routes', () {
      expect(EtaModel.detourRatio(routeMeters: 2000, straightMeters: 1000), 2.0);
      expect(EtaModel.detourRatio(routeMeters: 1000, straightMeters: 0), 1.0);
    });
  });
}
