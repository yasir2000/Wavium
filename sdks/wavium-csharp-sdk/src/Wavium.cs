using System;
using System.Text;

namespace Wavium
{
    /// <summary>
    /// Wavium C# SDK entry point. Every SDK in this repository is generated
    /// from the same WIT and canonical ABI definitions, so application code
    /// written against this SDK maps onto the same runtime capability model
    /// as any other language.
    /// </summary>
    public static class WaviumSdk
    {
        public const string Version = "0.1.0";

        public static string SdkName() => "wavium-csharp-sdk";

        public static string PackageName() => "wavium";
    }

    /// <summary>
    /// An opaque, runtime-issued capability handle. Resource access always
    /// flows through a handle like this rather than an ambient API.
    /// </summary>
    public readonly struct CapabilityHandle
    {
        public readonly ulong Id;

        public CapabilityHandle(ulong id)
        {
            Id = id;
        }

        public bool IsValid() => Id != 0;
    }

    /// <summary>Raised when canonical ABI encoding or decoding fails.</summary>
    public sealed class AbiException : Exception
    {
        public AbiException(string message) : base(message)
        {
        }
    }

    /// <summary>
    /// Canonical ABI codecs. These mirror the encoding used by wavium-wit so
    /// that payloads produced by this SDK are wire-compatible with the runtime.
    /// </summary>
    public static class AbiCodec
    {
        public static int EncodeI32(int value, byte[] output)
        {
            if (output.Length < 4) throw new AbiException("buffer too small");
            output[0] = (byte)(value & 0xFF);
            output[1] = (byte)((value >> 8) & 0xFF);
            output[2] = (byte)((value >> 16) & 0xFF);
            output[3] = (byte)((value >> 24) & 0xFF);
            return 4;
        }

        public static int DecodeI32(byte[] data)
        {
            if (data.Length < 4) throw new AbiException("buffer too small");
            return data[0]
                | (data[1] << 8)
                | (data[2] << 16)
                | (data[3] << 24);
        }

        public static int EncodeBool(bool value, byte[] output)
        {
            if (output.Length < 1) throw new AbiException("buffer too small");
            output[0] = (byte)(value ? 1 : 0);
            return 1;
        }

        public static bool DecodeBool(byte[] data)
        {
            if (data.Length < 1) throw new AbiException("buffer too small");
            if (data[0] == 0) return false;
            if (data[0] == 1) return true;
            throw new AbiException("invalid boolean encoding");
        }

        public static int EncodeString(string value, byte[] output)
        {
            byte[] payload = Encoding.UTF8.GetBytes(value);
            int required = 4 + payload.Length;
            if (output.Length < required) throw new AbiException("buffer too small");
            output[0] = (byte)(payload.Length & 0xFF);
            output[1] = (byte)((payload.Length >> 8) & 0xFF);
            output[2] = (byte)((payload.Length >> 16) & 0xFF);
            output[3] = (byte)((payload.Length >> 24) & 0xFF);
            Array.Copy(payload, 0, output, 4, payload.Length);
            return required;
        }

        public static string DecodeString(byte[] data)
        {
            if (data.Length < 4) throw new AbiException("buffer too small");
            int length = data[0]
                | (data[1] << 8)
                | (data[2] << 16)
                | (data[3] << 24);
            int required = 4 + length;
            if (data.Length < required) throw new AbiException("buffer too small");
            return Encoding.UTF8.GetString(data, 4, length);
        }
    }
}
