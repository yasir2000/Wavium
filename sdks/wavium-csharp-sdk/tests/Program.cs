using System;
using Wavium;

/// <summary>
/// Dependency-free test runner for the C# SDK. Kept intentionally free of
/// xUnit/NUnit so it can run with only `dotnet run`.
/// </summary>
internal static class Program
{
    private static int failures = 0;

    private static int Main()
    {
        TestSdkName();
        TestCapabilityHandleValidity();
        TestEncodeDecodeI32();
        TestEncodeDecodeBool();
        TestEncodeDecodeString();
        TestBufferTooSmall();

        if (failures > 0)
        {
            Console.WriteLine(failures + " test(s) failed");
            return 1;
        }

        Console.WriteLine("wavium-csharp-sdk: all tests passed");
        return 0;
    }

    private static void Check(bool condition, string message)
    {
        if (!condition)
        {
            failures++;
            Console.WriteLine("FAILED: " + message);
        }
    }

    private static void TestSdkName()
    {
        Check(WaviumSdk.SdkName() == "wavium-csharp-sdk", "sdk name");
        Check(WaviumSdk.PackageName() == "wavium", "package name");
    }

    private static void TestCapabilityHandleValidity()
    {
        Check(!new CapabilityHandle(0).IsValid(), "zero id invalid");
        Check(new CapabilityHandle(7).IsValid(), "nonzero id valid");
    }

    private static void TestEncodeDecodeI32()
    {
        var buf = new byte[4];
        AbiCodec.EncodeI32(-99, buf);
        Check(AbiCodec.DecodeI32(buf) == -99, "i32 roundtrip");
    }

    private static void TestEncodeDecodeBool()
    {
        var buf = new byte[1];
        AbiCodec.EncodeBool(true, buf);
        Check(AbiCodec.DecodeBool(buf), "bool roundtrip");

        bool threw = false;
        try { AbiCodec.DecodeBool(new byte[] { 9 }); }
        catch (AbiException) { threw = true; }
        Check(threw, "invalid boolean throws");
    }

    private static void TestEncodeDecodeString()
    {
        var buf = new byte[32];
        int used = AbiCodec.EncodeString("wavium-sdk", buf);
        var slice = new byte[used];
        Array.Copy(buf, slice, used);
        Check(AbiCodec.DecodeString(slice) == "wavium-sdk", "string roundtrip");
    }

    private static void TestBufferTooSmall()
    {
        bool threw = false;
        try { AbiCodec.EncodeI32(1, new byte[2]); }
        catch (AbiException) { threw = true; }
        Check(threw, "buffer too small throws");
    }
}
