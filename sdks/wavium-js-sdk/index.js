export const VERSION = "0.1.0";

export function sdkName() {
  return "wavium-js-sdk";
}

export function packageName() {
  return "wavium";
}

/**
 * An opaque, runtime-issued capability handle. Resource access always flows
 * through a handle like this rather than an ambient API.
 */
export class CapabilityHandle {
  constructor(id) {
    this.id = id;
  }

  isValid() {
    return this.id !== 0;
  }
}

export class AbiError extends Error {}

// Canonical ABI codecs. These mirror the encoding used by wavium-wit so that
// payloads produced by this SDK are wire-compatible with the runtime.
export function encodeI32(value, out) {
  if (out.length < 4) {
    throw new AbiError("buffer too small");
  }
  const view = new DataView(out.buffer, out.byteOffset, out.byteLength);
  view.setInt32(0, value, true);
  return 4;
}

export function decodeI32(data) {
  if (data.length < 4) {
    throw new AbiError("buffer too small");
  }
  const view = new DataView(data.buffer, data.byteOffset, data.byteLength);
  return view.getInt32(0, true);
}

export function encodeBool(value, out) {
  if (out.length < 1) {
    throw new AbiError("buffer too small");
  }
  out[0] = value ? 1 : 0;
  return 1;
}

export function decodeBool(data) {
  if (data.length < 1) {
    throw new AbiError("buffer too small");
  }
  if (data[0] === 0) return false;
  if (data[0] === 1) return true;
  throw new AbiError("invalid boolean encoding");
}

export function encodeString(value, out) {
  const encoded = new TextEncoder().encode(value);
  const required = 4 + encoded.length;
  if (out.length < required) {
    throw new AbiError("buffer too small");
  }
  const view = new DataView(out.buffer, out.byteOffset, out.byteLength);
  view.setUint32(0, encoded.length, true);
  out.set(encoded, 4);
  return required;
}

export function decodeString(data) {
  if (data.length < 4) {
    throw new AbiError("buffer too small");
  }
  const view = new DataView(data.buffer, data.byteOffset, data.byteLength);
  const length = view.getUint32(0, true);
  const required = 4 + length;
  if (data.length < required) {
    throw new AbiError("buffer too small");
  }
  return new TextDecoder().decode(data.subarray(4, required));
}
