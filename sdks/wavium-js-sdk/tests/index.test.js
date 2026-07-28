import assert from "node:assert/strict";
import test from "node:test";
import {
  AbiError,
  CapabilityHandle,
  decodeBool,
  decodeI32,
  decodeString,
  encodeBool,
  encodeI32,
  encodeString,
  packageName,
  sdkName,
} from "../index.js";

test("sdk name", () => {
  assert.equal(sdkName(), "wavium-js-sdk");
});

test("package name", () => {
  assert.equal(packageName(), "wavium");
});

test("capability handle validity", () => {
  assert.equal(new CapabilityHandle(0).isValid(), false);
  assert.equal(new CapabilityHandle(7).isValid(), true);
});

test("encode/decode i32", () => {
  const buf = new Uint8Array(4);
  encodeI32(-99, buf);
  assert.equal(decodeI32(buf), -99);
});

test("encode/decode bool", () => {
  const buf = new Uint8Array(1);
  encodeBool(true, buf);
  assert.equal(decodeBool(buf), true);
  assert.throws(() => decodeBool(new Uint8Array([9])), AbiError);
});

test("encode/decode string", () => {
  const buf = new Uint8Array(32);
  const used = encodeString("wavium-sdk", buf);
  assert.equal(decodeString(buf.subarray(0, used)), "wavium-sdk");
});

test("buffer too small", () => {
  assert.throws(() => encodeI32(1, new Uint8Array(2)), AbiError);
});
