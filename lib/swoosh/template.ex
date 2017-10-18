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

      def render(template, assigns) do
        render_template(template, assigns)
      end
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

  def engines() do
    @default_engines |> Enum.into(%{})
  end

  def find_all(root, pattern \\ @default_pattern) do
    root
    |> Path.join(pattern <> ".#{extensions_pattern()}")
    |> Path.wildcard()
  end

  defp compile(path, root) do
    engine = engine_for(path)
    name = path |> Path.rootname() |> Path.relative_to(root)
    quoted = engine.compile(path)

    defp = String.to_atom(name)

    quote do
      defp unquote(defp)(var!(assigns)) do
        unquote(quoted)
      end

      defp render_template(unquote(name), assigns) do
        unquote(defp)(assigns)
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
