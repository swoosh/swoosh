defmodule Swoosh.Adapters.SMTP2GOTest do
  use Swoosh.AdapterCase, async: true

  import Swoosh.Email
  alias Swoosh.Adapters.SMTP2GO

  @firstname "John"
  @lastname "Smith"
  @subject "Hello, world!"
  @sender "sender@example.com"
  @receiver "receiver@example.com"
  @developer "developer@example.com"
  @template_id "template_id"
  @template_html_content "<h1>Hello, world!</h1>"
  @template_text_content "# Hello, world!"
  @success_response """
  {
    "data": {
      "email_id": "123456789"
    }
  }
  """
  @error_response """
  {
    "data": {
      "error":"error_message",
      "error_code":"E.Code"
    }
  }
  """

  setup do
    bypass = Bypass.open()

    config = [
      base_url: "http://localhost:#{bypass.port}",
      api_key: "api_key"
    ]

    valid_email =
      new()
      |> from(@sender)
      |> to(@receiver)
      |> subject(@subject)

    {:ok, bypass: bypass, valid_email: valid_email, config: config}
  end

  test "deliver/1 - valid email with html and text body",
       %{
         bypass: bypass,
         config: config,
         valid_email: email
       } do
    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "api_key" => "api_key",
        "custom_headers" => [],
        "html_body" => "<h1>Hello, world!</h1>",
        "sender" => "sender@example.com",
        "subject" => "Hello, world!",
        "text_body" => "# Hello, world!",
        "to" => ["receiver@example.com"]
      }

      assert body_params == conn.body_params
      assert "/email/send" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    email =
      email
      |> text_body(@template_text_content)
      |> html_body(@template_html_content)

    assert {:ok, %{id: "123456789"}} = SMTP2GO.deliver(email, config)
  end

  test "deliver/1 - valid email with template ID and data",
       %{
         bypass: bypass,
         config: config,
         valid_email: email
       } do
    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "api_key" => "api_key",
        "custom_headers" => [],
        "sender" => "sender@example.com",
        "subject" => "Hello, world!",
        "template_data" => %{"firstname" => "John", "lastname" => "Smith"},
        "template_id" => "template_id",
        "to" => ["receiver@example.com"]
      }

      assert body_params == conn.body_params
      assert "/email/send" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    email =
      email
      |> put_provider_option(:template_data, %{
        firstname: @firstname,
        lastname: @lastname
      })
      |> put_provider_option(:template_id, @template_id)
      |> put_provider_option(:template_error_deliver, true)
      |> put_provider_option(:template_error_reporting, @developer)

    assert {:ok, %{id: "123456789"}} = SMTP2GO.deliver(email, config)
  end

  test "deliver/1 - valid email with singular reply_to",
       %{
         bypass: bypass,
         config: config,
         valid_email: email
       } do
    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "api_key" => "api_key",
        "custom_headers" => [%{"header" => "Reply-To", "value" => "reply-to@example.com"}],
        "sender" => "sender@example.com",
        "subject" => "Hello, world!",
        "to" => ["receiver@example.com"]
      }

      assert body_params == conn.body_params
      assert "/email/send" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    email = reply_to(email, "reply-to@example.com")

    assert {:ok, %{id: "123456789"}} = SMTP2GO.deliver(email, config)
  end

  test "deliver/1 - valid email with multiple reply_to",
       %{
         bypass: bypass,
         config: config,
         valid_email: email
       } do
    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "api_key" => "api_key",
        "custom_headers" => [
          %{"header" => "Reply-To", "value" => "reply-to1@example.com, reply-to2@example.com"}
        ],
        "sender" => "sender@example.com",
        "subject" => "Hello, world!",
        "to" => ["receiver@example.com"]
      }

      assert body_params == conn.body_params
      assert "/email/send" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    email = reply_to(email, ["reply-to1@example.com", "reply-to2@example.com"])

    assert {:ok, %{id: "123456789"}} = SMTP2GO.deliver(email, config)
  end

  test "deliver/1 - valid email with reply_to and custom headers",
       %{
         bypass: bypass,
         config: config,
         valid_email: email
       } do
    Bypass.expect(bypass, fn conn ->
      conn = parse(conn)

      body_params = %{
        "api_key" => "api_key",
        "custom_headers" => [
          %{"header" => "Reply-To", "value" => "reply-to@example.com"},
          %{"header" => "test", "value" => "value"}
        ],
        "sender" => "sender@example.com",
        "subject" => "Hello, world!",
        "to" => ["receiver@example.com"]
      }

      assert body_params == conn.body_params
      assert "/email/send" == conn.request_path
      assert "POST" == conn.method

      Plug.Conn.resp(conn, 200, @success_response)
    end)

    email = email |> reply_to("reply-to@example.com") |> header("test", "value")

    assert {:ok, %{id: "123456789"}} = SMTP2GO.deliver(email, config)
  end

  test "deliver1/1 - 400", %{
    bypass: bypass,
    config: config,
    valid_email: email
  } do
    Bypass.expect(bypass, fn conn ->
      Plug.Conn.resp(conn, 400, @error_response)
    end)

    assert SMTP2GO.deliver(email, config) == {:error, {400, "E.Code"}}
  end
end
