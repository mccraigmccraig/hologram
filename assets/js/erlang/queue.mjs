"use strict";

import Interpreter from "../interpreter.mjs";
import Type from "../type.mjs";

const Erlang_Queue = {
  // Start in/2
  "in/2": (item, queue) => {
    const inList = queue.data[0];
    const outList = queue.data[1];

    return Type.tuple([Type.list([item, ...inList.data]), outList]);
  },
  // End in/2
  // Deps: []

  // Start is_empty/1
  "is_empty/1": (queue) => {
    const inList = queue.data[0];
    const outList = queue.data[1];

    return Type.boolean(
      inList.data.length === 0 && outList.data.length === 0,
    );
  },
  // End is_empty/1
  // Deps: []

  // Start len/1
  "len/1": (queue) => {
    const inList = queue.data[0];
    const outList = queue.data[1];

    return Type.integer(inList.data.length + outList.data.length);
  },
  // End len/1
  // Deps: []

  // Start new/0
  "new/0": () => {
    return Type.tuple([Type.list(), Type.list()]);
  },
  // End new/0
  // Deps: []

  // Start out/1
  "out/1": (queue) => {
    const inList = queue.data[0];
    const outList = queue.data[1];

    if (outList.data.length > 0) {
      const [item, ...rest] = outList.data;

      return Type.tuple([
        Type.tuple([Type.atom("value"), item]),
        Type.tuple([inList, Type.list(rest)]),
      ]);
    }

    if (inList.data.length === 0) {
      return Type.tuple([Type.atom("empty"), queue]);
    }

    const reversed = [...inList.data].reverse();
    const [item, ...rest] = reversed;

    return Type.tuple([
      Type.tuple([Type.atom("value"), item]),
      Type.tuple([Type.list(), Type.list(rest)]),
    ]);
  },
  // End out/1
  // Deps: []
};

export default Erlang_Queue;
