defmodule Swoosh.ConnParser do
  def parse(conn, opts \\ []) do
    opts =
      opts
      |> Keyword.put_new(:parsers, [
        Plug.Parsers.URLENCODED,
        Plug.Parsers.RFC822,
        Plug.Parsers.JSON,
        Plug.Parsers.MULTIPART
      ])
      |> Keyword.put_new(:json_decoder, Swoosh.json_library())
      |> Keyword.put_new(:pass, ["message/rfc822", "text/plain"])
      |> Keyword.put_new(:body_reader, {GZipBodyReader, :read_body, []})

    Plug.Parsers.call(conn, Plug.Parsers.init(opts))
  end
end
