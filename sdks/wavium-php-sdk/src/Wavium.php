<?php

declare(strict_types=1);

namespace Wavium;

/**
 * Wavium PHP SDK entry point. Every SDK in this repository is generated
 * from the same WIT and canonical ABI definitions, so application code
 * written against this SDK maps onto the same runtime capability model as
 * any other language.
 */
final class WaviumSdk
{
    public const VERSION = '0.1.0';

    public static function sdkName(): string
    {
        return 'wavium-php-sdk';
    }

    public static function packageName(): string
    {
        return 'wavium';
    }
}

/**
 * An opaque, runtime-issued capability handle. Resource access always flows
 * through a handle like this rather than an ambient API.
 */
final class CapabilityHandle
{
    public function __construct(public readonly int $id)
    {
    }

    public function isValid(): bool
    {
        return $this->id !== 0;
    }
}

/** Raised when canonical ABI encoding or decoding fails. */
final class AbiException extends \RuntimeException
{
}

/**
 * Canonical ABI codecs. These mirror the encoding used by wavium-wit so that
 * payloads produced by this SDK are wire-compatible with the runtime.
 */
final class AbiCodec
{
    public static function encodeI32(int $value): string
    {
        return pack('V', $value & 0xFFFFFFFF);
    }

    public static function decodeI32(string $data): int
    {
        if (strlen($data) < 4) {
            throw new AbiException('buffer too small');
        }
        $unsigned = unpack('V', substr($data, 0, 4))[1];
        return $unsigned >= 0x80000000 ? $unsigned - 0x100000000 : $unsigned;
    }

    public static function encodeBool(bool $value): string
    {
        return chr($value ? 1 : 0);
    }

    public static function decodeBool(string $data): bool
    {
        if (strlen($data) < 1) {
            throw new AbiException('buffer too small');
        }
        $byte = ord($data[0]);
        return match ($byte) {
            0 => false,
            1 => true,
            default => throw new AbiException('invalid boolean encoding'),
        };
    }

    public static function encodeString(string $value): string
    {
        $length = strlen($value);
        if ($length > 0xFFFFFFFF) {
            throw new AbiException('string too long');
        }
        return pack('V', $length) . $value;
    }

    public static function decodeString(string $data): string
    {
        if (strlen($data) < 4) {
            throw new AbiException('buffer too small');
        }
        $length = unpack('V', substr($data, 0, 4))[1];
        $required = 4 + $length;
        if (strlen($data) < $required) {
            throw new AbiException('buffer too small');
        }
        return substr($data, 4, $length);
    }
}
