#!/usr/bin/env node
/**
 * Robustness test: inject decoys into a known-good Lua-Guard file and assert the
 * unpacker still identifies the right payload and salt.
 *
 * Two things a naive implementation gets wrong, and this test pins down:
 *   1. A decoy 44-char base64 literal placed near the top (looks exactly like the HMAC salt).
 *   2. A decoy long base64 literal elsewhere in the file (looks exactly like a payload segment).
 *
 * Usage: node test/noise.mjs /path/to/plain_out.lua
 */
import { execFileSync } from "node:child_process";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const cli = path.join(here, "..", "luaguard-unpack.mjs");
const fixture = process.argv[2];
if (!fixture) {
    console.error("usage: node test/noise.mjs <protected.lua>");
    process.exit(1);
}

const original = fs.readFileSync(fixture, "latin1");
const decoySalt = "A".repeat(43) + "=";                       // 44 chars, base64-shaped, ends with '='
const decoySeg = "QUJD".repeat(500);                          // 2000 chars, valid base64 alphabet
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "lg-noise-"));

const variants = [
    ["decoy salt only", `-- noise\nlocal decoy="${decoySalt}"\n${original}`],
    ["decoy salt + decoy segment", `-- noise\nlocal decoy="${decoySalt}"\nlocal decoySeg="${decoySeg}"\n${original}`],
    ["decoy segment appended after payload", `-- noise\nlead local x=1\n${original}\nlocal decoySeg="${decoySeg}"\n`],
];

let failed = 0;
for (const [name, body] of variants) {
    const file = path.join(tmp, `${name.replace(/\W+/g, "_")}.lua`);
    fs.writeFileSync(file, body, "latin1");
    let out = "", code = 0;
    try {
        out = execFileSync(process.execPath, [cli, file, "--verify", "--quiet"], { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
    } catch (e) {
        out = `${e.stdout ?? ""}${e.stderr ?? ""}`;
        code = e.status ?? 1;
    }
    const ok = code === 0 && /fully verified/.test(out);
    console.log(`${ok ? "  ok  " : " FAIL "} ${name}`);
    if (!ok) {
        failed++;
        console.log(out.split("\n").map((l) => `        ${l}`).join("\n"));
    }
}

fs.rmSync(tmp, { recursive: true, force: true });
console.log(failed ? `\n${failed} variant(s) failed` : "\nall variants still verify");
process.exit(failed ? 1 : 0);
