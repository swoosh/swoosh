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

  describe "render_to_html/3" do
    test "renders template as `html_body`" do
      email =
        Swoosh.Email.new()
        |> FakeTemplate.render_to_html("template_1")

      %{ html_body: "Hello, world!\n" } = email
    end

    test "renders template with assigned variables" do
      email =
        Swoosh.Email.new()
        |> Swoosh.Email.assign(:subject, "world")
        |> FakeTemplate.render_to_html("template_2")

      %{ html_body: "Hello, world!\n" } = email
    end

    test "renders template with passed in variables" do
      email =
        Swoosh.Email.new()
        |> Swoosh.Email.assign(:subject, "me")
        |> FakeTemplate.render_to_html("template_2", %{ subject: "world" })

      %{ html_body: "Hello, world!\n" } = email
    end
  end

  describe "render_to_text/3" do
    test "renders template as `text_body`" do
      email =
        Swoosh.Email.new()
        |> FakeTemplate.render_to_text("template_1")

      %{ text_body: "Hello, world!\n" } = email
    end

    test "renders template with assigned variables" do
      email =
        Swoosh.Email.new()
        |> Swoosh.Email.assign(:subject, "world")
        |> FakeTemplate.render_to_text("template_2")

      %{ text_body: "Hello, world!\n" } = email
    end

    test "renders template with passed in variables" do
      email =
        Swoosh.Email.new()
        |> Swoosh.Email.assign(:subject, "me")
        |> FakeTemplate.render_to_text("template_2", %{ subject: "world" })

      %{ text_body: "Hello, world!\n" } = email
    end
  end
end
