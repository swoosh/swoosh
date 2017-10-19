defmodule Swoosh.TemplateTest do
  use ExUnit.Case, async: true

  defmodule FakeTemplate do
    use Swoosh.Template, root: Path.join(__DIR__, "../support/fixtures/templates")

    def render() do
      render_template("template", %{ subject: "world" })
    end
  end

  describe "render/2" do
    test "returns a compiled template" do
      assert FakeTemplate.render() == "Hello, world!\n"
    end
  end
end
