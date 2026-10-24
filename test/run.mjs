#!/usr/bin/env node
/**
 * Regression test: run the unpacker in --verify mode against a known-good file
 * and assert that the payload verifies end to end.
 *
 *   node test/run.mjs /path/to/plain_out.lua
 *
 * Point it at a Lua-Guard-protected file whose payload is known to be intact.
 * Exits 0 on success, 1 on failure.
 */
import { execFileSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const cli = path.join(here, "..", "luaguard-unpack.mjs");
const fixture = process.argv[2];

if (!fixture) {
    console.error("usage: node test/run.mjs <protected.lua>");
    process.exit(1);
}

let out = "";
let code = 0;
try {
    out = execFileSync(process.execPath, [cli, fixture, "--verify"], { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
} catch (e) {
    out = `${e.stdout ?? ""}${e.stderr ?? ""}`;
    code = e.status ?? 1;
}

process.stdout.write(out);

const checks = [
    ["exits 0", code === 0],
    ["payload HMAC verified", /salt verified/.test(out)],
    ["structure consumed fully", /bytes (\d+)\/\1\b/.test(out)],
    ["every prototype checksum passes", /all checksums pass: true/.test(out)],
    ["all strings decrypted", /strings: (\d+)\/\1\b/.test(out)],
    ["final verdict", /fully verified/.test(out)],
];

let failed = 0;
for (const [name, ok] of checks) {
    console.log(`${ok ? "  ok  " : " FAIL "} ${name}`);
    if (!ok) failed++;
}
console.log(failed ? `\n${failed} check(s) failed` : "\nall checks passed");
process.exit(failed ? 1 : 0);
