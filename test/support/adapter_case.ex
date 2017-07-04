defmodule AdapterCase do
  @moduledoc "Conveniences for testing adapters."

  use ExUnit.CaseTemplate

  using do
    quote do
      import Swoosh.Email
      alias Swoosh.AdapterError

      defp parse(conn, opts \\ []) do
        opts =
          opts
          |> Keyword.put_new(:parsers, [Plug.Parsers.URLENCODED, Plug.Parsers.JSON])
          |> Keyword.put_new(:json_decoder, Poison)

        Plug.Parsers.call(conn, Plug.Parsers.init(opts))
      end
    end
  end
end
