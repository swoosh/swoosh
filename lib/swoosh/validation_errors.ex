defmodule Swoosh.Validation.MissingDepsError do
  defexception adapter: nil, deps: nil

  def message(%{adapter: adapter, deps: deps}) do
    deps =
      deps
      |> Enum.map(fn
        {lib, module} -> "#{module} from #{inspect(lib)}"
        module -> inspect(module)
      end)
      |> Enum.map(&"\n- #{&1}")

    """
    The following dependencies are required to use #{inspect(adapter)}:
    #{deps}
    """
  end
end

defmodule Swoosh.Validation.MissingAdapterError do
  defexception adapter: nil

  def message(%{adapter: adapter}) do
    "#{adapter} does not exist"
  end
end
