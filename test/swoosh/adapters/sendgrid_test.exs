defmodule Swoosh.Adapters.SendgridTest do
  use AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.Sendgrid

  @error_response_401 """
    {
      "errors": ["The provided authorization grant is invalid, expired."],
      "message": "error"
    }
  """

  @error_response_500 """
    {
      "errors": ["Internal server error"],
      "message": "error"
    }
  """

  setup_all do
    bypass = Bypass.open
    config = [api_key: "123", base_url: "http://localhost:#{bypass.port}"]

    valid_email =
      new
      |> from("tony@stark.com")
      |> to("steve@rogers.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")

    {:ok, bypass: bypass, config: config, valid_email: valid_email}
  end

  test "successful delivery returns :ok", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      body_params = %{"from" => "tony@stark.com",
                      "to" => ["steve@rogers.com"],
                      "html" => "<h1>Hello</h1>",
                      "subject" => "Hello, Avengers!",
                      "text" => "Hello"}
      assert body_params == conn.body_params
      assert "/mail.send.json" == conn.request_path
      assert "POST" == conn.method
      Plug.Conn.resp(conn, 200, "{\"message\":\"success\"}")
    end
    assert Sendgrid.deliver(email, config) == {:ok, %{}}
  end

  test "delivery/1 with all fields returns :ok", %{bypass: bypass, config: config} do
    email =
      new
      |> from({"T Stark", "tony@stark.com"})
      |> to({"Steve Rogers", "steve@rogers.com"})
      |> reply_to("hulk@smash.com")
      |> cc("hulk@smash.com")
      |> cc({"Janet Pym", "wasp@avengers.com"})
      |> bcc("thor@odinson.com")
      |> bcc({"Henry McCoy", "beast@avengers.com"})
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")

    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      body_params = %{"from" => "tony@stark.com",
                      "fromname" => "T Stark",
                      "to" => ["steve@rogers.com"],
                      "toname" => ["Steve Rogers"],
                      "replyto" => "hulk@smash.com",
                      "cc" => ["wasp@avengers.com", "hulk@smash.com"],
                      "ccname" => ["Janet Pym", ""],
                      "bcc" => ["beast@avengers.com", "thor@odinson.com"],
                      "bccname" => ["Henry McCoy", ""],
                      "html" => "<h1>Hello</h1>",
                      "subject" => "Hello, Avengers!",
                      "text" => "Hello"}
      assert body_params == conn.body_params
      assert "/mail.send.json" == conn.request_path
      assert "POST" == conn.method
      Plug.Conn.resp(conn, 200, "{\"message\":\"success\"}")
    end
    assert Sendgrid.deliver(email, config) == {:ok, %{}}
  end

  test "delivery/1 with 4xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect bypass, fn conn ->
      assert "/mail.send.json" == conn.request_path
      assert "POST" == conn.method
      Plug.Conn.resp(conn, 401, @error_response_401)
    end
    assert Sendgrid.deliver(email, config) ==
      {:error, {401, %{"errors" => ["The provided authorization grant is invalid, expired."], "message" => "error"}}}
  end

  test "delivery/1 with 5xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect bypass, fn conn ->
      assert "/mail.send.json" == conn.request_path
      assert "POST" == conn.method
      Plug.Conn.resp(conn, 500, @error_response_500)
    end
    assert Sendgrid.deliver(email, config) ==
      {:error, {500, %{"errors" => ["Internal server error"], "message" => "error"}}}
  end


  test "validate_config/1 with valid config", %{config: config} do
    assert Sendgrid.validate_config(config) == :ok
  end

  test "validate_config/1 with invalid config" do
    assert_raise ArgumentError, """
    expected [:api_key] to be set, got: []
    """, fn ->
      Sendgrid.validate_config([])
    end
  end
end
