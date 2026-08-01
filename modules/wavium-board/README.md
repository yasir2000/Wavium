# wavium-board

Status: implemented

Defines the `.wboard` hardware target package format used to describe a
board's CPU, memory, devices, driver bindings, and required capabilities
for `wavium build` / `wavium deploy` targeting.

See `src/lib.zig` for the `BoardDescriptor` type, `parseBoard` (line-based
`key=value` parser), and `validateBoard` (referential integrity checks,
e.g. every driver binding must reference a declared device).

Example board descriptions live under `src/boards/`:
`raspberry-pi.wboard`, `server-x86.wboard`, `riscv-board.wboard`.
