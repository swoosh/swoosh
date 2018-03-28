defmodule Swoosh.View do
  defmacro __using__(opts) do
    quote do
      use Swoosh.Template, unquote(opts)

      import Swoosh.View
    end
  end

  @doc """
  Renders a template.

  It expects the view module, the template as a string, and a
  set of assigns.

  ## Examples

      Swoosh.View.render(YourApp.EmailView, "index.html", name: "John Doe")
      #=> "Hello John Doe"

  ## Assigns

  Assigns are meant to be user data that will be available in templates.
  However, there are keys under assigns that are specially handled by
  Swoosh, they are:

    * `:layout` - tells Swoosh to wrap the rendered result in the
      given layout. See next section.

  The following assigns are reserved, and cannot be set directly:

    * `@view_module` - The view module being rendered
    * `@view_template` - The `@view_module`'s template being rendered

  ## Layouts

  Templates can be rendered within other templates using the `:layout`
  option. `:layout` accepts a tuple of the form
  `{LayoutModule, "template.extension"}`.

  To render the template within the layout, simply call `render/3`
  using the `@view_module` and `@view_template` assign:

      <%= render @view_module, @view_template, assigns %>
  """
  def render(module, template, assigns) do
    assigns
    |> Enum.into(%{})
    |> Map.pop(:layout, false)
    |> render_within(module, template)
  end

  defp render_within({ { layout_mod, layout_tpl }, assigns }, inner_mod, inner_tpl) do
    assigns = Map.merge(assigns, %{ view_module: inner_mod, view_template: inner_tpl })

    layout_mod.render(layout_tpl, assigns)
  end

  defp render_within({ false, assigns }, module, template) do
    assigns = Map.merge(assigns, %{ view_module: module, view_template: template })

    module.render(template, assigns)
  end
end
