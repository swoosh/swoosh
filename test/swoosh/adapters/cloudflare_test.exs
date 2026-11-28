defmodule Swoosh.Adapters.CloudflareTest do
  use Swoosh.AdapterCase, async: true

  import Plug.Conn, only: [get_req_header: 2, resp: 3]
  import Swoosh.Email

  alias Swoosh.Adapters.Cloudflare
  alias Swoosh.Attachment
  alias Swoosh.Mailer

  @account_id "0123456789abcdef0123456789abcdef"
  @endpoint "/client/v4/accounts/#{@account_id}/email/sending/send"
  @message_id "<message@example.com>"

  setup do
    bypass = Bypass.open()

    config = [
      adapter: Cloudflare,
      account_id: @account_id,
      api_token: "test-token",
      base_url: "http://localhost:#{bypass.port}"
    ]

    email =
      new()
      |> from("sender@example.com")
      |> to("recipient@example.com")
      |> subject("Welcome")
      |> text_body("Hello")

    {:ok, bypass: bypass, config: config, email: email}
  end

  test "sends a text email with bearer authentication", context do
    Bypass.expect_once(context.bypass, "POST", @endpoint, fn conn ->
      assert get_req_header(conn, "authorization") == ["Bearer test-token"]
      assert get_req_header(conn, "content-type") == ["application/json"]

      assert parse(conn).body_params == %{
               "from" => "sender@example.com",
               "to" => ["recipient@example.com"],
               "subject" => "Welcome",
               "text" => "Hello"
             }

      respond(conn, 200, response())
    end)

    assert Mailer.deliver(context.email, context.config) ==
             {:ok,
              %{
                id: @message_id,
                delivered: ["recipient@example.com"],
                queued: [],
                permanent_bounces: [],
                suppressed_recipients: []
              }}
  end

  test "preserves named addresses and sends cc, bcc, reply-to, HTML and headers", context do
    email =
      context.email
      |> from({"Support", "sender@example.com"})
      |> to({"Jane Doe", "jane@example.com"})
      |> cc({"Team", "team@example.com"})
      |> bcc("archive@example.com")
      |> reply_to([{"Replies", "replies@example.com"}])
      |> html_body("<h1>Hello</h1>")
      |> header("X-Ticket", "123")

    Bypass.expect_once(context.bypass, "POST", @endpoint, fn conn ->
      assert parse(conn).body_params == %{
               "from" => %{"address" => "sender@example.com", "name" => "Support"},
               "to" => [
                 %{"address" => "jane@example.com", "name" => "Jane Doe"},
                 "recipient@example.com"
               ],
               "cc" => [%{"address" => "team@example.com", "name" => "Team"}],
               "bcc" => ["archive@example.com"],
               "reply_to" => %{"address" => "replies@example.com", "name" => "Replies"},
               "subject" => "Welcome",
               "text" => "Hello",
               "html" => "<h1>Hello</h1>",
               "headers" => %{"X-Ticket" => "123"}
             }

      respond(conn, 200, response())
    end)

    assert {:ok, _} = Mailer.deliver(email, context.config)
  end

  test "encodes regular and inline attachments", context do
    email =
      context.email
      |> attachment(Attachment.new({:data, "hello"}, filename: "hello.txt"))
      |> attachment(
        Attachment.new({:data, <<0, 255>>},
          filename: "logo.png",
          content_type: "image/png",
          type: :inline,
          cid: "logo"
        )
      )

    Bypass.expect_once(context.bypass, "POST", @endpoint, fn conn ->
      assert parse(conn).body_params["attachments"] == [
               %{
                 "content" => "AP8=",
                 "filename" => "logo.png",
                 "type" => "image/png",
                 "disposition" => "inline",
                 "content_id" => "logo"
               },
               %{
                 "content" => "aGVsbG8=",
                 "filename" => "hello.txt",
                 "type" => "text/plain",
                 "disposition" => "attachment"
               }
             ]

      respond(conn, 200, response())
    end)

    assert {:ok, _} = Mailer.deliver(email, context.config)
  end

  test "sends an HTML-only email addressed via bcc", context do
    email =
      new()
      |> from("sender@example.com")
      |> bcc("archive@example.com")
      |> subject("Welcome")
      |> html_body("<h1>Hello</h1>")

    Bypass.expect_once(context.bypass, "POST", @endpoint, fn conn ->
      assert parse(conn).body_params == %{
               "from" => "sender@example.com",
               "bcc" => ["archive@example.com"],
               "subject" => "Welcome",
               "html" => "<h1>Hello</h1>"
             }

      result = %{
        "queued" => ["archive@example.com"],
        "delivered" => [],
        "permanent_bounces" => []
      }

      respond(conn, 200, %{response() | "result" => result})
    end)

    assert {:ok, %{id: nil, queued: ["archive@example.com"], suppressed_recipients: []}} =
             Mailer.deliver(email, context.config)
  end

  test "returns all recipient outcomes from a successful request", context do
    result = %{
      "message_id" => @message_id,
      "delivered" => ["recipient@example.com"],
      "queued" => ["queued@example.com"],
      "permanent_bounces" => ["bounced@example.com"],
      "suppressed_recipients" => ["suppressed@example.com"]
    }

    email =
      to(context.email, ["queued@example.com", "bounced@example.com", "suppressed@example.com"])

    Bypass.expect_once(context.bypass, "POST", @endpoint, fn conn ->
      respond(conn, 200, %{response() | "result" => result})
    end)

    assert Mailer.deliver(email, context.config) ==
             {:ok,
              %{
                id: @message_id,
                delivered: ["recipient@example.com"],
                queued: ["queued@example.com"],
                permanent_bounces: ["bounced@example.com"],
                suppressed_recipients: ["suppressed@example.com"]
              }}
  end

  for status <- [200, 403] do
    test "returns Cloudflare's error details for HTTP #{status}", context do
      status = unquote(status)

      error = %{
        "success" => false,
        "errors" => [
          %{"code" => 10102, "message" => "email.sending.error.authentication.forbidden"}
        ],
        "messages" => [],
        "result" => nil
      }

      Bypass.expect_once(context.bypass, "POST", @endpoint, &respond(&1, status, error))

      assert Mailer.deliver(context.email, context.config) == {:error, {status, error}}
    end
  end

  test "reports unknown acceptance for a successful HTTP status with malformed JSON", context do
    Bypass.expect_once(context.bypass, "POST", @endpoint, &resp(&1, 200, "invalid JSON"))

    assert Mailer.deliver(context.email, context.config) ==
             {:error, {:acceptance_unknown, 200, "invalid JSON"}}
  end

  test "reports unknown acceptance when a 2xx body lacks an explicit success flag", context do
    body = %{"result" => %{}}
    Bypass.expect_once(context.bypass, "POST", @endpoint, &respond(&1, 202, body))

    assert Mailer.deliver(context.email, context.config) ==
             {:error, {:acceptance_unknown, 202, body}}
  end

  test "reports acceptance when the successful response has no result", context do
    body = Map.delete(response(), "result")
    Bypass.expect_once(context.bypass, "POST", @endpoint, &respond(&1, 200, body))

    assert Mailer.deliver(context.email, context.config) ==
             {:ok,
              %{
                id: nil,
                delivered: [],
                queued: [],
                permanent_bounces: [],
                suppressed_recipients: []
              }}
  end

  test "keeps valid outcomes when other result fields are missing or invalid", context do
    result = %{
      "message_id" => 123,
      "delivered" => ["recipient@example.com", nil],
      "permanent_bounces" => "bounced@example.com",
      "suppressed_recipients" => nil
    }

    Bypass.expect_once(
      context.bypass,
      "POST",
      @endpoint,
      &respond(&1, 200, %{response() | "result" => result})
    )

    assert Mailer.deliver(context.email, context.config) ==
             {:ok,
              %{
                id: nil,
                delivered: ["recipient@example.com"],
                queued: [],
                permanent_bounces: [],
                suppressed_recipients: []
              }}
  end

  test "returns the permanent bounce when Cloudflare accepted the request but no recipient got the email",
       context do
    result = %{
      "message_id" => @message_id,
      "delivered" => [],
      "queued" => [],
      "permanent_bounces" => ["recipient@example.com"],
      "suppressed_recipients" => []
    }

    Bypass.expect_once(
      context.bypass,
      "POST",
      @endpoint,
      &respond(&1, 200, %{response() | "result" => result})
    )

    assert {:ok, %{delivered: [], queued: [], permanent_bounces: ["recipient@example.com"]}} =
             Mailer.deliver(context.email, context.config)
  end

  test "returns an error when the HTTP connection fails", context do
    :ok = Bypass.down(context.bypass)

    assert {:error, _reason} = Mailer.deliver(context.email, context.config)
  end

  test "rejects multiple reply-to addresses", context do
    email = reply_to(context.email, ["first@example.com", "second@example.com"])

    assert Mailer.deliver(email, context.config) == {:error, :multiple_reply_to_not_supported}
  end

  test "rejects a binary attachment that has no filename", context do
    email = attachment(context.email, Attachment.new({:data, "hello"}))

    assert Mailer.deliver(email, context.config) == {:error, :attachment_filename_required}
  end

  for key <- [:account_id, :api_token], invalid <- [nil, "", 123] do
    test "rejects #{inspect(invalid)} for #{key} without exposing credentials", context do
      key = unquote(key)
      config = Keyword.put(context.config, key, unquote(invalid))

      exception =
        assert_raise ArgumentError, ~r/expected .+#{key}.+ to be set/, fn ->
          Mailer.deliver(context.email, config)
        end

      refute Exception.message(exception) =~ "test-token"
    end
  end

  for invalid <- [@account_id <> "\n", @account_id <> "/other"] do
    test "rejects account IDs containing #{inspect(invalid)} before sending", context do
      config = Keyword.put(context.config, :account_id, unquote(invalid))

      exception =
        assert_raise ArgumentError, ~r/expected .+account_id.+ to be set/, fn ->
          Mailer.deliver(context.email, config)
        end

      refute Exception.message(exception) =~ "test-token"
    end
  end

  defp response do
    %{
      "success" => true,
      "errors" => [],
      "messages" => [],
      "result" => %{
        "message_id" => @message_id,
        "delivered" => ["recipient@example.com"],
        "queued" => [],
        "permanent_bounces" => [],
        "suppressed_recipients" => []
      }
    }
  end

  defp respond(conn, status, body), do: resp(conn, status, Jason.encode!(body))
