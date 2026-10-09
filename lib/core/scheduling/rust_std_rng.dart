import 'dart:typed_data';

/// Rust's `rand::rngs::StdRng`, as rand 0.9.5 has it (the version
/// `fsrs-rs` 6.6.2 locks): ChaCha12 from rand_chacha 0.9.0, seeded by
/// rand_core 0.9.5's `seed_from_u64`, with `SliceRandom::shuffle`. Given
/// the same seed it gives the same numbers and the same shuffles, which is
/// what lets `FsrsFit` put its batches in `fsrs-rs`'s order.
///
/// Checked against Rust's own output in `test/rust_std_rng_test.dart`.
/// Uses 64-bit integer arithmetic, as the Dart VM does it; not for the web.
class RustStdRng {
  /// rand_core 0.9.5 `seed_from_u64`: PCG32 fills the 32-byte key, four
  /// bytes at a time, little-endian.
  RustStdRng.seedFromU64(int seed) {
    var state = seed;
    for (var i = 0; i < 8; i++) {
      // 6364136223846793005 and 11634580027462260723, wrapping mod 2^64.
      state = state * 6364136223846793005 + -6812164046247290893;
      final xorshifted = (((state >>> 18) ^ state) >>> 27) & _mask32;
      _input[4 + i] = _rotateRight(xorshifted, state >>> 59);
    }
    // "expand 32-byte k"; words 12-13 count blocks, 14-15 (the stream) are 0.
    _input
      ..[0] = 0x61707865
      ..[1] = 0x3320646e
      ..[2] = 0x79622d32
      ..[3] = 0x6b206574;
  }

  static const int _mask32 = 0xFFFFFFFF;

  final Uint32List _input = Uint32List(16);
  final Uint32List _block = Uint32List(16);
  final Uint32List _x = Uint32List(16);
  int _index = 16;
  int _counter = 0;

  static int _rotateRight(int x, int n) =>
      n == 0 ? x : ((x >>> n) | (x << (32 - n))) & _mask32;

  static int _rotateLeft(int x, int n) =>
      ((x << n) | (x >>> (32 - n))) & _mask32;

  /// `next_u32`: the ChaCha12 keystream, one 32-bit word at a time.
  int nextU32() {
    if (_index == 16) {
      _nextBlock();
      _index = 0;
    }
    return _block[_index++];
  }

  void _nextBlock() {
    _input[12] = _counter & _mask32;
    _input[13] = _counter >>> 32;
    _counter++;
    final x = _x..setAll(0, _input);
    void quarterRound(int a, int b, int c, int d) {
      x[a] += x[b];
      x[d] = _rotateLeft(x[d] ^ x[a], 16);
      x[c] += x[d];
      x[b] = _rotateLeft(x[b] ^ x[c], 12);
      x[a] += x[b];
      x[d] = _rotateLeft(x[d] ^ x[a], 8);
      x[c] += x[d];
      x[b] = _rotateLeft(x[b] ^ x[c], 7);
    }

    for (var round = 0; round < 6; round++) {
      quarterRound(0, 4, 8, 12);
      quarterRound(1, 5, 9, 13);
      quarterRound(2, 6, 10, 14);
      quarterRound(3, 7, 11, 15);
      quarterRound(0, 5, 10, 15);
      quarterRound(1, 6, 11, 12);
      quarterRound(2, 7, 8, 13);
      quarterRound(3, 4, 9, 14);
    }
    for (var i = 0; i < 16; i++) {
      _block[i] = x[i] + _input[i];
    }
  }

  /// `random_range(..bound)` for a u32: Canon's widening multiply, with
  /// one more word when the low half is in the biased zone
  /// (`UniformInt::sample_single_inclusive`, without `unbiased`).
  int _below(int bound) {
    final product = nextU32() * bound;
    var result = product >>> 32;
    final low = product & _mask32;
    if (low > 0x100000000 - bound) {
      final high = (nextU32() * bound) >>> 32;
      if (low + high > _mask32) result++;
    }
    return result;
  }

  /// `SliceRandom::shuffle`: Fisher–Yates from the front, drawing several
  /// indices from one number in [0, (n+1)(n+2)...(n+k)), the largest such
  /// product that fits in 32 bits (`IncreasingUniform`).
  void shuffle<T>(List<T> list) {
    if (list.length <= 1) return;
    var chunk = 0;
    var remaining = 1; // the first index, in [0, 0], needs no number
    for (var i = 0; i < list.length; i++) {
      final range = i + 1;
      if (remaining == 0) {
        var product = range;
        var next = range + 1;
        while (product * next <= _mask32) {
          product *= next;
          next++;
        }
        chunk = _below(product);
        remaining = next - range;
      }
      remaining--;
      final int j;
      if (remaining == 0) {
        j = chunk;
      } else {
        j = chunk % range;
        chunk ~/= range;
      }
      final swap = list[i];
      list[i] = list[j];
      list[j] = swap;
    }
  }
}
