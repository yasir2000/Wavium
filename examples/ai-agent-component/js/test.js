import test from "node:test";
import assert from "node:assert/strict";
import { execute, plan, publish, step, verify } from "./index.js";

test("stage handlers return expected outputs", () => {
  assert.equal(plan("plan"), "plan: assemble a native workflow graph without network calls");
  assert.equal(execute("execute"), "execute: run the next component directly inside the host-managed flow");
  assert.equal(verify("verify"), "verify: confirm the workflow output without leaving the component boundary");
  assert.equal(publish("publish"), "publish: emit the final artifact from native state");
});

test("dispatcher maps known stages", () => {
  assert.equal(step("plan"), "plan: assemble a native workflow graph without network calls");
  assert.equal(step("anything-else"), "component observed input");
});
