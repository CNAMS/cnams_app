// Device packet codec, CRC, and the age-calculation boundary at 24 months.
//
// Real assertions land with the codec and mock BLE client in Phase P2. Kept as
// a valid placeholder so the suite stays green and the intent is visible.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'packet codec round-trips frames and rejects a bad CRC',
    () {
      // TODO(P2): encode/decode a known frame, flip a byte, expect a CRC
      // failure. Also cover the recumbent/standing switch at exactly 24 months.
    },
    skip: 'Implemented in Phase P2.',
  );
}
