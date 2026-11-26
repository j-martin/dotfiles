// node --test mods/jm-complete/words.test.js
import { test } from "node:test";
import assert from "node:assert/strict";
import { completions, fuzzy, insertion, prefixOf, words } from "./words.js";

test("words: newest first (bottom line up, right to left), focused screen before others, unique", () => {
  const focused = "git status\n  modified:   shell/aliases/docker";
  const other = "docker compose up\ngit";
  assert.deepEqual(words([focused, other]), ["shell/aliases/docker", "shell", "aliases", "docker", "modified", "status", "git", "up", "compose"]);
});

test("words: trims quotes, brackets and trailing punctuation, drops symbols and escapes", () => {
  assert.deepEqual(words(['\x1b[32m"hello"\x1b[0m (world). ➜ -- https://x.io/a']), ["https://x.io/a", "https", "x.io", "world", "hello"]);
});

test("words: drops words without letters", () => {
  assert.deepEqual(words(["36.0 KiB 110.39 v1.2"]), ["v1.2", "KiB"]);
});

test("words: keeps flags", () => {
  assert.deepEqual(words(["git push --force-with-lease"]), ["--force-with-lease", "push", "git"]);
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

test("insertion: extends the prefix, or erases it when the word differs", () => {
  assert.deepEqual(insertion("checkout", "che"), { erase: 0, text: "ckout" });
  assert.deepEqual(insertion("Cherry", "che"), { erase: 3, text: "Cherry" });
  assert.deepEqual(insertion("aliases", "shell/al"), { erase: 8, text: "aliases" });
});
