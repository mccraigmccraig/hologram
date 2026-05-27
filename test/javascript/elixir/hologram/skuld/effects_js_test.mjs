"use strict";

import ERTS from "../../../../../assets/js/erts.mjs";
import Type from "../../../../../assets/js/type.mjs";

import {assert, sinon, registerWebApis} from "../../../support/helpers.mjs";

import Elixir_Hologram_Skuld_Effects_JS
  from "../../../../../assets/js/elixir/hologram/skuld/effects_js.mjs";

describe("Elixir_Hologram_Skuld_Effects_JS", () => {
  beforeEach(() => {
    registerWebApis();
    ERTS.nativeObjectRegistry.clear();
  });

  afterEach(() => {
    sinon.restore();
  });

  describe("__native_call__/2", () => {
    it("calls a global function by atom name", () => {
      const spy = sinon.spy(() => "fn_result");
      globalThis.__testFn__ = spy;

      const fnAtom = Type.atom("__testFn__");
      const args = Type.list([Type.bitstring("hello"), Type.integer(42)]);

      const result = Elixir_Hologram_Skuld_Effects_JS["__native_call__/2"](
        fnAtom,
        args,
      );

      sinon.assert.calledOnceWithExactly(spy, "hello", 42);

      assert.strictEqual(result.data[0].value, "sync");
      assert.strictEqual(result.data[1].text, "fn_result");

      delete globalThis.__testFn__;
    });

    it("returns a reference that resolves to the stored Promise", async () => {
      globalThis.__asyncFn__ = () => Promise.resolve("async_result");

      const fnAtom = Type.atom("__asyncFn__");
      const args = Type.list([]);

      const result = Elixir_Hologram_Skuld_Effects_JS["__native_call__/2"](
        fnAtom,
        args,
      );

      assert.strictEqual(result.data[0].value, "async");
      const ref = result.data[1];

      const stored = ERTS.nativeObjectRegistry.get(ref);
      assert.instanceOf(stored, Promise);

      const resolved = await stored;
      assert.strictEqual(resolved, "async_result");

      delete globalThis.__asyncFn__;
    });

    it("handles functions returning plain values", () => {
      globalThis.__plainFn__ = () => 100;

      const result = Elixir_Hologram_Skuld_Effects_JS["__native_call__/2"](
        Type.atom("__plainFn__"),
        Type.list([]),
      );

      assert.strictEqual(result.data[0].value, "sync");
      assert.strictEqual(result.data[1].value, 100n);

      delete globalThis.__plainFn__;
    });

    it("throw an error for unknown global function", () => {
      assert.throws(
        () =>
          Elixir_Hologram_Skuld_Effects_JS["__native_call__/2"](
            Type.atom("__nonexistent_fn__"),
            Type.list([]),
          ),
        /not a function on globalThis/,
      );
    });

    it("unboxes all argument types correctly", () => {
      globalThis.__echo__ = (...a) => a;

      const fnAtom = Type.atom("__echo__");
      const args = Type.list([
        Type.atom("hello"),
        Type.integer(42),
        Type.bitstring("world"),
        Type.atom("true"),
        Type.atom("false"),
        Type.atom("nil"),
      ]);

      const result = Elixir_Hologram_Skuld_Effects_JS["__native_call__/2"](
        fnAtom,
        args,
      );

      assert.strictEqual(result.data[0].value, "sync");
      // box() wraps a JS array as a Type.list
      const listResult = result.data[1];
      assert.strictEqual(listResult.type, "list");
      assert.strictEqual(listResult.data.length, 6);

      delete globalThis.__echo__;
    });
  });
});
