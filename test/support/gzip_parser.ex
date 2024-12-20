defmodule Plug.Parsers.GZIP do
  @behaviour Plug.Parsers

  @impl true
  def init(opts), do: opts

  @impl true
  def parse(conn, "application", "json", _headers, opts) do
    json_decoder = Keyword.get(opts, :json_decoder)

    case get_content_encoding(conn) do
      "gzip" ->
        {:ok, compressed_body, conn} = Plug.Conn.read_body(conn)
        uncompressed_body = :zlib.gunzip(compressed_body)

        case json_decoder.decode(uncompressed_body) do
          {:ok, json} ->
            {:ok, json, conn}

          {:error, _} ->
            {:error, :unprocessable_entity, conn}
        end

      _ ->
        {:next, conn}
    end
  end

  @impl true
  def parse(conn, _type, _subtype, _headers, _opts) do
    {:next, conn}
  end

  # Helper to get the `Content-Encoding` header
  defp get_content_encoding(conn) do
    conn
    |> Plug.Conn.get_req_header("content-encoding")
    |> List.first("")
    |> String.downcase()
  end
end
