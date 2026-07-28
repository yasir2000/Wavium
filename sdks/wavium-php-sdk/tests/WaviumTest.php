<?php

declare(strict_types=1);

require __DIR__ . '/../src/Wavium.php';

use Wavium\AbiCodec;
use Wavium\AbiException;
use Wavium\CapabilityHandle;
use Wavium\WaviumSdk;

$failures = 0;

function check(bool $condition, string $message): void
{
    global $failures;
    if (!$condition) {
        $failures++;
        echo "FAILED: {$message}\n";
    }
}

check(WaviumSdk::sdkName() === 'wavium-php-sdk', 'sdk name');
check(WaviumSdk::packageName() === 'wavium', 'package name');

check(!(new CapabilityHandle(0))->isValid(), 'zero id invalid');
check((new CapabilityHandle(7))->isValid(), 'nonzero id valid');

$encodedI32 = AbiCodec::encodeI32(-99);
check(AbiCodec::decodeI32($encodedI32) === -99, 'i32 roundtrip');

$encodedBool = AbiCodec::encodeBool(true);
check(AbiCodec::decodeBool($encodedBool) === true, 'bool roundtrip');

try {
    AbiCodec::decodeBool("\x09");
    check(false, 'invalid boolean should throw');
} catch (AbiException $e) {
    check(true, 'invalid boolean throws');
}

$encodedString = AbiCodec::encodeString('wavium-sdk');
check(AbiCodec::decodeString($encodedString) === 'wavium-sdk', 'string roundtrip');

try {
    AbiCodec::decodeString("\x00");
    check(false, 'short buffer should throw');
} catch (AbiException $e) {
    check(true, 'buffer too small throws');
}

if ($failures > 0) {
    echo "{$failures} test(s) failed\n";
    exit(1);
}

echo "wavium-php-sdk: all tests passed\n";
