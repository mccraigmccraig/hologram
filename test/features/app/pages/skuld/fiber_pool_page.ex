defmodule HologramFeatureTests.Skuld.FiberPoolPage do
  use Hologram.Page

  import Hologram.Commons.KernelUtils, only: [inspect: 1]
  import Kernel, except: [inspect: 1]
  import Skuld.Comp.CompBlock

  alias Skuld.Comp
  alias Skuld.Effects.FiberPool

  route "/skuld/fiber-pool"

  layout HologramFeatureTests.Components.DefaultLayout

  def init(_params, component, _server) do
    put_state(component, :result, nil)
  end

  def template do
    ~HOLO"""
    <h1>Skuld FiberPool Test</h1>

    <button id="run-single" $click="run_single">Run single fiber</button>
    <button id="run-parallel" $click="run_parallel">Run 3 parallel fibers</button>

    <p>
      Result: <strong id="result"><code>{inspect(@result)}</code></strong>
    </p>
    """
  end

  def action(:run_single, _params, component) do
    result =
      comp do
        h <- FiberPool.fiber(42)
        FiberPool.await!(h)
      end
      |> FiberPool.with_handler()
      |> Comp.run!()

    put_state(component, :result, result)
  end

  def action(:run_parallel, _params, component) do
    result =
      comp do
        h1 <- FiberPool.fiber(10)
        h2 <- FiberPool.fiber(20)
        h3 <- FiberPool.fiber(30)
        FiberPool.await_all!([h1, h2, h3])
      end
      |> FiberPool.with_handler()
      |> Comp.run!()

    put_state(component, :result, result)
  end
end
