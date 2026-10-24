// Deterministic PRNG (xorshift64*) so regenerated fixtures are byte-identical.
export function makeRng(seed = 0x9e3779b97f4a7c15n) {
  let s = BigInt.asUintN(64, seed) || 1n;
  return () => {
    s ^= s >> 12n;
    s ^= BigInt.asUintN(64, s << 25n);
    s ^= s >> 27n;
    return BigInt.asUintN(64, s * 0x2545f4914f6cdd1dn);
  };
}

export function bitsToDouble(bits) {
  const b = new DataView(new ArrayBuffer(8));
  b.setBigUint64(0, BigInt.asUintN(64, bits));
  return b.getFloat64(0);
}

export function doubleToBits(x) {
  const b = new DataView(new ArrayBuffer(8));
  b.setFloat64(0, x);
  return b.getBigUint64(0);
}

// Every NaN prints as the canonical quiet NaN: payloads are not observable from JS and differ between engines.
export const hex16 = (x) => (Number.isNaN(x) ? '7ff8000000000000' : doubleToBits(x).toString(16).padStart(16, '0'));
