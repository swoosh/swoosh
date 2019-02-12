defmodule Swoosh.AdapterCase do
  @moduledoc "Conveniences for testing adapters."

  use ExUnit.CaseTemplate

  using do
    quote do
      import Swoosh.ConnParser
    end
  end
end
