defmodule Swoosh.Adapters.MailgunTest do
  use AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.Mailgun

  @success_response """
    {
      "message": "Queued. Thank you.",
      "id": "<20111114174239.25659.5817@samples.mailgun.org>"
    }
  """

  setup_all do
    bypass = Bypass.open
    config = [base_url: "http://localhost:#{bypass.port}",
              api_key: "fake",
              domain: "avengers.com"]

    valid_email =
      new
      |> from("tony@stark.com")
      |> to("steve@rogers.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")

    {:ok, bypass: bypass, valid_email: valid_email, config: config}
  end

  test "a sent email results in :ok", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      expected_path = "/" <> config[:domain] <> "/messages"
      body_params = %{"subject" => "Hello, Avengers!",
                      "to" => "steve@rogers.com",
                      "from" => "tony@stark.com",
                      "html" => "<h1>Hello</h1>"}
      assert body_params == conn.body_params
      assert expected_path == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end

    assert Mailgun.deliver(email, config) == {:ok, %{id: "<20111114174239.25659.5817@samples.mailgun.org>"}}
  end

  test "delivery/1 with all fields returns :ok", %{bypass: bypass, config: config} do
    email =
      new
      |> from({"T Stark", "tony@stark.com"})
      |> to({"Steve Rogers", "steve@rogers.com"})
      |> to("wasp@avengers.com")
      |> reply_to("office@avengers.com")
      |> cc({"Bruce Banner", "hulk@smash.com"})
      |> cc("thor@odinson.com")
      |> bcc({"Clinton Francis Barton", "hawk@eye.com"})
      |> bcc("beast@avengers.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")

    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      expected_path = "/" <> config[:domain] <> "/messages"
      body_params = %{"subject" => "Hello, Avengers!",
                      "to" => "wasp@avengers.com,Steve Rogers <steve@rogers.com>",
                      "bcc" => "beast@avengers.com,Clinton Francis Barton <hawk@eye.com>",
                      "cc" => "thor@odinson.com,Bruce Banner <hulk@smash.com>",
                      "h:Reply-To" => "office@avengers.com",
                      "from" => "T Stark <tony@stark.com>",
                      "text" => "Hello",
                      "html" => "<h1>Hello</h1>"}
      assert body_params == conn.body_params
      assert expected_path == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end

    assert Mailgun.deliver(email, config) == {:ok, %{id: "<20111114174239.25659.5817@samples.mailgun.org>"}}
  end

  test "delivery/1 with 4xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect bypass, fn conn ->
      Plug.Conn.resp(conn, 401, "{\"errors\":[\"The provided authorization grant is invalid, expired, or revoked\"], \"message\":\"error\"}")
    end

    assert Mailgun.deliver(email, config) == {:error, %{"errors" => ["The provided authorization grant is invalid, expired, or revoked"], "message" => "error"}}
  end

  test "deliver/1 with 5xx response", %{bypass: bypass, valid_email: email, config: config} do
    Bypass.expect bypass, fn conn ->
      Plug.Conn.resp(conn, 500, "{\"errors\":[\"The provided authorization grant is invalid, expired, or revoked\"], \"message\":\"error\"}")
    end

    assert Mailgun.deliver(email, config) == {:error, %{"errors" => ["The provided authorization grant is invalid, expired, or revoked"], "message" => "error"}}
  end

  test "validate_config/1 with valid config", %{config: config} do
    assert Mailgun.validate_config(config) == :ok
  end

  test "validate_config/1 with invalid config" do
    assert_raise ArgumentError, """
    expected [:domain, :api_key] to be set, got: []
    """, fn ->
      Mailgun.validate_config([])
    end
  end
end
