defmodule Hologram.Test.Fixtures.Compiler.Skuld.ForeignSuspendPage do
  use Hologram.Page

  import Skuld.Comp.CompBlock
  alias Skuld.Comp
  alias Skuld.Coroutine.Completed
  alias Skuld.Coroutine.ForeignSuspensions
  alias Skuld.Effects.FiberPool
  alias Skuld.ForeignResolver.Runner, as: ForeignRunner
  alias Hologram.Skuld.Effects.JS

  route "/hologram-test-fixtures-compiler-skuld-foreign-suspend"

  layout Hologram.Test.Fixtures.Compiler.Module6

  def template do
    ~HOLO"""
    <div id="result">waiting</div>
    <button id="run" $click={:run}>Run</button>
    """
  end

  def action(:run, _params, _component) do
    comp do
      h1 <- FiberPool.fiber(JS.call(:fetch, ["/api/1"]))
      h2 <- FiberPool.fiber(JS.call(:fetch, ["/api/2"]))
      results <- FiberPool.await_all!([h1, h2])
      results
    end
    |> JS.with_handler()
    |> FiberPool.with_handler()
    |> ForeignRunner.run()
  end
end
