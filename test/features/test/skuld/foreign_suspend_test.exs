defmodule HologramFeatureTests.Skuld.ForeignSuspendTest do
  use HologramFeatureTests.TestCase, async: true

  alias HologramFeatureTests.Skuld.ForeignSuspendPage

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
    |> click(button("Run slow"))
    |> assert_text(~r/async_done/)
  end

  feature "concurrent sync + async via FiberPool", %{session: session} do
    session
    |> visit(ForeignSuspendPage)
    |> click(button("Run concurrent"))
    |> assert_text(~r/first/)
    |> assert_text("30")
  end
end
