defmodule Swoosh.ViewTest do
  use ExUnit.Case, async: true

  defmodule FakeLayout do
    use Swoosh.View, root: Path.join(__DIR__, "../support/fixtures/templates/layout")
  end

  defmodule FakeView do
    use Swoosh.View, root: Path.join(__DIR__, "../support/fixtures/templates")
  end

  describe "render/3" do
    test "renders template" do
      assert Swoosh.View.render(FakeView, "template_1", %{}) ==
        "Hello, world!\n"
    end

    test "renders layout" do
      assert Swoosh.View.render(FakeView, "template_1", layout: { FakeLayout, "layout" }) ==
        "This is a layout!\n\nHello, world!\n"
    end

    test "assigns variables" do
      assert Swoosh.View.render(FakeView, "template_2", subject: "world") ==
        "Hello, world!\n"
    end
  end
end
