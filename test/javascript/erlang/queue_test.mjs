"use strict";

import {
  assert,
  assertBoxedFalse,
  assertBoxedTrue,
  defineGlobalErlangAndElixirModules,
  freeze,
} from "../support/helpers.mjs";

import Erlang_Queue from "../../../assets/js/erlang/queue.mjs";
import Interpreter from "../../../assets/js/interpreter.mjs";
import Type from "../../../assets/js/type.mjs";

defineGlobalErlangAndElixirModules();

const integer1 = freeze(Type.integer(1));
const integer2 = freeze(Type.integer(2));
const integer3 = freeze(Type.integer(3));

const atomEmpty = freeze(Type.atom("empty"));
const atomValue = freeze(Type.atom("value"));

function emptyQueue() {
  return Type.tuple([Type.list(), Type.list()]);
}

describe("Erlang_Queue", () => {
  describe("new/0", () => {
    it("returns an empty queue", () => {
      const q = Erlang_Queue["new/0"]();

      assert.deepStrictEqual(q, emptyQueue());
      assertBoxedTrue(Erlang_Queue["is_empty/1"](q));
    });
  });

  describe("in/2", () => {
    it("adds an item to an empty queue", () => {
      const q = Erlang_Queue["in/2"](integer1, emptyQueue());

      assertBoxedFalse(Erlang_Queue["is_empty/1"](q));
      assert.deepStrictEqual(
        Erlang_Queue["len/1"](q),
        Type.integer(1),
      );
    });

    it("adds multiple items in FIFO order", () => {
      const q = Erlang_Queue["new/0"]();
      const q1 = Erlang_Queue["in/2"](integer1, q);
      const q2 = Erlang_Queue["in/2"](integer2, q1);
      const q3 = Erlang_Queue["in/2"](integer3, q2);

      assert.deepStrictEqual(
        Erlang_Queue["len/1"](q3),
        Type.integer(3),
      );
    });
  });

  describe("out/1", () => {
    it("returns :empty for an empty queue", () => {
      const result = Erlang_Queue["out/1"](emptyQueue());

      assert.deepStrictEqual(result.data[0], atomEmpty);
    });

    it("returns {:value, item} and shortened queue", () => {
      const q = Erlang_Queue["in/2"](integer1, emptyQueue());
      const result = Erlang_Queue["out/1"](q);

      assert.deepStrictEqual(
        result.data[0],
        Type.tuple([atomValue, integer1]),
      );

      assertBoxedTrue(Erlang_Queue["is_empty/1"](result.data[1]));
    });

    it("dequeues in FIFO order", () => {
      let q = Erlang_Queue["new/0"]();
      q = Erlang_Queue["in/2"](integer1, q);
      q = Erlang_Queue["in/2"](integer2, q);
      q = Erlang_Queue["in/2"](integer3, q);

      const r1 = Erlang_Queue["out/1"](q);

      assert.deepStrictEqual(
        r1.data[0],
        Type.tuple([atomValue, integer1]),
      );

      const r2 = Erlang_Queue["out/1"](r1.data[1]);

      assert.deepStrictEqual(
        r2.data[0],
        Type.tuple([atomValue, integer2]),
      );

      const r3 = Erlang_Queue["out/1"](r2.data[1]);

      assert.deepStrictEqual(
        r3.data[0],
        Type.tuple([atomValue, integer3]),
      );

      assertBoxedTrue(Erlang_Queue["is_empty/1"](r3.data[1]));
    });

    it("handles out_list exhaustion", () => {
      // Enqueue two items, dequeue one — out_list has one left
      let q = Erlang_Queue["new/0"]();
      q = Erlang_Queue["in/2"](integer1, q);
      q = Erlang_Queue["in/2"](integer2, q);

      const r1 = Erlang_Queue["out/1"](q);

      // Now enqueue a third — goes to in_list
      let q2 = Erlang_Queue["in/2"](integer3, r1.data[1]);

      const r2 = Erlang_Queue["out/1"](q2);

      assert.deepStrictEqual(
        r2.data[0],
        Type.tuple([atomValue, integer2]),
      );

      const r3 = Erlang_Queue["out/1"](r2.data[1]);

      assert.deepStrictEqual(
        r3.data[0],
        Type.tuple([atomValue, integer3]),
      );
    });
  });

  describe("is_empty/1", () => {
    it("returns true for an empty queue", () => {
      assertBoxedTrue(Erlang_Queue["is_empty/1"](emptyQueue()));
    });

    it("returns false with items in in_list", () => {
      const q = Erlang_Queue["in/2"](integer1, emptyQueue());

      assertBoxedFalse(Erlang_Queue["is_empty/1"](q));
    });
  });

  describe("len/1", () => {
    it("returns 0 for an empty queue", () => {
      assert.deepStrictEqual(
        Erlang_Queue["len/1"](emptyQueue()),
        Type.integer(0),
      );
    });

    it("counts items in both in_list and out_list", () => {
      let q = Erlang_Queue["new/0"]();
      q = Erlang_Queue["in/2"](integer1, q);
      q = Erlang_Queue["in/2"](integer2, q);

      const r = Erlang_Queue["out/1"](q);
      q = Erlang_Queue["in/2"](integer3, r.data[1]);

      assert.deepStrictEqual(
        Erlang_Queue["len/1"](q),
        Type.integer(2),
      );
    });
  });
});
