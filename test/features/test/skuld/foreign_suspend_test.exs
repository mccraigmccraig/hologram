defmodule HologramFeatureTests.Skuld.ForeignSuspendTest do
  use HologramFeatureTests.TestCase, async: true

  alias HologramFeatureTests.Skuld.ForeignSuspendPage

  # alias HologramFeatureTests.JSDebug

  feature "sync JS call via FiberPool", %{session: session} do
    session
    |> visit(ForeignSuspendPage)
    |> assert_text("Skuld ForeignSuspend Test")
    |> click(button("Run fast"))
    |> assert_text("42")
  end

  feature "async JS call (Promise) via FiberPool", %{session: session} do
    session
    |> visit(ForeignSuspendPage)
    |> assert_text("Skuld ForeignSuspend Test")
    |> click(button("Run slow"))
    |> assert_text("async_done")
  end

  #   Debug telemetry (uncomment to trace):
  #   JSDebug.debug_keys("Elixir_Hologram_Skuld_JSRef", "__resolve__/2") ++
  #     JSDebug.debug_keys("Elixir_Skuld_Coroutine", "call/2") ++
  #     JSDebug.debug_keys("Elixir_Skuld_ForeignResolver_Runner", "run/1") ++
  #     JSDebug.debug_keys("Elixir_Skuld_FiberPool_Main", "apply_foreign_resolutions/2") ++
  #     JSDebug.log_keys()
  #   |> then(&JSDebug.dump_keys(session, &1))

  feature "concurrent sync + async via FiberPool", %{session: session} do
    session
    |> visit(ForeignSuspendPage)
    |> click(button("Run concurrent"))
    |> assert_text("first")
    |> assert_text("30")
  end
end
