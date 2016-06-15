defmodule Swoosh.Adapters.MandrillTest do
  use AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.Mandrill

  @success_response """
    [
      {
        "email": "steve@rogers.com",
        "status": "sent",
        "_id": "9",
        "reject_reason" :null
      }
    ]
  """

  @queued_response """
    [
      {
        "email": "steve@rogers.com",
        "status": "queued",
        "_id": "9",
        "reject_reason": null
      }
    ]
  """

  setup_all do
    bypass = Bypass.open
    config = [base_url: "http://localhost:#{bypass.port}",
              api_key: "jarvis"]

    valid_email =
      new
      |> from({"T Stark", "tony@stark.com"})
      |> to("steve@rogers.com")
      |> cc({"Bruce Banner", "hulk@smash.com"})
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")

    {:ok, bypass: bypass, config: config, valid_email: valid_email}
  end

  test "a sent email results in :ok", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      body_params = %{"key" => "jarvis",
                      "message" => %{
                        "subject" => "Hello, Avengers!",
                        "to" => [%{"type" => "cc", "email" => "hulk@smash.com", "name" => "Bruce Banner"},
                                 %{"type" => "to", "email" => "steve@rogers.com"}],
                        "from_name" => "T Stark",
                        "from_email" => "tony@stark.com",
                        "html" => "<h1>Hello</h1>"}}
      assert body_params == conn.body_params
      assert "/messages/send.json" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end

    assert Mandrill.deliver(email, config) == {:ok, %{id: "9"}}
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
      body_params = %{"key" => "jarvis",
                      "message" => %{
                        "subject" => "Hello, Avengers!",
                        "headers" => %{"Reply-To" => "office@avengers.com"},
                        "to" => [%{"type" => "bcc", "email" => "beast@avengers.com"},
                                 %{"type" => "bcc", "email" => "hawk@eye.com", "name" => "Clinton Francis Barton"},
                                 %{"type" => "cc", "email" => "thor@odinson.com"},
                                 %{"type" => "cc", "email" => "hulk@smash.com", "name" => "Bruce Banner"},
                                 %{"type" => "to", "email" => "wasp@avengers.com"},
                                 %{"type" => "to", "email" => "steve@rogers.com", "name" => "Steve Rogers"}],
                        "from_name" => "T Stark",
                        "from_email" => "tony@stark.com",
                        "html" => "<h1>Hello</h1>",
                        "text" => "Hello"}}
      assert body_params == conn.body_params
      assert "/messages/send.json" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end

    assert Mandrill.deliver(email, config) == {:ok, %{id: "9"}}
  end

  test "a queued email results in :ok", %{bypass: bypass, config: config, valid_email: email} do
    email = put_provider_option(email, :async, true)
    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      assert true == conn.body_params["async"]
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @queued_response)
    end

    assert Mandrill.deliver(email, config) == {:ok, %{id: "9"}}
  end

  test "deliver/1 with 2xx response containing errors", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect bypass, fn conn ->
      Plug.Conn.resp(conn, 200, "[{\"email\":\"leafybasil@gmail.com\",\"status\":\"rejected\",\"_id\":\"e1f1f16d3c6e47c5955ad2b4c3207986\",\"reject_reason\":\"unsigned\"}]")
    end

    assert Mandrill.deliver(email, config) == {:error, %{"_id" => "e1f1f16d3c6e47c5955ad2b4c3207986", "email" => "leafybasil@gmail.com", "reject_reason" => "unsigned", "status" => "rejected"}}
  end

  test "deliver/1 with non 2xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect bypass, fn conn ->
      Plug.Conn.resp(conn, 500, "{\"status\":\"error\",\"code\":-1,\"name\":\"Invalid_Key\",\"message\":\"Invalid API key\"}")
    end

    assert Mandrill.deliver(email, config) == {:error, {500, %{"code" => -1, "message" => "Invalid API key", "name" => "Invalid_Key", "status" => "error"}}}
  end

  test "validate_config/1 with valid config", %{config: config} do
    assert Mandrill.validate_config(config) == :ok
  end

  test "validate_config/1 with invalid config" do
    assert_raise ArgumentError, """
    expected [:api_key] to be set, got: []
    """, fn ->
      Mandrill.validate_config([])
    end
  end
end
