defmodule Swoosh.ConnParser do
  def parse(conn, opts \\ []) do
    case get_content_encoding(conn) do
      "gzip" ->
        opts = [parsers: [Plug.Parsers.Gzip], json_decoder: Swoosh.json_library()]
        Plug.Parsers.call(conn, Plug.Parsers.init(opts))

      _ ->
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

        Plug.Parsers.call(conn, Plug.Parsers.init(opts))
    end
  end

  # Helper to get the `Content-Encoding` header
  defp get_content_encoding(conn) do
    conn
    |> Plug.Conn.get_req_header("content-encoding")
    |> List.first("")
    |> String.downcase()
  end
end
