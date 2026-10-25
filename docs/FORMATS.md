# Supported protections

| Format | Status | Notes |
|---|---|---|
| **Lua-Guard v1** (`Elton's Hub`) | ✅ full | strings, structure, disassembly, pseudocode, structured code, naming |
| **Lua-Guard v2** (`Hood Rivals`) | ✅ full | same |
| **Lua-Guard v3** (`RIVALS`) | ✅ full (34 instr untranslated) | `ADDI` semantics unconfirmed, kept as raw `-- op` |
| **SparkHub / IronBrew-style VM** | 🚧 in progress | see `sparkhub-status.md` |

## How detection works

`detect.mjs` fingerprints the input before attempting anything, and refuses to guess:

- Lua-Guard: 4+ long base64 segments + `bit32.bxor` (confidence 90-96)
- IronBrew-style: many numeric escapes + huge elseif chains
- Single base64 + loadstring: naive encoding

Anything else prints `unrecognised protection` plus a stats dump (segment count, escape
count, elseif count, loadstring presence) so a human can decide what to do next.

## Adding a new format

Each protection needs its own reverse-engineering pass. What a format module must answer:

1. **Outer layer** — how is the payload encoded/hidden (segments, shuffle, XOR, base64 variant)?
2. **Integrity** — what checks does the original perform, so we can verify our result?
3. **Inner representation** — bytecode arrays? dynamic VM? string pool?
4. **Semantics** — operand layout per opcode, program-counter convention, jump encoding.

Lua-Guard took one day. SparkHub's VM alone is a 27,117-instruction interpreter, so it is
a week-scale effort, tracked in `sparkhub-status.md`.
