defmodule HologramFeatureTests.Skuld.ForeignSuspendPage do
  use Hologram.Page
  use Hologram.JS

  import Hologram.Commons.KernelUtils, only: [inspect: 1]
  import Kernel, except: [inspect: 1]
  import Skuld.Comp.CompBlock

  # alias HologramFeatureTests.JSDebug
  alias Hologram.Skuld.Effects.JS, as: SkuldJS
  alias Hologram.Skuld.Runner
  alias Skuld.Effects.FiberPool

  route "/skuld/foreign-suspend"

  layout HologramFeatureTests.Components.DefaultLayout

  def init(_params, component, _server) do
    put_state(component, :result, nil)
  end

  def template do
    ~HOLO"""
    <h1>Skuld ForeignSuspend Test</h1>

    <button id="run-fast" $click="run_fast">Run fast (sync JS)</button>
    <button id="run-slow" $click="run_slow">Run slow (Promise JS)</button>
    <button id="run-concurrent" $click="run_concurrent">Run concurrent (mixed sync + Promise)</button>

    <p>
      Result: <strong id="result"><code>{inspect(@result)}</code></strong>
    </p>
    """
  end

  def action(:run_fast, _params, component) do
    Hologram.JS.eval("globalThis.__fast__ = (a, b) => a + b")

    result =
      comp do
        SkuldJS.call(:__fast__, [21, 21])
      end
      |> SkuldJS.with_handler()
      |> FiberPool.with_handler()
      |> Runner.run()
      |> Task.await()

    put_state(component, :result, result)
  end

  def action(:run_slow, _params, component) do
    Hologram.JS.eval(
      "globalThis.__slow__ = (v) => new Promise(resolve => setTimeout(() => resolve(v), 50))"
    )

    # Debug telemetry (uncomment to trace):
    # Hologram.JS.eval(JSDebug.wrap_debug("Elixir_Hologram_Skuld_JSRef", "__resolve__/2", 2))
    # Hologram.JS.eval(JSDebug.wrap_debug("Elixir_Skuld_Coroutine", "call/2", 2))
    # Hologram.JS.eval(JSDebug.wrap_debug("Elixir_Skuld_ForeignResolver_Runner", "run/1", 1))
    # Hologram.JS.eval(JSDebug.wrap_debug("Elixir_Skuld_FiberPool_Main", "apply_foreign_resolutions/2", 2))
    # Hologram.JS.eval(JSDebug.setup_log())
    # JSDebug.log(:info, "run_slow starting")

    result =
      comp do
        h <- SkuldJS.async(:__slow__, ["async_done"])
        FiberPool.await!(h)
      end
      |> SkuldJS.with_handler()
      |> FiberPool.with_handler()
      |> Runner.run()
      |> Task.await()

    put_state(component, :result, result)
  end

  def action(:run_concurrent, _params, component) do
    Hologram.JS.eval(
      "globalThis.__slow__ = (v) => new Promise(resolve => setTimeout(() => resolve(v), 50))"
    )

    Hologram.JS.eval("globalThis.__fast__ = (a, b) => a + b")

    result =
      comp do
        h1 <- SkuldJS.async(:__slow__, ["first"])
        h2 <- SkuldJS.async(:__fast__, [10, 20])
        [r1, r2] <- FiberPool.await_all!([h1, h2])
        {r1, r2}
      end
      |> SkuldJS.with_handler()
      |> FiberPool.with_handler()
      |> Runner.run()
      |> Task.await()

    put_state(component, :result, result)
  end
end
