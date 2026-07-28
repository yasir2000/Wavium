package io.wavium.sdk;

/**
 * Dependency-free test runner for the Java SDK. Kept intentionally free of
 * JUnit or any build tool so it can run with only {@code javac}/{@code java}.
 */
public final class WaviumTest {

    private static int failures = 0;

    public static void main(String[] args) {
        testSdkName();
        testCapabilityHandleValidity();
        testEncodeDecodeI32();
        testEncodeDecodeBool();
        testEncodeDecodeString();
        testBufferTooSmall();

        if (failures > 0) {
            System.out.println(failures + " test(s) failed");
            System.exit(1);
        }
        System.out.println("wavium-java-sdk: all tests passed");
    }

    private static void check(boolean condition, String message) {
        if (!condition) {
            failures++;
            System.out.println("FAILED: " + message);
        }
    }

    private static void testSdkName() {
        check(Wavium.sdkName().equals("wavium-java-sdk"), "sdk name");
        check(Wavium.packageName().equals("wavium"), "package name");
    }

    private static void testCapabilityHandleValidity() {
        check(!new Wavium.CapabilityHandle(0).isValid(), "zero id invalid");
        check(new Wavium.CapabilityHandle(7).isValid(), "nonzero id valid");
    }

    private static void testEncodeDecodeI32() {
        byte[] buf = new byte[4];
        Wavium.encodeI32(-99, buf);
        check(Wavium.decodeI32(buf) == -99, "i32 roundtrip");
    }

    private static void testEncodeDecodeBool() {
        byte[] buf = new byte[1];
        Wavium.encodeBool(true, buf);
        check(Wavium.decodeBool(buf), "bool roundtrip");

        boolean threw = false;
        try {
            Wavium.decodeBool(new byte[] { 9 });
        } catch (Wavium.AbiException e) {
            threw = true;
        }
        check(threw, "invalid boolean throws");
    }

    private static void testEncodeDecodeString() {
        byte[] buf = new byte[32];
        int used = Wavium.encodeString("wavium-sdk", buf);
        byte[] slice = new byte[used];
        System.arraycopy(buf, 0, slice, 0, used);
        check(Wavium.decodeString(slice).equals("wavium-sdk"), "string roundtrip");
    }

    private static void testBufferTooSmall() {
        boolean threw = false;
        try {
            Wavium.encodeI32(1, new byte[2]);
        } catch (Wavium.AbiException e) {
            threw = true;
        }
        check(threw, "buffer too small throws");
    }
}
