// node --test mods/jm-complete/words.test.js
import { test } from "node:test";
import assert from "node:assert/strict";
import { completions, fuzzy, prefixOf, words } from "./words.js";

test("words: nearest first, focused screen before others, unique", () => {
  const focused = "git status\n  modified:   shell/aliases/docker";
  const other = "docker compose up\ngit";
  assert.deepEqual(words([focused, other]), ["modified", "shell/aliases/docker", "shell", "aliases", "docker", "git", "status", "compose", "up"]);
});

test("words: trims quotes, brackets and trailing punctuation, drops symbols and escapes", () => {
  assert.deepEqual(words(['\x1b[32m"hello"\x1b[0m (world). ➜ -- https://x.io/a']), ["hello", "world", "https://x.io/a", "https", "x.io"]);
});

test("words: drops words without letters", () => {
  assert.deepEqual(words(["36.0 KiB 110.39 v1.2"]), ["KiB", "v1.2"]);
});

test("words: keeps flags", () => {
  assert.deepEqual(words(["git push --force-with-lease"]), ["git", "push", "--force-with-lease"]);
});

test("prefixOf: the partial word before the cursor", () => {
  assert.equal(prefixOf("➜  .config git che"), "che");
  assert.equal(prefixOf('➜  .config cat "shell/al'), "shell/al");
  assert.equal(prefixOf("➜  .config ls "), "");
  assert.equal(prefixOf(""), "");
});

test("completions: case-sensitive prefix, longer than it", () => {
  assert.deepEqual(completions(["checkout", "Cherry", "che", "chmod"], "che"), ["checkout"]);
  assert.deepEqual(completions(["a", "bb"], ""), ["a", "bb"]);
});

test("fuzzy: characters in order, ignoring case", () => {
  assert.equal(fuzzy("shell/aliases/docker", "SAD"), true);
  assert.equal(fuzzy("docker", "dk"), true);
  assert.equal(fuzzy("docker", "kd"), false);
});