end

defmodule Swoosh.Adapters.CloudflareClientContractTest do
  use ExUnit.Case, async: false

  import Swoosh.Email

  defmodule Client do
    @behaviour Swoosh.ApiClient

    @impl true
    def post(url, _headers, _body, _email) when is_binary(url) do
      send(self(), {:request_url, url})
      {:error, :test_transport_failure}
    end
  end

  setup do
    previous_client = Application.fetch_env!(:swoosh, :api_client)
    Application.put_env(:swoosh, :api_client, Client)
    on_exit(fn -> Application.put_env(:swoosh, :api_client, previous_client) end)

    email =
      new()
      |> from("sender@example.com")
      |> to("recipient@example.com")
      |> subject("Welcome")
      |> text_body("Hello")

    account_id = "0123456789abcdef0123456789abcdef"

    config = [
      adapter: Swoosh.Adapters.Cloudflare,
      account_id: account_id,
      api_token: "test-token"
    ]

    {:ok, email: email, config: config, account_id: account_id}
  end

  test "passes the default endpoint as a binary to a custom API client", context do
    %{email: email, config: config, account_id: account_id} = context
    assert Swoosh.Mailer.deliver(email, config) == {:error, :test_transport_failure}

    assert_received {:request_url,
                     "https://api.cloudflare.com/client/v4/accounts/" <>
                       ^account_id <> "/email/sending/send"}
  end

  test "removes trailing slashes from the configured base URL", context do
    config = Keyword.put(context.config, :base_url, "https://cloudflare.example//")

    expected =
      "https://cloudflare.example/client/v4/accounts/#{context.account_id}/email/sending/send"

    assert Swoosh.Mailer.deliver(context.email, config) == {:error, :test_transport_failure}
    assert_received {:request_url, ^expected}
  end
end
