// node --test mods/jm-complete/words.test.js
import { test } from "node:test";
import assert from "node:assert/strict";
import { candidates, completions, folderOf, fuzzy, insertion, pathCompletions, prefixOf, splitPath, words } from "./words.js";

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

test("splitPath: the folder part up to the last slash and the partial name after it", () => {
  assert.deepEqual(splitPath("../"), { head: "../", tail: "" });
  assert.deepEqual(splitPath("../sh"), { head: "../", tail: "sh" });
  assert.deepEqual(splitPath("che"), { head: "", tail: "che" });
});

test("folderOf: resolves the head against the cwd and home", () => {
  assert.equal(folderOf("../", "/a/b", "/home"), "/a/b/../");
  assert.equal(folderOf("~/src/", "/a/b", "/home"), "/home/src/");
  assert.equal(folderOf("/etc/", "/a/b", "/home"), "/etc/");
  assert.equal(folderOf("", "/a/b", "/home"), "/a/b/");
});

test("pathCompletions: entries of the folder starting with the tail, hidden ones only for a dot", () => {
  const entries = ["shell/", "share", ".git/", "bin/"];
  assert.deepEqual(pathCompletions(entries, "../sh"), ["../shell/", "../share"]);
  assert.deepEqual(pathCompletions(entries, "../"), ["../shell/", "../share", "../bin/"]);
  assert.deepEqual(pathCompletions(entries, "../.g"), ["../.git/"]);
  assert.deepEqual(pathCompletions(entries, "sh"), ["shell/", "share"]);
});

test("words: keeps leading dots of dotfiles and relative paths", () => {
  assert.deepEqual(words([".claude/ ../src"]), ["../src", "src", ".claude/", ".claude"]);
});

test("candidates: screen words completing the prefix or its partial name, folder entries, unique", () => {
  const screen = ["../shell/aliases", "shell", "shelf", "docker"];
  assert.deepEqual(candidates(screen, ["shell/"], "../sh"), ["../shell/aliases", "../shell/", "../shelf"]);
  assert.deepEqual(candidates(screen, [], "sh"), ["shell", "shelf"]);
  assert.deepEqual(candidates(["shelf"], ["share"], "sh"), ["shelf", "share"]);
  assert.deepEqual(candidates([".claude/x", ".claude"], [".claude/"], ".cl"), [".claude/x", ".claude/"]);
});

test("candidates: deeper paths first, then the most recent on screen, then files not on screen", () => {
  assert.deepEqual(candidates(["src/a", "src/a/b/c", "src/a/b"], [], "src/"), ["src/a/b/c", "src/a/b", "src/a"]);
  assert.deepEqual(candidates(["src/b", "src/a"], ["src/"], "s"), ["src/b", "src/a", "src/"]);
});

test("candidates: a bare folder part completes from its files only, not every screen word", () => {
  assert.deepEqual(candidates(["docker"], ["x"], "../"), ["../x"]);
});
