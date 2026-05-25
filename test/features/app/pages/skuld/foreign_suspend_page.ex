defmodule HologramFeatureTests.Skuld.ForeignSuspendPage do
  use Hologram.Page
  use Hologram.JS

  import Hologram.Commons.KernelUtils, only: [inspect: 1]
  import Kernel, except: [inspect: 1]
  import Skuld.Comp.CompBlock

  alias Skuld.Effects.FiberPool
  alias Hologram.Skuld.Effects.JS, as: SkuldJS
  alias Hologram.Skuld.Runner

  route "/skuld/foreign-suspend"

  layout HologramFeatureTests.Components.DefaultLayout

  def init(_params, component, _server) do
    Hologram.JS.exec("globalThis.__slow__ = (v) => new Promise(resolve => setTimeout(() => resolve(v), 50));")
    Hologram.JS.exec("globalThis.__fast__ = (a, b) => a + b;")

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
    result =
      comp do
        h <- FiberPool.fiber(SkuldJS.call(:__fast__, [21, 21]))
        FiberPool.await!(h)
      end
      |> SkuldJS.with_handler()
      |> FiberPool.with_handler()
      |> Runner.run()
      |> Task.await()

    put_state(component, :result, result)
  end

  def action(:run_slow, _params, component) do
    result =
      comp do
        h <- FiberPool.fiber(SkuldJS.call(:__slow__, ["async_done"]))
        FiberPool.await!(h)
      end
      |> SkuldJS.with_handler()
      |> FiberPool.with_handler()
      |> Runner.run()
      |> Task.await()

    put_state(component, :result, result)
  end

  def action(:run_concurrent, _params, component) do
    result =
      comp do
        h1 <- FiberPool.fiber(SkuldJS.call(:__slow__, ["first"]))
        h2 <- FiberPool.fiber(SkuldJS.call(:__fast__, [10, 20]))
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
