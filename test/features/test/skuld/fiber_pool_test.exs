defmodule HologramFeatureTests.Skuld.FiberPoolTest do
  use HologramFeatureTests.TestCase, async: true

  alias HologramFeatureTests.Skuld.FiberPoolPage

  feature "single fiber", %{session: session} do
    session
    |> visit(FiberPoolPage)
    |> assert_text("Skuld FiberPool Test")
    |> click(button("Run single fiber"))
    |> assert_text("42")
  end

  feature "parallel fibers", %{session: session} do
    session
    |> visit(FiberPoolPage)
    |> click(button("Run 3 parallel fibers"))
    |> assert_text("[10, 20, 30]")
  end
end
