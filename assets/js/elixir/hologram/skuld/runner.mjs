"use strict";

import ERTS from "../../../erts.mjs";
import Type from "../../../type.mjs";

const Elixir_Hologram_Skuld_Runner = {
  "__wrap__/1": (comp) => {
    const runner = globalThis.Elixir_Skuld_ForeignResolver_Runner;
    if (!runner) {
      throw new Error("Skuld.ForeignResolver.Runner module not loaded");
    }

    const result = runner["run/1"](comp);

    if (result instanceof Promise) {
      return ERTS.registerPromise(result);
    }

    return ERTS.registerPromise(Promise.resolve(result));
  },
};

export default Elixir_Hologram_Skuld_Runner;
