defmodule Hologram.Skuld.Runner do
  @moduledoc """
  Hologram-specific runner that wraps the ForeignResolver.Runner result
  in a `%Task{}` struct so it can be used with `Task.await/1` in actions.

      result =
        comp do
          h <- FiberPool.fiber(JS.call(:fetch, ["/api"]))
          FiberPool.await!(h)
        end
        |> JS.with_handler()
        |> FiberPool.with_handler()
        |> Hologram.Skuld.Runner.run()
        |> Task.await()

      put_state(component, :result, result)

  On the Hologram JS runtime, `run/1` calls `ForeignResolver.Runner.run/1`
  and wraps the resulting Promise in a `%Task{}` via `PromiseRegistry`.
  On the server, this raises.
  """

  alias Skuld.Comp.Types

  @doc """
  Run a computation through the ForeignResolver and wrap the result
  as a Task for use with `Task.await/1`.
  """
  @spec run(Types.computation()) :: Task.t()
  def run(comp) do
    _ensure_call_graph = &Skuld.ForeignResolver.Runner.run/1
    Hologram.Skuld.Runner.__wrap__(comp)
  end

  @doc false
  @spec __wrap__(Types.computation()) :: term()
  def __wrap__(_comp) do
    raise "Hologram.Skuld.Runner.__wrap__/1 is only available in the Hologram browser runtime"
  end
end
