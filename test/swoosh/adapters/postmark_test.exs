defmodule Swoosh.Adapters.PostmarkTest do
  use AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.Postmark

  @success_response """
    {
      "ErrorCode": 0,
      "Message": "OK",
      "MessageID": "b7bc2f4a-e38e-4336-af7d-e6c392c2f817",
      "SubmittedAt": "2010-11-26T12:01:05.1794748-05:00",
      "To": "tony@stark.com"
    }
  """

  setup_all do
    bypass = Bypass.open
    config = [base_url: "http://localhost:#{bypass.port}",
              api_key: "jarvis"]

    valid_email =
      new
      |> from("steve@rogers.com")
      |> to("tony@stark.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")

    {:ok, bypass: bypass, valid_email: valid_email, config: config}
  end

  test "a sent email results in :ok", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      body_params = %{"Subject" => "Hello, Avengers!",
                      "To" => "tony@stark.com",
                      "From" => "steve@rogers.com",
                      "HtmlBody" => "<h1>Hello</h1>"}
      assert body_params == conn.body_params
      assert "/email" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end

    assert Postmark.deliver(email, config) == {:ok, %{id: "b7bc2f4a-e38e-4336-af7d-e6c392c2f817"}}
  end

  test "delivery/1 with all fields returns :ok", %{bypass: bypass, config: config} do
    email =
      new
      |> from({"T Stark", "tony@stark.com"})
      |> to("wasp@avengers.com")
      |> to({"Steve Rogers", "steve@rogers.com"})
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> cc({"Bruce Banner", "hulk@smash.com"})
      |> cc("thor@odinson.com")
      |> bcc({"Clinton Francis Barton", "hawk@eye.com"})
      |> bcc("beast@avengers.com")
      |> reply_to("iron@stark.com")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")

    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      body_params = %{"Subject" => "Hello, Avengers!",
                      "To" => "\"Steve Rogers\" <steve@rogers.com>,wasp@avengers.com",
                      "From" => "tony@stark.com",
                      "Cc" => "thor@odinson.com,\"Bruce Banner\" <hulk@smash.com>",
                      "Bcc" => "beast@avengers.com,\"Clinton Francis Barton\" <hawk@eye.com>",
                      "ReplyTo" => "iron@stark.com",
                      "TextBody" => "Hello",
                      "HtmlBody" => "<h1>Hello</h1>"}

      assert body_params == conn.body_params
      assert "/email" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end

    assert Postmark.deliver(email, config) == {:ok, %{id: "b7bc2f4a-e38e-4336-af7d-e6c392c2f817"}}
  end

  test "delivery/1 with 4xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect bypass, fn conn ->
      Plug.Conn.resp(conn, 422, "{\"errors\":[\"The provided authorization grant is invalid, expired, or revoked\"], \"message\":\"error\"}")
    end

    assert Postmark.deliver(email, config) == {:error, {422, %{"errors" => ["The provided authorization grant is invalid, expired, or revoked"], "message" => "error"}}}
  end

  test "deliver/1 with 5xx response", %{bypass: bypass, valid_email: email, config: config} do
    Bypass.expect bypass, fn conn ->
      Plug.Conn.resp(conn, 500, "{\"errors\":[\"The provided authorization grant is invalid, expired, or revoked\"], \"message\":\"error\"}")
    end

    assert Postmark.deliver(email, config) == {:error, {500, %{"errors" => ["The provided authorization grant is invalid, expired, or revoked"], "message" => "error"}}}
  end

  test "validate_config/1 with valid config", %{config: config} do
    assert Postmark.validate_config(config) == :ok
  end

  test "validate_config/1 with invalid config" do
    assert_raise ArgumentError, """
    expected [:api_key] to be set, got: []
    """, fn ->
      Postmark.validate_config([])
    end
  end
end
