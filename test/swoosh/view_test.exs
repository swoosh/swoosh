Code.require_file "../support/fixtures/views.exs", __DIR__

defmodule Swoosh.ViewTest do
  use ExUnit.Case, async: true

  describe "render/3" do
    test "renders template" do
      assert Swoosh.View.render(MyApp.FakeView, "template_1", %{}) ==
        "Hello, world!\n"
    end

    test "renders layout" do
      assert Swoosh.View.render(MyApp.FakeView, "template_1", layout: { MyApp.FakeLayout, "layout" }) ==
        "This is a layout!\n\nHello, world!\n"
    end

    test "assigns variables" do
      assert Swoosh.View.render(MyApp.FakeView, "template_2", subject: "world") ==
        "Hello, world!\n"
    end
  end
end
