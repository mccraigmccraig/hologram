"use strict";

import ERTS from "../../../../erts.mjs";
import Type from "../../../../type.mjs";

import {unbox} from "../../js.mjs";

function atomValue(term) {
  if (Type.isAtom(term)) {
    return term.value;
  }
}

function unboxValue(term) {
  if (Type.isAtom(term)) {
    if (term.value === "true") return true;
    if (term.value === "false") return false;
    if (term.value === "nil") return null;

    return term.value;
  }

  if (Type.isInteger(term)) {
    return Number(term.value);
  }

  if (Type.isFloat(term)) {
    return term.value;
  }

  if (Type.isBinary(term) || Type.isBitstring(term)) {
    let text = term.text;
    if (text === null) {
      const decoder = new TextDecoder();
      text = decoder.decode(new Uint8Array(term.bytes));
    }

    return text;
  }

  if (Type.isList(term)) {
    return term.data.map(unboxValue);
  }

  if (Type.isMap(term)) {
    const obj = {};

    for (const [, [key, value]] of Object.entries(term.data)) {
      obj[unboxValue(key)] = unboxValue(value);
    }

    return obj;
  }

  if (Type.isNativeValueStruct(term)) {
    return unbox(term, null);
  }

  return term;
}

function resolveJSFunction(functionArg) {
  if (Type.isAtom(functionArg)) {
    const name = functionArg.value;
    const fn = globalThis[name];

    if (typeof fn !== "function") {
      throw new Error(`JS.call: "${name}" is not a function on globalThis`);
    }

    return fn;
  }

  if (Type.isNativeValueStruct(functionArg)) {
    return unbox(functionArg, null);
  }

  throw new Error(
    `JS.call: expected an atom or NativeValue, got ${functionArg.type}`,
  );
}

const Elixir_Hologram_Skuld_Effects_JS = {
  "__native_call__/2": (functionArg, args) => {
    const jsFn = resolveJSFunction(functionArg);
    const jsArgs = Type.isList(args) ? args.data.map(unboxValue) : [];

    const result = jsFn(...jsArgs);

    const ref = ERTS.registerNativeObject(result);

    return ref;
  },
};

export default Elixir_Hologram_Skuld_Effects_JS;
