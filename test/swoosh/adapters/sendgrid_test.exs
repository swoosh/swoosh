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
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")

    {:ok, bypass: bypass, config: config, valid_email: valid_email}
  end

  test "successful delivery returns :ok", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      body_params = %{"from" => "{\"email\":\"tony.stark@example.com\"}",
                      "to" => "[{\"email\":\"steve.rogers@example.com\"}]",
                      "content" => "[{\"text/html\":\"<h1>Hello</h1>\",\"text/plain\":\"Hello\"}]",
                      "subject" => "Hello, Avengers!"}
      assert body_params == conn.body_params
      assert "/mail.send" == conn.request_path
      assert "POST" == conn.method
      Plug.Conn.resp(conn, 200, "{\"message\":\"success\"}")
    end
    assert Sendgrid.deliver(email, config) == {:ok, %{}}
  end

  test "delivery/1 with all fields returns :ok", %{bypass: bypass, config: config} do
    email =
      new
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> reply_to("hulk.smash@example.com")
      |> cc("hulk.smash@example.com")
      |> cc({"Janet Pym", "wasp.avengers@example.com"})
      |> bcc("thor.odinson@example.com")
      |> bcc({"Henry McCoy", "beast.avengers@example.com"})
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")

    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      body_params = %{"from" => "{\"name\":\"T Stark\",\"email\":\"tony.stark@example.com\"}",
                      "to" => "[{\"name\":\"Steve Rogers\",\"email\":\"steve.rogers@example.com\"}]",
                      "reply_to" => "{\"email\":\"hulk.smash@example.com\"}",
                      "cc" => "[{\"name\":\"Janet Pym\",\"email\":\"wasp.avengers@example.com\"},{\"email\":\"hulk.smash@example.com\"}]",
                      "bcc" => "[{\"name\":\"Henry McCoy\",\"email\":\"beast.avengers@example.com\"},{\"email\":\"thor.odinson@example.com\"}]",
                      "content" => "[{\"text/html\":\"<h1>Hello</h1>\",\"text/plain\":\"Hello\"}]",
                      "subject" => "Hello, Avengers!"}
      assert body_params == conn.body_params
      assert "/mail.send" == conn.request_path
      assert "POST" == conn.method
      Plug.Conn.resp(conn, 200, "{\"message\":\"success\"}")
    end
    assert Sendgrid.deliver(email, config) == {:ok, %{}}
  end

  test "delivery/1 with custom variables returns :ok", %{bypass: bypass, config: config} do
    email =
      new
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> reply_to("hulk.smash@example.com")
      |> cc("hulk.smash@example.com")
      |> cc({"Janet Pym", "wasp.avengers@example.com"})
      |> bcc("thor.odinson@example.com")
      |> bcc({"Henry McCoy", "beast.avengers@example.com"})
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")
      |> put_provider_option(:custom_args, %{my_var: %{"my_message_id": 123}, my_other_var: %{"my_other_id": 1, "stuff": 2}})

    Bypass.expect bypass, fn conn ->
      conn = parse(conn)
      body_params = %{"from" => "{\"name\":\"T Stark\",\"email\":\"tony.stark@example.com\"}",
                      "to" => "[{\"name\":\"Steve Rogers\",\"email\":\"steve.rogers@example.com\"}]",
                      "reply_to" => "{\"email\":\"hulk.smash@example.com\"}",
                      "cc" => "[{\"name\":\"Janet Pym\",\"email\":\"wasp.avengers@example.com\"},{\"email\":\"hulk.smash@example.com\"}]",
                      "bcc" => "[{\"name\":\"Henry McCoy\",\"email\":\"beast.avengers@example.com\"},{\"email\":\"thor.odinson@example.com\"}]",
                      "content" => "[{\"text/html\":\"<h1>Hello</h1>\",\"text/plain\":\"Hello\"}]",
                      "subject" => "Hello, Avengers!",
                      "custom_args" => "{\"my_var\":{\"my_message_id\":123},\"my_other_var\":{\"stuff\":2,\"my_other_id\":1}}"
                    }
      assert body_params == conn.body_params
      assert "/mail.send" == conn.request_path
      assert "POST" == conn.method
      Plug.Conn.resp(conn, 200, "{\"message\":\"success\"}")
    end
    assert Sendgrid.deliver(email, config) == {:ok, %{}}
  end

  test "delivery/1 with 4xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect bypass, fn conn ->
      assert "/mail.send" == conn.request_path
      assert "POST" == conn.method
      Plug.Conn.resp(conn, 401, @error_response_401)
    end
    assert Sendgrid.deliver(email, config) ==
      {:error, {401, %{"errors" => ["The provided authorization grant is invalid, expired."], "message" => "error"}}}
  end

  test "delivery/1 with 5xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect bypass, fn conn ->
      assert "/mail.send" == conn.request_path
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
