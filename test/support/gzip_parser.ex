defmodule Plug.Parsers.Gzip do
  @moduledoc """
  Local fork of https://github.com/DefactoSoftware/xml_parser
  with some mods
  """
  alias Hex.API.Key
  @behaviour Plug.Parsers

  def init(opts) do
    json_decoder = Keyword.get(opts, :json_decoder)
    {:ok, opts, json_decoder}
  end

  def parse(conn, _type, _subtype, _headers, {:ok, opts, json_decoder}) do
    case get_content_encoding(conn) do
      "gzip" ->
        body = :zlib.gunzip(body)

        case json_decoder do
          {:ok, json} ->
            {:ok, json, conn}

          {:error, _reason} ->
            {:error, :unprocessable_entity, conn}
        end

      _ ->
        {:next, conn}
    end
  end

  # Helper to get the `Content-Encoding` header
  defp get_content_encoding(conn) do
    conn
    |> Plug.Conn.get_req_header("content-encoding")
    |> List.first()
    |> String.downcase()
  end
end
