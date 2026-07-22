// Gate G2: the z-score engine diffed against the golden corpus.
//
// The corpus and the real assertions land with the engine implementation in
// Phase P2 (target |Δz| ≤ 0.01 across every row, plus an exact classification
// match). Until then this is a placeholder that keeps the file valid and the
// intent visible.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'engine output matches the WHO golden corpus within tolerance',
    () {
      // TODO(P2): load test/zscore/golden_corpus.json, run the engine over
      // every case, and assert |Δz| <= 0.01 and matching classification.
    },
    skip: 'Implemented in Phase P2 (Gate G2).',
  );
}
