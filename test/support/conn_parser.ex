defmodule Swoosh.ConnParser do
  def parse(conn, opts \\ []) do
    opts =
      opts
      |> Keyword.put_new(:parsers, [Plug.Parsers.URLENCODED, Plug.Parsers.JSON])
      |> Keyword.put_new(:json_decoder, Swoosh.json_library())

    Plug.Parsers.call(conn, Plug.Parsers.init(opts))
  end
end
