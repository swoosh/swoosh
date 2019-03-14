defmodule Swoosh.ApiClientTest do
  use ExUnit.Case, async: true

  alias Swoosh.{ApiClient, Email}
  import Swoosh.ConnParser

  setup do
    {:ok, bypass: Bypass.open()}
  end

  test "ApiClient sends post request with hackney_options", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      expected_path = "/test"
      body_params = %{"hello" => "world"}

      assert body_params == conn.body_params
      assert {"cookie", "a=b"} in conn.req_headers
      assert expected_path == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, "OK")
    end)

    assert {:ok, 200, _headers, "OK" = _body} =
             ApiClient.post(
               "http://localhost:#{bypass.port}/test",
               [{"Content-Type", "application/json"}],
               Swoosh.json_library().encode!(%{hello: :world}),
               %Email{private: %{hackney_options: [cookie: "a=b"]}}
             )
  end

  test "ApiClient sends requests with swoosh user agent", %{bypass: bypass} do
    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      assert {"user-agent", "swoosh/#{Swoosh.version()}"} in conn.req_headers
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, "OK")
    end)

    assert {:ok, 200, _headers, "OK" = _body} =
             ApiClient.post(
               "http://localhost:#{bypass.port}/test",
               [{"Content-Type", "application/json"}],
               "{}",
               %Email{}
             )
  end
end
