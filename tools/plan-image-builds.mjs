#!/usr/bin/env node
// tools/plan-image-builds.mjs — the build.yml matrix for the
// names a dispatch asks for, from templates/images/variants.json.
//
//   node tools/plan-image-builds.mjs "serve-vllm,nb-pytorch"   # prints matrix=<json>
//   node tools/plan-image-builds.mjs --self-test
//
// Every name must exist in variants.json (a typo fails the run before any
// build); names are the GHCR package suffix and the digest artifact key.
import { readFileSync } from "node:fs";
import assert from "node:assert/strict";

export function plan(names, variants) {
  const list = [...new Set(String(names).split(",").map((s) => s.trim()).filter(Boolean))];
  if (!list.length) throw new Error("no images named; see templates/images/variants.json");
  return list.map((name) => {
    const v = variants[name];
    if (!/^[a-z0-9-]+$/.test(name) || !v) throw new Error(`unknown image "${name}"; see templates/images/variants.json`);
    const buildArgs = Object.entries(v.args ?? {}).map(([k, x]) => `${k}=${x}`).join("\n");
    return { name, context: v.context, build_args: buildArgs };
  });
}

function selfTest() {
  const variants = { vllm: { context: "vllm" }, "nb-x": { context: "workspace", args: { BASE: "a:b@sha256:" + "0".repeat(64), APP: "jupyter" } } };
  assert.deepEqual(plan(" nb-x, vllm,nb-x ", variants), [
    { name: "nb-x", context: "workspace", build_args: `BASE=a:b@sha256:${"0".repeat(64)}\nAPP=jupyter` },
    { name: "vllm", context: "vllm", build_args: "" },
  ]);
  assert.throws(() => plan("", variants), /no images/);
  assert.throws(() => plan("nope", variants), /unknown image/);
  assert.throws(() => plan("vllm;rm -rf /", variants), /unknown image/);
  console.log("plan-image-builds self-test OK");
}

if (import.meta.url === `file://${process.argv[1]}`) {
  if (process.argv[2] === "--self-test") selfTest();
  else {
    const variants = JSON.parse(readFileSync(new URL("../variants.json", import.meta.url), "utf8")).images;
    console.log(`matrix=${JSON.stringify(plan(process.argv[2] ?? "", variants))}`);
  }
}
