defmodule Swoosh.Adapters.PostUpTest do
  use Swoosh.AdapterCase, async: true
  import Swoosh.Email
  alias Swoosh.Adapters.PostUp

  setup do
    bypass = Bypass.open()

    config = [
      base_url: "http://localhost:#{bypass.port}",
      username: "testuser",
      password: "testpassword321%"
    ]

    valid_email =
      new()
      |> from({"Test", "test@example.com"})
      |> to({"CustomTag=foo;AnotherTag=bar", "recipient@example.com"})
      |> subject("Test Email from PostUp")
      |> put_provider_option(:send_template_id, 42)
      |> text_body("Hey, is this thing on?")
      |> html_body("<h1>Hello!</h1>")

    {:ok, bypass: bypass, config: config, valid_email: valid_email}
  end

  test "successful delivery returns :ok", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "SendTemplateId" => 42,
        "content" => %{
          "fromEmail" => "test@example.com",
          "fromName" => "Test",
          "htmlBody" => "<h1>Hello!</h1>",
          "subject" => "Test Email from PostUp",
          "textBody" => "Hey, is this thing on?"
        },
        "recipients" => [
          %{"address" => "recipient@example.com", "tags" => ["CustomTag=foo", "AnotherTag=bar"]}
        ]
      }

      assert body_params == conn.body_params
      assert "/templatemailing" == conn.request_path
      assert "POST" == conn.method
      assert body_params == conn.body_params

      Plug.Conn.resp(conn, 200, "{\"status\":\"DONE\"}")
    end)

    assert PostUp.deliver(email, config) == {:ok, %{"status" => "DONE"}}
  end

  test "deliver/1 with multiple recipients returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from({"Test", "test@example.com"})
      |> to("no.custom.tags@example.com")
      |> to({"CustomTag=foo;AnotherTag=bar", "recipient@example.com"})
      |> subject("Test Email from PostUp")
      |> put_provider_option(:send_template_id, 42)
      |> text_body("Hey, is this thing on?")
      |> html_body("<h1>Hello!</h1>")

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "SendTemplateId" => 42,
        "content" => %{
          "fromEmail" => "test@example.com",
          "fromName" => "Test",
          "htmlBody" => "<h1>Hello!</h1>",
          "subject" => "Test Email from PostUp",
          "textBody" => "Hey, is this thing on?"
        },
        "recipients" => [
          %{"address" => "recipient@example.com", "tags" => ["CustomTag=foo", "AnotherTag=bar"]},
          %{"address" => "no.custom.tags@example.com", "tags" => []}
        ]
      }

      assert body_params == conn.body_params
      assert "/templatemailing" == conn.request_path
      assert "POST" == conn.method
      assert body_params == conn.body_params

      Plug.Conn.resp(conn, 200, "{\"status\":\"DONE\"}")
    end)

    assert PostUp.deliver(email, config) == {:ok, %{"status" => "DONE"}}
  end

  test "deliver/1 with additional provider options returns :ok", %{bypass: bypass, config: config} do
    email =
      new()
      |> from("IGNORE")
      |> to("recipient@example.com")
      |> put_provider_option(:send_template_id, 42)
      |> put_provider_option(:header_content_id, 123)
      |> put_provider_option(:footer_content_id, 314)
      |> put_provider_option(:unsub_content_id, 248)
      |> put_provider_option(:forward_to_friend_content_id, 963)

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "SendTemplateId" => 42,
        "content" => %{
          "footerContentId" => 314,
          "forwardToFriendContentId" => 963,
          "headerContentId" => 123,
          "unsubContentId" => 248
        },
        "recipients" => [%{"address" => "recipient@example.com", "tags" => []}]
      }

      assert body_params == conn.body_params
      assert "/templatemailing" == conn.request_path
      assert "POST" == conn.method
      assert body_params == conn.body_params

      Plug.Conn.resp(conn, 200, "{\"status\":\"DONE\"}")
    end)

    assert PostUp.deliver(email, config) == {:ok, %{"status" => "DONE"}}
  end

  test ~s(deliver/1 with no from or "context" field returns :ok), %{
    bypass: bypass,
    config: config
  } do
    email =
      new()
      |> from("SKIP")
      |> to("anotherone@example.com")
      |> to("recipient@example.com")
      |> put_provider_option(:send_template_id, 42)

    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "SendTemplateId" => 42,
        "recipients" => [
          %{"address" => "recipient@example.com", "tags" => []},
          %{"address" => "anotherone@example.com", "tags" => []}
        ]
      }

      assert body_params == conn.body_params
      assert "/templatemailing" == conn.request_path
      assert "POST" == conn.method
      assert body_params == conn.body_params

      Plug.Conn.resp(conn, 200, "{\"status\":\"DONE\"}")
    end)

    assert PostUp.deliver(email, config) == {:ok, %{"status" => "DONE"}}
  end

  test "deliver/1 with 5xx response", %{bypass: bypass, config: config, valid_email: email} do
    Bypass.expect(bypass, fn conn ->
      assert "/templatemailing" == conn.request_path
      assert "POST" == conn.method
      Plug.Conn.resp(conn, 500, "Server error")
    end)

    assert PostUp.deliver(email, config) == {:error, {500, "Server error"}}
  end

  test "validate_config/1 with valid config", %{config: config} do
    assert PostUp.validate_config(config) == :ok
  end

  test "validate_config/1 with missing username and password" do
    assert_raise ArgumentError, "expected [:password, :username] to be set, got: []\n", fn ->
      PostUp.validate_config([])
    end
  end

  test "validate_config/1 with missing password" do
    assert_raise ArgumentError,
                 ~s(expected [:password] to be set, got: [username: "test"]\n),
                 fn ->
                   PostUp.validate_config(username: "test")
                 end
  end

  test "validate_config/1 with missing username" do
    assert_raise ArgumentError,
                 ~s(expected [:username] to be set, got: [password: "testpassword"]\n),
                 fn ->
                   PostUp.validate_config(password: "testpassword")
                 end
  end
end
