// node --test mods/jm-open-file/paths.test.js
import { test } from "node:test";
import assert from "node:assert/strict";
import { candidates, resolve } from "./paths.js";

test("candidates: a clicked path keeps its line and column", () => {
  assert.deepEqual(candidates("src/a.lua:12:3")[0], { path: "src/a.lua", line: "12", col: "3" });
});

test("candidates: a clicked git diff path drops its a/ prefix first", () => {
  assert.deepEqual(candidates("a/src/a.lua").map((c) => c.path), ["src/a.lua", "a/src/a.lua"]);
});

test("candidates: an agent mention keeps its line", () => {
  assert.deepEqual(candidates("@~/a.sh#L136-159")[0], { path: "~/a.sh", line: "136", col: undefined });
});

test("resolve: tries the terminal folder before home", async () => {
  const tested = [];
  const exec = async (cmd, args) => {
    if (cmd === "test") tested.push(args[1]);
    return { code: cmd === "test" && args[1] === "/home/a.lua" ? 0 : 1, stdout: "", stderr: "" };
  };
  assert.deepEqual(await resolve([{ path: "a.lua" }], "/work", "/home", exec), { path: "/home/a.lua" });
  assert.deepEqual(tested, ["/work/a.lua", "/home/a.lua"]);
});
