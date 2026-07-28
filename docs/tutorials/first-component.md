# First Component

This tutorial walks through creating a real component, defining its WIT surface, packaging it, and running it in the runtime or simulator.

## Prerequisites

- familiarity with the component model
- a Zig source file or equivalent language binding
- a WIT world definition

## Tutorial Flow

1. write the component logic
2. define the WIT world
3. package the component
4. run it in the simulator
5. verify the expected output

## Step-by-Step Walkthrough

### 1. Write the component logic

Begin with one function that accepts a simple input and returns a predictable output. Keep the logic side-effect free so the component remains easy to test.

### 2. Define the WIT world

Describe the function signature in WIT so the runtime can validate the interface before the component is executed. This is the contract that the host and guest both rely on.

### 3. Package the component

Assemble the component and contract metadata into a package that the build and runtime tools can inspect. Packaging should preserve the interface contract and any declared capabilities.

### 4. Run it in the simulator

Execute the package in the local simulator or runtime harness. The point of this step is to prove that the component works without depending on a desktop process model.

### 5. Verify the expected output

Confirm that the observed result matches the WIT contract and the component logic. If the output differs, fix the contract or implementation before moving on.

## Worked Example

The binary-friendly echo component below shows a slightly more involved first component, including a fallible operation and a bounded output buffer:

```zig
const std = @import("std");

pub fn echo(payload: []const u8, out: []u8) !usize {
    if (out.len < payload.len) return error.BufferTooSmall;
    @memcpy(out[0..payload.len], payload);
    return payload.len;
}

test "echo returns the input bytes" {
    var out: [16]u8 = undefined;
    const used = try echo("ping", out[0..]);
    try std.testing.expectEqual(@as(usize, 4), used);
    try std.testing.expectEqualStrings("ping", out[0..used]);
}
```

```wit
package wavium:rpc;

world binary-rpc-replacement {
    export echo: func(payload: list<u8>) -> list<u8>;
}
```

The full working source lives in [examples/binary-rpc-replacement](../../examples/binary-rpc-replacement).

## Outcome

After this tutorial, you should have a working mental model for the full Wavium component lifecycle from source to execution.

This tutorial should be paired with the component and WIT developer guides.

## Related Documentation

- [Hello World](hello-world.md)
- [Write a WIT Interface](../developers/write-wit-interface.md)
- [Wavium Component Spec](../specifications/wavium-component-spec.md)