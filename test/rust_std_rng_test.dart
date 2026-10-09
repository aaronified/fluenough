import 'package:flutter_test/flutter_test.dart';
import 'package:fluenough/core/scheduling/rust_std_rng.dart';

/// The port of Rust's `StdRng` against Rust itself: every expected value
/// below was printed by rand 0.9.5 (`StdRng::seed_from_u64`, `next_u32`
/// and `SliceRandom::shuffle`), the version `fsrs-rs` 6.6.2 locks, from
/// the fsrs-rs harness's `rng` binary.
void main() {
  List<int> words(int seed, int n) {
    final rng = RustStdRng.seedFromU64(seed);
    return <int>[for (var i = 0; i < n; i++) rng.nextU32()];
  }

  List<List<int>> shuffles(int seed, int length, int times) {
    final rng = RustStdRng.seedFromU64(seed);
    final list = <int>[for (var i = 0; i < length; i++) i];
    final out = <List<int>>[];
    for (var i = 0; i < times; i++) {
      rng.shuffle(list);
      out.add(List<int>.of(list));
    }
    return out;
  }

  group('next_u32', () {
    test("fsrs-rs's seed, 2023, past the first 16-word block", () {
      expect(words(2023, 20), <int>[
        735633102, 1016027681, 3247234690, 1683510550, 479679860, //
        1925742188, 4000639327, 1991037199, 1215978289, 917645115,
        2078948571, 2892239238, 4109145066, 1019052881, 3883562631,
        663750460, 180278126, 3771476871, 3691084927, 4269581390,
      ]);
    });

    test('far into the stream: words 1028 to 1030', () {
      expect(words(2023, 1030).sublist(1027), <int>[
        32963502,
        2671715028,
        2179456122,
      ]);
    });

    test('seed 0, and u64::MAX passed as -1', () {
      expect(words(0, 4), <int>[
        3442241407,
        3140108210,
        2384947579,
        3321986196,
      ]);
      expect(words(-1, 4), <int>[775774136, 262641736, 1091716766, 171143348]);
    });
  });

  group('shuffle', () {
    test('five batches over five epochs, from 2023', () {
      expect(shuffles(2023, 5, 5), <List<int>>[
        [0, 3, 1, 4, 2],
        [3, 2, 4, 0, 1],
        [2, 3, 1, 0, 4],
        [4, 3, 2, 0, 1],
        [3, 2, 0, 1, 4],
      ]);
    });

    test('two batches', () {
      expect(shuffles(2023, 2, 6), <List<int>>[
        [0, 1],
        [1, 0],
        [0, 1],
        [0, 1],
        [1, 0],
        [1, 0],
      ]);
    });

    test('14 items: 13! does not fit in 32 bits, so a second number is '
        'drawn', () {
      expect(shuffles(2023, 14, 3), <List<int>>[
        [10, 6, 11, 4, 5, 2, 9, 12, 0, 13, 8, 1, 3, 7],
        [7, 6, 10, 0, 1, 12, 5, 8, 4, 11, 13, 3, 2, 9],
        [5, 13, 6, 9, 4, 0, 7, 8, 1, 11, 12, 2, 3, 10],
      ]);
    });

    test('30 items, from 7', () {
      expect(shuffles(7, 30, 2).map((order) => order.join(' ')), <String>[
        '18 3 21 25 15 28 16 29 13 19 17 12 26 8 6 23 2 24 1 22 11 4 9 20 10 '
            '14 27 0 7 5',
        '25 7 10 27 29 28 9 26 19 21 6 3 1 11 14 20 12 15 22 17 23 18 5 2 13 '
            '16 4 24 8 0',
      ]);
    });

    test('nothing to shuffle draws nothing', () {
      final rng = RustStdRng.seedFromU64(2023);
      rng
        ..shuffle(<int>[])
        ..shuffle(<int>[0]);
      expect(rng.nextU32(), 735633102);
    });
  });
}
