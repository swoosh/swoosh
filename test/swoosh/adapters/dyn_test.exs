defmodule Swoosh.Adapters.DynTest do
  use Swoosh.AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.DeliveryError
  alias Swoosh.Adapters.Dyn

  @success_response """
    {
      "response": {
        "status": 200,
        "message": "OK",
        "data": "250 2.1.5 Ok"
      }
    }
    """

  setup do
    bypass = Bypass.open
    config = [base_url: "http://localhost:#{bypass.port}",
              api_key: "fake"]

    valid_email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")

    {:ok, bypass: bypass, valid_email: valid_email, config: config}
  end

  test "a sent email results in :ok", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      expected_path = "/rest/json/send"
      body_params = %{
        "apikey" => "fake",
        "bodyhtml" => "<h1>Hello</h1>",
        "from" => "\"T Stark\" <tony.stark@example.com>",
        "subject" => "Hello, Avengers!",
        "to" => "\"Steve Rogers\" <steve.rogers@example.com>"
      }
      assert body_params == conn.body_params
      assert expected_path == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end

    assert Dyn.deliver(email, config) == {:ok, "OK"}
  end

  test "an email with attachments results in DeliveryError", %{config: config, valid_email: email} do
    email_with_attachments = email
    |> attachment("README.md")
    assert_raise DeliveryError, fn ->
      Dyn.deliver(email_with_attachments, config)
    end
  end

  test "deliver/1 with all fields returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> to("wasp.avengers@example.com")
      |> bcc([{"Clinton Francis Barton", "hawk.eye@example.com"}, {"", "beast.avengers@example.com"}])
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")

    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      body_params = %{
        "apikey" => "fake",
        "bcc" => %{
          "1" => "\"Clinton Francis Barton\" <hawk.eye@example.com>",
          "2" => "beast.avengers@example.com"
        },
        "bodyhtml" => "<h1>Hello</h1>",
        "bodytext" => "Hello",
        "from" => "\"T Stark\" <tony.stark@example.com>",
        "subject" => "Hello, Avengers!",
        "to" => "wasp.avengers@example.com, \"Steve Rogers\" <steve.rogers@example.com>"
      }

      assert body_params == conn.body_params

      Plug.Conn.resp(conn, 200, @success_response)
    end

    assert Dyn.deliver(email, config) == {:ok, "OK"}
  end

  test "deliver/1 with 4xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect bypass, fn conn ->
      Plug.Conn.resp(conn, 404, "Not Found")
    end

    assert Dyn.deliver(email, config) == {:error, "Not found"}
  end

  test "deliver/1 with 503 response", %{bypass: bypass, valid_email: email, config: config} do
    Bypass.expect bypass, fn conn ->
      Plug.Conn.resp(conn, 503, "Service Unavailable")
    end

    assert Dyn.deliver(email, config) == {:error, "Service Unavailable"}
  end

  test "deliver/1 with 500 response", %{bypass: bypass, valid_email: email, config: config} do
    Bypass.expect bypass, fn conn ->
      Plug.Conn.resp(conn, 500, "{\"message\": \"error\"}")
    end
    assert Dyn.deliver(email, config) == {:error, "Error: \"{\\\"message\\\": \\\"error\\\"}\""}
  end

  test "validate_config/1 with valid config", %{config: config} do
    assert Dyn.validate_config(config) == :ok
  end

  test "validate_config/1 with invalid config" do
    assert_raise ArgumentError, """
    expected [:api_key] to be set, got: []
    """, fn ->
      Dyn.validate_config([])
    end
  end
end
