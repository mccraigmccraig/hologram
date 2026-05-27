"use strict";

import ERTS from "../../../../../assets/js/erts.mjs";
import Interpreter from "../../../../../assets/js/interpreter.mjs";
import Type from "../../../../../assets/js/type.mjs";

import {assert, sinon} from "../../../support/helpers.mjs";

import Elixir_Hologram_Skuld_JSRef
  from "../../../../../assets/js/elixir/hologram/skuld/js_ref.mjs";

import Elixir_Hologram_Skuld_Effects_JS
  from "../../../../../assets/js/elixir/hologram/skuld/effects_js.mjs";

const ID_ATOM = Type.atom("id");
const PAYLOAD_ATOM = Type.atom("payload");
const REF_ATOM = Type.atom("ref");

function buildForeignSuspend(id, jsRef) {
  return Type.struct("Elixir.Skuld.Comp.ForeignSuspend", [
    [ID_ATOM, id],
    [PAYLOAD_ATOM, jsRef],
  ]);
}

function buildJSRef(ref) {
  return Type.struct("Elixir.Hologram.Skuld.JSRef", [[REF_ATOM, ref]]);
}

function recordContinuation() {
  let calls = [];

  const stub = sinon
    .stub(Interpreter, "callAnonymousFunction")
    .callsFake((continuation, argsArray) => {
      calls.push({
        continuation,
        resolvedMap: argsArray[0],
      });

      return Type.atom("ok");
    });

  return {calls, stub};
}

describe("ForeignSuspend resolution loop (integration)", () => {
  beforeEach(() => {
    ERTS.nativeObjectRegistry.clear();
  });

  afterEach(() => {
    sinon.restore();
  });

  it("resolves a single round of foreign suspends", async () => {
    const result = Promise.resolve("data_from_fetch");

    const suspends = Type.list([
      buildForeignSuspend(
        Type.atom("fiber_1"),
        buildJSRef(ERTS.registerNativeObject(result)),
      ),
    ]);

    const {calls} = recordContinuation();
    const DUMMY_CONT = Type.atom("cont");

    await Elixir_Hologram_Skuld_JSRef["__resolve__/2"](suspends, DUMMY_CONT);

    assert.strictEqual(calls.length, 1);
    const expected = Type.map([
      [Type.atom("fiber_1"), Type.bitstring("data_from_fetch")],
    ]);

    assert.isTrue(
      Interpreter.isStrictlyEqual(calls[0].resolvedMap, expected),
    );
  });

  it("resolves multiple foreign suspends from different JS calls", async () => {
    globalThis.__apiA__ = () => Promise.resolve("A");
    globalThis.__apiB__ = () => Promise.resolve("B");

    const suspends = Type.list([
      buildForeignSuspend(
        Type.atom("a"),
        buildJSRef(
          Elixir_Hologram_Skuld_Effects_JS["__native_call__/2"](
            Type.atom("__apiA__"),
            Type.list([]),
          ).data[1],
        ),
      ),
      buildForeignSuspend(
        Type.atom("b"),
        buildJSRef(
          Elixir_Hologram_Skuld_Effects_JS["__native_call__/2"](
            Type.atom("__apiB__"),
            Type.list([]),
          ).data[1],
        ),
      ),
    ]);

    const {calls} = recordContinuation();
    const DUMMY_CONT = Type.atom("cont");

    await Elixir_Hologram_Skuld_JSRef["__resolve__/2"](suspends, DUMMY_CONT);

    assert.strictEqual(calls.length, 1);
    assert.isTrue(
      Interpreter.isStrictlyEqual(
        calls[0].resolvedMap,
        Type.map([
          [Type.atom("a"), Type.bitstring("A")],
          [Type.atom("b"), Type.bitstring("B")],
        ]),
      ),
    );

    delete globalThis.__apiA__;
    delete globalThis.__apiB__;
  });

  it("full pipeline: JS call → register Promise → resolve all → continuation", async () => {
    globalThis.__fetch__ = () =>
      new Promise((resolve) => setTimeout(() => resolve("slow_data"), 5));

    const suspends = Type.list([
      buildForeignSuspend(
        Type.integer(1),
        buildJSRef(
          Elixir_Hologram_Skuld_Effects_JS["__native_call__/2"](
            Type.atom("__fetch__"),
            Type.list([]),
          ).data[1],
        ),
      ),
      buildForeignSuspend(
        Type.integer(2),
        buildJSRef(
          Elixir_Hologram_Skuld_Effects_JS["__native_call__/2"](
            Type.atom("__fetch__"),
            Type.list([]),
          ).data[1],
        ),
      ),
    ]);

    const {calls} = recordContinuation();
    const DUMMY_CONT = Type.atom("cont");

    await Elixir_Hologram_Skuld_JSRef["__resolve__/2"](suspends, DUMMY_CONT);

    assert.strictEqual(calls.length, 1);
    assert.isTrue(
      Interpreter.isStrictlyEqual(
        calls[0].resolvedMap,
        Type.map([
          [Type.integer(1), Type.bitstring("slow_data")],
          [Type.integer(2), Type.bitstring("slow_data")],
        ]),
      ),
    );

    delete globalThis.__fetch__;
  });

  it("action-like flow: run suspends and return final value via continuation", async () => {
    globalThis.__getUser__ = (id) => Promise.resolve(`user_${id}`);

    const suspends = Type.list([
      buildForeignSuspend(
        Type.atom("req_a"),
        buildJSRef(
          Elixir_Hologram_Skuld_Effects_JS["__native_call__/2"](
            Type.atom("__getUser__"),
            Type.list([Type.integer(1)]),
          ).data[1],
        ),
      ),
      buildForeignSuspend(
        Type.atom("req_b"),
        buildJSRef(
          Elixir_Hologram_Skuld_Effects_JS["__native_call__/2"](
            Type.atom("__getUser__"),
            Type.list([Type.integer(2)]),
          ).data[1],
        ),
      ),
    ]);

    let finalResult = null;

    const contSpy = sinon
      .stub(Interpreter, "callAnonymousFunction")
      .callsFake((continuation, argsArray) => {
        finalResult = argsArray[0];

        return Type.atom("ok");
      });

    await Elixir_Hologram_Skuld_JSRef["__resolve__/2"](
      suspends,
      Type.atom("action_cont"),
    );

    sinon.assert.calledOnce(contSpy);
    assert.isTrue(
      Interpreter.isStrictlyEqual(
        finalResult,
        Type.map([
          [Type.atom("req_a"), Type.bitstring("user_1")],
          [Type.atom("req_b"), Type.bitstring("user_2")],
        ]),
      ),
    );

    delete globalThis.__getUser__;
  });
});
