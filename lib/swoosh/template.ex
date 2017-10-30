defmodule Swoosh.Template do
  @default_engines [ eex: Swoosh.Template.EExEngine ]
  @default_pattern "*"

  defmacro __before_compile__(env) do
    root = Module.get_attribute(env.module, :swoosh_root)
    pattern = Module.get_attribute(env.module, :swoosh_pattern)

    codes =
      for path <- find_all(root, pattern) do
        compile(path, root)
      end

    quote do
      unquote(codes)

      def render(template), do: render(template, %{})
    end
  end

  defmacro __using__(opts) do
    quote bind_quoted: [ opts: opts ], unquote: true do
      root = Keyword.fetch!(opts, :root)

      @swoosh_root Path.relative_to_cwd(root)
      @swoosh_pattern Keyword.get(opts, :pattern, unquote(@default_pattern))

      @before_compile unquote(__MODULE__)
    end
  end

  @doc """
  Returns a keyword list of all template engines identified by their extensions.
  """
  @spec engines() :: %{ atom => module }
  def engines() do
    @default_engines
    |> Keyword.merge(Application.get_env(:swoosh, :template_engines, []))
    |> Enum.into(%{})
  end

  @doc """
  Returns all template paths in a given template root.
  """
  @spec find_all(binary, binary) :: binary
  def find_all(root, pattern \\ @default_pattern) do
    root
    |> Path.join(pattern <> ".#{extensions_pattern()}")
    |> Path.wildcard()
  end

  @doc """
  Converts the template path into the template name.

  ## Examples

      iex> Swoosh.Template.template_path_to_name(
      ...>   "lib/templates/users/welcome.html.eex",
      ...>   "lib/templates")
      "users/welcome.html"
  """
  @spec template_path_to_name(binary, binary) :: binary
  def template_path_to_name(path, root) do
    path
    |> Path.rootname()
    |> Path.relative_to(root)
  end

  defp compile(path, root) do
    engine = engine_for(path)
    name = template_path_to_name(path, root)
    quoted = engine.compile(path)

    quote do
      def render(unquote(name), var!(assigns)) do
        _ = var!(assigns)

        unquote(quoted)
      end
    end
  end

  defp engine_for(path) do
    engines()
    |> Map.fetch!(extension(path))
  end

  defp extension(path) do
    path
    |> Path.extname()
    |> String.trim_leading(".")
    |> String.to_atom()
  end

  defp extensions_pattern() do
    engines()
    |> Map.keys()
    |> Enum.join(",")
  end
end
