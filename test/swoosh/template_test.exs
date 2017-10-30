defmodule Swoosh.TemplateTest do
  use ExUnit.Case, async: true

  defmodule FakeTemplate do
    use Swoosh.Template, root: Path.join(__DIR__, "../support/fixtures/templates")
  end

  describe "render/1" do
    test "renders template" do
      assert FakeTemplate.render("template_1") == "Hello, world!\n"
    end
  end

  describe "render/2" do
    test "renders template" do
      assert FakeTemplate.render("template_2", %{ subject: "world" }) == "Hello, world!\n"
    end
  end
end
