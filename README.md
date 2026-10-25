# luaguard-unpack

Extract the structure, string table and bytecode out of Lua scripts protected by
[Lua-Guard](https://lua-guard.xyz) — the obfuscator/protector commonly used for Roblox
executor scripts.

No executor is required. No `crypt` library. No game client. Just Node.

```bash
node luaguard-unpack.mjs protected.lua -o unpacked

# or straight from a link -- no manual download:
node luaguard-unpack.mjs --url https://example.com/protected.lua -o unpacked
```

## What you get

| Output | Contents |
|---|---|
| `segNN.b64` | the raw base64 payload segments, as found in the file |
| `blob.bin` | the concatenated + decoded packed binary |
| `strings.json` / `strings.txt` | the encrypted string table, **fully decrypted** |
| `globals.json` | numeric constants from the global table |
| `disasm.txt` | **every** function prototype (main + all nested children), disassembled with named opcodes, operands, and constant values inlined as comments |
| `pseudocode.txt` | **linear pseudocode** for v2/v3: one statement per instruction |
| `structured.txt` | **conditional jumps folded into `if`**, plus register provenance comments (TEST/CMP + JMP pairs merged) |
| `structure.json` | everything above, machine-readable, plus a verification verdict |

## Why you can trust the output

Lua-Guard embeds three independent integrity checks. This tool re-computes all of them,
and reports a verdict instead of silently producing garbage:

1. **Global HMAC** — the loader signs the entire payload with
   `HMAC-SHA256(SHA256(salt..":mac:global"), base64(payload))` and compares it with a
   hardcoded hex digest. We recompute it. If it matches, the segment extraction and the
   salt are both provably correct.
2. **Per-prototype arithmetic checksum** — each function prototype ends with a checksum
   over its own field counts. If our field layout were off by even one byte, these fail.
3. **Exact byte consumption** — a correct parse consumes the payload to the last byte.
   Anything left over means the layout differs and you get a warning.

A clean run prints `done — fully verified` and exits 0. Warnings exit 3, so it is
usable in scripts.

## Options

```
-o, --out <dir>   output directory (default: ./unpacked)
-u, --url <url>   download the protected script from a URL
--verify          validate the payload only; write nothing
--no-disasm       skip disassembly (large payloads)
--quiet           only errors and the final verdict
```

## Two layers, both handled

A Lua-Guard "protected" file is encrypted twice, and this tool unwraps **both** without
ever running Roblox or an executor:

1. **Outer layer** — a table of a few tens of thousands of short base64 chunks plus a
   self-contained decryptor written in plain Lua (hand-rolled SHA256, base64 and a
   byte-wise XOR). It ships **decoy chunks** and scrambles the real ones behind a
   permutation array:

   ```
   key       = sha256(salt ":" scriptId ":runtime")
   plaintext = XOR( base64decode( concat( chunk[order[i]] ) ), key )
   ```

   Only `order.length` chunks are used (e.g. 32097 of 32112 — the remaining 15 are junk),
   and junk characters are sprinkled through the base64 text, stripped by a `gsub` filter.
   Get the permutation or the decoy count wrong and you get noise, not an error message.

2. **Inner layer** — the payload described in the next section (base64 segments plus the
   custom VM bytecode).

Both layers are checked against the original program's own integrity values, so a clean
run means byte-exact output rather than a plausible-looking approximation.

## Version profiles (auto-detected)

Lua-Guard rotates its entire parameter set between builds, so nothing here is hardcoded
to one version. The tool tries each known profile and accepts the first whose per-prototype
checksum passes **and** which consumes the blob to the last byte.

| Parameter | v1 | v2 | v3 |
|---|---|---|---|
| LCG seed | 348 | 617 | 52 |
| LCG mixer | `i*17+173` | `i*25+70` | `i*31+231` |
| 3-byte order | `b1 b0 b2` | `b2 b0 b1` | `b1 b0 b2` |
| 4-byte order | `b3 b1 b2 b0` | `b2 b3 b0 b1` | `b2 b0 b3 b1` |
| Opcode multiplier | 143 | 151 | 97 |
| Checksum constant | 4442017 | 736242 | 2608344 |
| Instruction arrays | op,c,a,b | b,a,c,op | b,op,c,a |
| String-table fields | id,t,iv,tag | cipher,iv,id,tag | iv,id,tag,cipher |

Stable across all three: the outer decryption, the AES-256-CBC string decryption, and the
`3.<base64>.<hex>` tag format.

Verified end to end on a live URL:

```
$ node luaguard-unpack.mjs --url https://lua-guard.xyz/api/raw/1899... -o out
[0/5] downloading ...
[1/5] segments: 4 -> 79759 bytes
[2/5] salt verified: xLNORP0hF+Ie...
[3/5] layout: v3 (checksum 3107495 OK, 79759/79759 bytes)
[4/5] strings: 178/178 decrypted
done - fully verified (v3)
```

### Opcode semantics

Each version has its own opcode numbering, so the names are stored per profile and applied when
disassembling. They were obtained by reading every handler body, not guessed from similarity
(similarity matching gets `T = not X` and `R[a][b] = c` wrong, so the final tables are hand-checked).

| Version | handler table | opcodes named |
|---|---|---|
| v1 | `Y7[hash]` | 50 |
| v2 | `QH[hash]` | 33 |
| v3 | `Vl[hash]` | 33 |

Example (v3):

```
  0005  LOADK          op= 178
  0006  GETTABLE       op=  30
  0007  CLOSURE        op=  70
  0008  CALL2DISCARD   op= 227
  0011  NOT            op= 231
```

### What the disassembly looks like

Every `LOADK` / `GETGLOBAL` carries the decoded constant as a trailing comment, and all operands
are shown, so the instruction stream is readable without a decompiler:

```
  0003  LOADK          a=  40 b=   0 c=  31   ; "Invalid key"
  0008  LOADK          a=  33 b=   0 c=  16   ; "getgenv"
  0009  GETTABLE       a=  32 b=  31 c=  33
  0018  LOADK          a=   0 b=   5 c=  18   ; "RbxAnalyticsService"
```

For v2/v3 there are two readable renderings. `structured.txt` folds the VM's "test + jump" pairs
into real `if` statements:

```lua
L0012:
  if not (r26) then goto L0034 end
```

Register provenance is annotated inline (`; r8 = r10[K["getgenv"]]`), loop head candidates are
marked, and jump targets are resolved through jump-chains so every `goto` has a matching label.

`pseudocode.txt` keeps it flat, one statement per instruction:

```lua
L0003:
  r40 = K["Invalid key"]
L0005:
  r37 = true
L0006:
  goto L190
```

**Coverage is 100%**: every instruction of the two v2/v3 samples translates (3618/3618 and 3616/3616),
including alias opcodes that share one handler. Registers stay unnamed (`rN`) and control flow is not
rebuilt, so this is a readability aid, not a decompiler — but no instruction is left as a raw
`-- op N` placeholder, and multi-mode opcodes (`ARITH`, `CMP`, `NOT`) show which mode they carry
rather than guessing an operator.

Nested prototypes are walked recursively (`chunk#0.#2.#1 (depth 3) …`), each with its own
checksum status, so no code is left unexamined.

## How the format works

The file is three layers:

```
[ loader ~6KB ]  [ N base64 segments → packed VM bytecode ]  [ the VM itself as readable Lua ]
```

The only non-obvious parts are inside the packed blob:

- **Fields are 3 bytes, but not in any standard endianness.** A 3-byte field decodes as
  `(b1 << 16 | b0 << 8 | b2) - 0x800000`; the 4-byte fields used for table counts use the
  same "second byte up top" quirk (`b3<<24 | b1<<16 | b2<<8 | b0`). Treating them as
  little-endian shifts every table by one byte.
- **Every prototype derives its own XOR key** from a 32-byte LCG stream seeded with
  `x = 348; x = (x*214013 + 2531011) % 2^24` and mixed with the prototype's key offset.
- **The operand arrays are stored separately** (opcode array first, then C, A, B arrays),
  and each array is decrypted with a different phase offset of that per-prototype key
  (seeds 7 / 5 / 6, stepping by 3 and wrapping at 32).
- **Opcodes are then obfuscated** as `((op - shift) * 143) % 256`.
- **The string table is AES-256-CBC**, with `key = hex2bin(sha256hex(salt..":enc:"..id))`
  and the IV stored per entry.

The opcode names in `disasm.txt` were read out of the VM's own 50 handler bodies
(`ADD`, `GETTABLE`, `CALL2`, `CLOSURE`, `FORLOOP`, …), so they are the real semantics,
not guesses.

## The VM is a custom register machine

It is **not** standard Lua 5.1 bytecode and cannot be fed to `luac -l`. Its semantics
however mirror the Lua 5.1 register model closely, which is what makes the disassembly
readable:

```
0007  LOADK        a=   0 b=   1 c=   5   ; "FindFirstChild"
0008  LOADK        a=   0 b=   2 c=   4   ; "Head"
0009  GETTABLE     a=   3 b=   2 c=   5
0010  CALL3        a=   2 b=   3 c=   2
```

Constants are annotated at every `LOADK` / `GETGLOBAL`, which gets you close to
pseudo-code without a full decompiler. In practice, searching `disasm.txt` for an API
name (`BillboardGui`, `KillAura`, `setthreadidentity`) locates the code that uses it.

## Limitations

- **Disassembly, not decompilation.** Control flow is not rebuilt, locals are unnamed.
- The payload layout is version-specific. Newer Lua-Guard builds may change field order
  or the key schedule; the tool tells you which step failed rather than pretending.
- Only tested against Lua-Guard payloads that use the loader described above. If you
  find a variant that parses with warnings, please open an issue with the
  `structure.json` verdict block.

## Tested against

A 2.37 MB Roblox executor script protected by Lua-Guard, decrypting to a 1.57 MB file:

- 42 payload segments → 991,613 bytes
- 185 global constants
- 1,441 encrypted strings → **1,441 / 1,441 decrypted**
- 803 function prototypes, 54,344 instructions, **all checksums passing**

## Test

```bash
node test/run.mjs /path/to/plain_out.lua
```

Runs `--verify` on a known-good file and asserts that the HMAC and structural checks
both pass.

## License

MIT
