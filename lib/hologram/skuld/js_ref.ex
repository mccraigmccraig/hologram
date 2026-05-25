defmodule Hologram.Skuld.JSRef do
  @moduledoc """
  Opaque reference to a JavaScript Promise, used as the `payload` of
  a `Skuld.Comp.ForeignSuspend` in the Hologram browser runtime.

  The `:ref` field holds a Hologram reference value that maps to the
  actual JS Promise in the `NativeObjectRegistry`. The Promise is
  registered when the JS effect creates the ForeignSuspend, and
  retrieved at resolution time by `Promise.all`.

  ## Lifecycle

  1. A Skuld fiber calls the JS effect → handler registers the Promise
     in `NativeObjectRegistry` and returns a `ForeignSuspend` with a
     `JSRef` payload carrying the registry reference.
  2. The FiberPool scheduler bundles all `ForeignSuspend` values into
     a `ForeignSuspensions` aggregate.
  3. `ForeignResolver.Runner` calls `await_resolutions/3` on the
     protocol impl, which delegates to `__resolve__/2`.
  4. The JS-side `__resolve__/2` extracts all Promises, calls
     `Promise.all`, and invokes the continuation with a resolved map.
  """

  defstruct [:ref]

  @type t :: %__MODULE__{ref: term()}

  @doc false
  @spec __resolve__([Skuld.Comp.ForeignSuspend.t()], function()) :: term()
  def __resolve__(_suspends, _continuation) do
    raise "Hologram.Skuld.JSRef.__resolve__/2 is only available in the Hologram browser runtime"
  end
end

defimpl Skuld.ForeignResolver, for: Hologram.Skuld.JSRef do
  @moduledoc false

  def await_resolutions(_payload, suspends, continuation) do
    Hologram.Skuld.JSRef.__resolve__(suspends, continuation)
  end
end
