defmodule Swoosh.Adapters.AhaSend do
  @moduledoc ~S"""
  An adapter that sends email using the AhaSend API.

  For reference: [AhaSend API docs](https://ahasend.com/docs/api-reference)

  **This adapter requires an API Client.** Swoosh comes with Hackney, Finch and Req out of the box.
  See the [installation section](https://hexdocs.pm/swoosh/Swoosh.html#module-installation)
  for details.

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.AhaSend,
        api_key: "aha-sk-my-api-key",
        account_id: "my-account-id"

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  ## Recipients

  AhaSend exposes two send endpoints and this adapter picks the one that
  preserves the semantics of the email you built:

    * emails without `cc` or `bcc` are sent through `/messages`, which
      delivers an individual message to each recipient. Recipients do not
      see one another.

    * emails with `cc` or `bcc` are sent through `/messages/conversation`,
      which delivers a single message carrying the full `To`/`Cc`/`Bcc`
      headers, the way a regular mail client would.

  ## Delivering many emails

  `deliver_many/2` sends each email in its own request, so a problem with one
  email (an invalid recipient, say) never affects the others. Results are
  returned in the same order as the emails passed in. Delivery stops at the
  first failure and returns that error; emails already sent are not rolled
  back.

  ## Using with provider options

      import Swoosh.Email

      new()
      |> from("nora@example.com")
      |> to("shushu@example.com")
      |> subject("Hello, Wally!")
      |> text_body("Hello")
      |> put_provider_option(:tags, ["welcome", "onboarding"])
      |> put_provider_option(:tracking, %{open: true, click: false})
      |> put_provider_option(:idempotency_key, "unique-key-123")

  ## Provider Options

    * `tags` (list of strings) - `tags`, categorize the message

    * `substitutions` (map) - `substitutions`, template variables applied to
      the subject and body

    * `tracking` (map) - `tracking`, override the account open/click tracking
      defaults, for example `%{open: true, click: false}`

    * `retention` (map) - `retention`, override the account data retention
      defaults, for example `%{metadata: 30, data: 7}`

    * `schedule` (map) - `schedule`, defer delivery, for example
      `%{first_attempt: "2026-01-01T00:00:00Z"}`

    * `sandbox` (boolean) - `sandbox`, accept and validate the message
      without delivering it

    * `sandbox_result` (string) - `sandbox_result`, the outcome to simulate in
      sandbox mode. One of `deliver`, `bounce`, `defer`, `fail`, `suppress`

    * `idempotency_key` (string) - sent as the `Idempotency-Key` header so a
      retried request cannot deliver the message twice

  """

  use Swoosh.Adapter, required_config: [:api_key, :account_id]

  alias Swoosh.Email

  @base_url "https://api.ahasend.com"

  def deliver(%Email{} = email, config \\ []) do
    headers = prepare_headers(config, email)
    body = email |> prepare_payload() |> Swoosh.json_library().encode!()
    url = [base_url(config), api_endpoint(config, email)]

    url |> Swoosh.ApiClient.post(headers, body, email) |> handle_response()
  end

  def deliver_many(emails, config \\ [])

  def deliver_many([], _config) do
    {:ok, []}
  end

  def deliver_many(emails, config) when is_list(emails) do
    case Enum.reduce_while(emails, [], &deliver_and_accumulate(&1, &2, config)) do
      {:error, reason} -> {:error, reason}
      results -> {:ok, Enum.reverse(results)}
    end
  end

  defp deliver_and_accumulate(email, results, config) do
    case deliver(email, config) do
      {:ok, result} -> {:cont, [result | results]}
      {:error, reason} -> {:halt, {:error, reason}}
    end
  end

  defp base_url(config), do: config[:base_url] || @base_url

  defp api_endpoint(config, email) do
    suffix = if conversation?(email), do: "/conversation", else: ""
    ["/v2/accounts/", to_string(config[:account_id]), "/messages", suffix]
  end

  defp conversation?(%{cc: [], bcc: []}), do: false
  defp conversation?(_email), do: true

  defp prepare_headers(config, email) do
    base_headers = [
      {"Accept", "application/json"},
      {"Content-Type", "application/json"},
      {"User-Agent", "swoosh/#{Swoosh.version()}"},
      {"Authorization", "Bearer #{config[:api_key]}"}
    ]

    case email do
      %{provider_options: %{idempotency_key: key}} -> [{"Idempotency-Key", key} | base_headers]
      _ -> base_headers
    end
  end

  defp prepare_payload(email) do
    %{}
    |> prepare_from(email)
    |> prepare_recipients(email)
    |> prepare_cc(email)
    |> prepare_bcc(email)
    |> prepare_reply_to(email)
    |> prepare_subject(email)
    |> prepare_text_content(email)
    |> prepare_html_content(email)
    |> prepare_email_headers(email)
    |> prepare_attachments(email)
    |> prepare_tags(email)
    |> prepare_substitutions(email)
    |> prepare_tracking(email)
    |> prepare_retention(email)
    |> prepare_schedule(email)
    |> prepare_sandbox(email)
    |> prepare_sandbox_result(email)
  end

  defp prepare_from(payload, %{from: from}), do: Map.put(payload, "from", format_address(from))

  defp prepare_recipients(payload, %{to: to} = email) do
    key = if conversation?(email), do: "to", else: "recipients"
    Map.put(payload, key, Enum.map(to, &format_address/1))
  end

  defp prepare_cc(payload, %{cc: []}), do: payload
  defp prepare_cc(payload, %{cc: cc}), do: Map.put(payload, "cc", Enum.map(cc, &format_address/1))

  defp prepare_bcc(payload, %{bcc: []}), do: payload

  defp prepare_bcc(payload, %{bcc: bcc}) do
    Map.put(payload, "bcc", Enum.map(bcc, &format_address/1))
  end

  defp prepare_reply_to(payload, %{reply_to: nil}), do: payload

  defp prepare_reply_to(payload, %{reply_to: reply_to}) do
    Map.put(payload, "reply_to", format_address(reply_to))
  end

  defp prepare_subject(payload, %{subject: ""}), do: payload
  defp prepare_subject(payload, %{subject: subject}), do: Map.put(payload, "subject", subject)

  defp prepare_text_content(payload, %{text_body: nil}), do: payload

  defp prepare_text_content(payload, %{text_body: text_body}) do
    Map.put(payload, "text_content", text_body)
  end

  defp prepare_html_content(payload, %{html_body: nil}), do: payload

  defp prepare_html_content(payload, %{html_body: html_body}) do
    Map.put(payload, "html_content", html_body)
  end

  defp prepare_email_headers(payload, %{headers: headers}) when map_size(headers) == 0,
    do: payload

  defp prepare_email_headers(payload, %{headers: headers}),
    do: Map.put(payload, "headers", headers)

  defp prepare_attachments(payload, %{attachments: []}), do: payload

  defp prepare_attachments(payload, %{attachments: attachments}) do
    Map.put(payload, "attachments", Enum.map(attachments, &prepare_attachment/1))
  end

  defp prepare_attachment(attachment) do
    prepared = %{
      "file_name" => attachment.filename,
      "content_type" => attachment.content_type,
      "data" => Swoosh.Attachment.get_content(attachment, :base64),
      "base64" => true
    }

    case attachment.type do
      :attachment ->
        prepared

      :inline ->
        Map.merge(prepared, %{"content_id" => attachment.cid, "content_disposition" => "inline"})
    end
  end

  defp prepare_tags(payload, %{provider_options: %{tags: tags}}),
    do: Map.put(payload, "tags", tags)

  defp prepare_tags(payload, _email), do: payload

  defp prepare_substitutions(payload, %{provider_options: %{substitutions: substitutions}}) do
    Map.put(payload, "substitutions", substitutions)
  end

  defp prepare_substitutions(payload, _email), do: payload

  defp prepare_tracking(payload, %{provider_options: %{tracking: tracking}}) do
    Map.put(payload, "tracking", tracking)
  end

  defp prepare_tracking(payload, _email), do: payload

  defp prepare_retention(payload, %{provider_options: %{retention: retention}}) do
    Map.put(payload, "retention", retention)
  end

  defp prepare_retention(payload, _email), do: payload

  defp prepare_schedule(payload, %{provider_options: %{schedule: schedule}}) do
    Map.put(payload, "schedule", schedule)
  end

  defp prepare_schedule(payload, _email), do: payload

  defp prepare_sandbox(payload, %{provider_options: %{sandbox: sandbox}}) do
    Map.put(payload, "sandbox", sandbox)
  end

  defp prepare_sandbox(payload, _email), do: payload

  defp prepare_sandbox_result(payload, %{provider_options: %{sandbox_result: result}}) do
    Map.put(payload, "sandbox_result", result)
  end

  defp prepare_sandbox_result(payload, _email), do: payload

  defp format_address({name, email}) when name in [nil, ""], do: %{"email" => email}
  defp format_address({name, email}), do: %{"email" => email, "name" => name}
  defp format_address(email) when is_binary(email), do: %{"email" => email}

  defp handle_response({:ok, 202, _headers, body}) do
    case Swoosh.json_library().decode(body) do
      {:ok, %{"data" => [_ | _] = messages}} -> {:ok, format_delivery(messages)}
      {:ok, response} -> {:ok, response}
      {:error, _} -> {:error, {202, body}}
    end
  end

  defp handle_response({:ok, code, _headers, body}) when code >= 400 do
    case Swoosh.json_library().decode(body) do
      {:ok, error} -> {:error, {code, error}}
      {:error, _} -> {:error, {code, body}}
    end
  end

  # Any other 2xx/3xx the API might return. The documented send response is
  # 202, but this keeps an unexpected success code from crashing rather than
  # being reported.
  defp handle_response({:ok, _code, _headers, body}) do
    case Swoosh.json_library().decode(body) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, _} -> {:ok, body}
    end
  end

  defp handle_response({:error, reason}), do: {:error, reason}

  # AhaSend answers with one entry per recipient. The first entry is surfaced
  # as `id`/`status` to match the shape used by the other adapters, and the
  # full list is kept under `messages` so nothing is lost.
  defp format_delivery([first | _] = messages) do
    %{
      id: first["id"],
      status: first["status"],
      messages: Enum.map(messages, &format_message/1)
    }
  end

  defp format_message(message) do
    %{
      id: message["id"],
      status: message["status"],
      recipient: get_in(message, ["recipient", "email"]),
      error: message["error"]
    }
  end
end
