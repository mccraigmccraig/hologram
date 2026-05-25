"use strict";

import ERTS from "../../../erts.mjs";
import Interpreter from "../../../interpreter.mjs";
import {box} from "../../../js_interop.mjs";
import Type from "../../../type.mjs";

const ID_KEY = Type.encodeMapKey(Type.atom("id"));
const PAYLOAD_KEY = Type.encodeMapKey(Type.atom("payload"));
const REF_KEY = Type.encodeMapKey(Type.atom("ref"));

function field(mapTerm, key) {
  return mapTerm.data[key][1];
}

const Elixir_Hologram_Skuld_JSRef = {
  "__resolve__/2": (suspends, continuation) => {
    const suspendData = suspends.data;

    const promises = suspendData.map((suspend) => {
      const jsRef = field(suspend, PAYLOAD_KEY);
      const ref = field(jsRef, REF_KEY);

      return ERTS.nativeObjectRegistry.get(ref);
    });

    return Promise.all(promises).then((rawResults) => {
      const entries = suspendData.map((suspend, i) => {
        const id = field(suspend, ID_KEY);

        return [id, box(rawResults[i])];
      });

      const resolved = Type.map(entries);

      return Interpreter.callAnonymousFunction(
        continuation,
        Type.list([resolved]),
      );
    });
  },
};

export default Elixir_Hologram_Skuld_JSRef;
