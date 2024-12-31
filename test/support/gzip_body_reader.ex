defmodule GZipBodyReader do
  def read_body(conn, _opts) do
    {:ok, body, conn} = Plug.Conn.read_body(conn)

    case get_content_encoding(conn) do
      "gzip" ->
        uncompressed_body = :zlib.gunzip(body)
        conn = put_in(conn.assigns[:raw_body], [uncompressed_body])
        {:ok, uncompressed_body, conn}

      _ ->
        {:ok, body, conn}
    end
  end

  defp get_content_encoding(conn) do
    conn
    |> Plug.Conn.get_req_header("content-encoding")
    |> List.first("")
    |> String.downcase()
  end
end
