"use strict";

import ERTS from "../../../../../assets/js/erts.mjs";
import Interpreter from "../../../../../assets/js/interpreter.mjs";
import Type from "../../../../../assets/js/type.mjs";

import {assert, sinon} from "../../../support/helpers.mjs";

import Elixir_Hologram_Skuld_JSRef from "../../../../../assets/js/elixir/hologram/skuld/js_ref.mjs";

const DUMMY_CONTINUATION = Type.atom("dummy_continuation");

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
  return Type.struct("Elixir.Hologram.Skuld.JSRef", [
    [REF_ATOM, ref],
  ]);
}

function recordContinuation() {
  const calls = [];

  const stub = sinon
    .stub(Interpreter, "callAnonymousFunction")
    .callsFake((continuation, argsArray) => {
      const resolvedMap = argsArray[0];

      calls.push({continuation, resolvedMap});

      return Type.atom("ok");
    });

  return {stub, calls};
}

describe("Elixir_Hologram_Skuld_JSRef", () => {
  beforeEach(() => {
    ERTS.nativeObjectRegistry.clear();
  });

  afterEach(() => {
    sinon.restore();
  });

  describe("__resolve__/2", () => {
    it("resolves a single Promise and passes the value to the continuation", async () => {
      const promise = Promise.resolve("hello");
      const ref = ERTS.registerNativeObject(promise);
      const jsRef = buildJSRef(ref);
      const suspend = buildForeignSuspend(Type.atom("s1"), jsRef);
      const suspends = Type.list([suspend]);

      const {calls} = recordContinuation();

      await Elixir_Hologram_Skuld_JSRef["__resolve__/2"](
        suspends,
        DUMMY_CONTINUATION,
      );

      assert.strictEqual(calls.length, 1);

      const resolvedMap = calls[0].resolvedMap;

      assert.isTrue(
        Interpreter.isStrictlyEqual(
          resolvedMap,
          Type.map([[Type.atom("s1"), Type.bitstring("hello")]]),
        ),
      );
    });

    it("resolves multiple Promises in parallel", async () => {
      const p1 = Promise.resolve("first");
      const p2 = Promise.resolve("second");
      const p3 = Promise.resolve("third");

      const suspends = Type.list([
        buildForeignSuspend(Type.atom("a"), buildJSRef(ERTS.registerNativeObject(p1))),
        buildForeignSuspend(Type.atom("b"), buildJSRef(ERTS.registerNativeObject(p2))),
        buildForeignSuspend(Type.atom("c"), buildJSRef(ERTS.registerNativeObject(p3))),
      ]);

      const {calls} = recordContinuation();

      await Elixir_Hologram_Skuld_JSRef["__resolve__/2"](
        suspends,
        DUMMY_CONTINUATION,
      );

      assert.strictEqual(calls.length, 1);

      const resolvedMap = calls[0].resolvedMap;
      const expected = Type.map([
        [Type.atom("a"), Type.bitstring("first")],
        [Type.atom("b"), Type.bitstring("second")],
        [Type.atom("c"), Type.bitstring("third")],
      ]);

      assert.isTrue(Interpreter.isStrictlyEqual(resolvedMap, expected));
    });

    it("calls the continuation with the correct continuation reference", async () => {
      const promise = Promise.resolve(42);
      const ref = ERTS.registerNativeObject(promise);
      const suspend = buildForeignSuspend(
        Type.integer(1),
        buildJSRef(ref),
      );

      const {calls, stub} = recordContinuation();

      await Elixir_Hologram_Skuld_JSRef["__resolve__/2"](
        Type.list([suspend]),
        DUMMY_CONTINUATION,
      );

      sinon.assert.calledWith(stub, DUMMY_CONTINUATION);
    });

    it("handles empty suspends list", async () => {
      const suspends = Type.list([]);

      const {calls} = recordContinuation();

      await Elixir_Hologram_Skuld_JSRef["__resolve__/2"](
        suspends,
        DUMMY_CONTINUATION,
      );

      assert.strictEqual(calls.length, 1);
      assert.isTrue(
        Interpreter.isStrictlyEqual(calls[0].resolvedMap, Type.map([])),
      );
    });

    it("propagates Promise rejection as a failed resolution", async () => {
      const promise = Promise.reject(new Error("boom"));
      const ref = ERTS.registerNativeObject(promise);
      const suspend = buildForeignSuspend(
        Type.atom("err_1"),
        buildJSRef(ref),
      );

      const {calls} = recordContinuation();

      try {
        await Elixir_Hologram_Skuld_JSRef["__resolve__/2"](
          Type.list([suspend]),
          DUMMY_CONTINUATION,
        );

        assert.fail("should have thrown");
      } catch (e) {
        assert.instanceOf(e, Error);
        assert.strictEqual(e.message, "boom");
      }

      assert.strictEqual(calls.length, 0);
    });

    it("preserves suspend ID types in the resolved map", async () => {
      const promise = Promise.resolve("val");
      const ref = ERTS.registerNativeObject(promise);

      const idInt = Type.integer(7);
      const idAtom = Type.atom("fiber_1");

      const suspends = Type.list([
        buildForeignSuspend(idInt, buildJSRef(ref)),
        buildForeignSuspend(idAtom, buildJSRef(ERTS.registerNativeObject(Promise.resolve("val2")))),
      ]);

      const {calls} = recordContinuation();

      await Elixir_Hologram_Skuld_JSRef["__resolve__/2"](
        suspends,
        DUMMY_CONTINUATION,
      );

      const resolvedMap = calls[0].resolvedMap;

      assert.isTrue(
        Interpreter.isStrictlyEqual(
          resolvedMap,
          Type.map([
            [idInt, Type.bitstring("val")],
            [idAtom, Type.bitstring("val2")],
          ]),
        ),
      );
    });
  });
});
