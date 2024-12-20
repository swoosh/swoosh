defmodule Plug.Parsers.Gzip do
  @moduledoc """
  Local fork of https://github.com/DefactoSoftware/xml_parser
  with some mods
  """
  @behaviour Plug.Parsers

  @impl true
  def init(opts) do
    json_decoder = Keyword.get(opts, :json_decoder)

    json_decoder
  end

  @impl true
  def parse(conn, _type, _subtype, _headers, json_decoder) when not is_nil(json_decoder) do
    case get_content_encoding(conn) do
      "gzip" ->
        body = :zlib.gunzip(conn.body_params)

        case json_decoder.decode(body) do
          {:ok, json} ->
            {:ok, json, conn}

          {:error, _reason} ->
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
    |> List.first()
    |> String.downcase()
  end
end
