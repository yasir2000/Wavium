package io.wavium.sdk;

import java.nio.charset.StandardCharsets;

/**
 * Wavium Java SDK entry point.
 *
 * <p>Every SDK in this repository is generated from the same WIT and
 * canonical ABI definitions, so application code written against this SDK
 * maps onto the same runtime capability model as any other language.
 */
public final class Wavium {

    public static final String VERSION = "0.1.0";

    private Wavium() {
    }

    public static String sdkName() {
        return "wavium-java-sdk";
    }

    public static String packageName() {
        return "wavium";
    }

    /**
     * An opaque, runtime-issued capability handle. Resource access always
     * flows through a handle like this rather than an ambient API.
     */
    public static final class CapabilityHandle {
        public final long id;

        public CapabilityHandle(long id) {
            this.id = id;
        }

        public boolean isValid() {
            return id != 0;
        }
    }

    /** Raised when canonical ABI encoding or decoding fails. */
    public static final class AbiException extends RuntimeException {
        public AbiException(String message) {
            super(message);
        }
    }

    // Canonical ABI codecs. These mirror the encoding used by wavium-wit so
    // that payloads produced by this SDK are wire-compatible with the runtime.

    public static int encodeI32(int value, byte[] out) {
        if (out.length < 4) {
            throw new AbiException("buffer too small");
        }
        out[0] = (byte) (value & 0xFF);
        out[1] = (byte) ((value >>> 8) & 0xFF);
        out[2] = (byte) ((value >>> 16) & 0xFF);
        out[3] = (byte) ((value >>> 24) & 0xFF);
        return 4;
    }

    public static int decodeI32(byte[] data) {
        if (data.length < 4) {
            throw new AbiException("buffer too small");
        }
        return (data[0] & 0xFF)
                | ((data[1] & 0xFF) << 8)
                | ((data[2] & 0xFF) << 16)
                | ((data[3] & 0xFF) << 24);
    }

    public static int encodeBool(boolean value, byte[] out) {
        if (out.length < 1) {
            throw new AbiException("buffer too small");
        }
        out[0] = (byte) (value ? 1 : 0);
        return 1;
    }

    public static boolean decodeBool(byte[] data) {
        if (data.length < 1) {
            throw new AbiException("buffer too small");
        }
        if (data[0] == 0) {
            return false;
        }
        if (data[0] == 1) {
            return true;
        }
        throw new AbiException("invalid boolean encoding");
    }

    public static int encodeString(String value, byte[] out) {
        byte[] payload = value.getBytes(StandardCharsets.UTF_8);
        int required = 4 + payload.length;
        if (out.length < required) {
            throw new AbiException("buffer too small");
        }
        out[0] = (byte) (payload.length & 0xFF);
        out[1] = (byte) ((payload.length >>> 8) & 0xFF);
        out[2] = (byte) ((payload.length >>> 16) & 0xFF);
        out[3] = (byte) ((payload.length >>> 24) & 0xFF);
        System.arraycopy(payload, 0, out, 4, payload.length);
        return required;
    }

    public static String decodeString(byte[] data) {
        if (data.length < 4) {
            throw new AbiException("buffer too small");
        }
        int length = (data[0] & 0xFF)
                | ((data[1] & 0xFF) << 8)
                | ((data[2] & 0xFF) << 16)
                | ((data[3] & 0xFF) << 24);
        int required = 4 + length;
        if (data.length < required) {
            throw new AbiException("buffer too small");
        }
        return new String(data, 4, length, StandardCharsets.UTF_8);
    }
}
