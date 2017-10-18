defmodule Swoosh.TemplateTest do
  use ExUnit.Case, async: true

  defmodule FakeTemplate do
    use Swoosh.Template, root: Path.join(__DIR__, "../fixtures/templates")
  end

  describe "render/2" do
    test "returns a compiled template" do
      assert FakeTemplate.render("template", %{ subject: "world" }) == "Hello, world!\n"
    end
  end
end
