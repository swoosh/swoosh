defmodule Plug.Parsers.GZIP do
  @behaviour Plug.Parsers

  @impl true
  def init(opts) do
    opts
  end

  @impl true
  def parse(%Plug.Conn{} = conn, "application", "json", %{}, opts) do
    json_decoder = Keyword.get(opts, :json_decoder)
    {:ok, compressed_body, conn} = Plug.Conn.read_body(conn, opts)

    body = :zlib.gunzip(compressed_body)

    case json_decoder.decode(body) do
      {:ok, json} ->
        {:ok, json, conn}

      {:error, _reason} ->
        {:error, :unprocessable_entity, conn}
    end
  end

  @impl true
  def parse(conn, _type, _subtype, _headers, _opts) do
    {:next, conn}
  end
end
