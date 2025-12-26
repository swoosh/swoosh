defmodule Swoosh.Adapters.Resend do
  @moduledoc ~S"""
  An adapter that sends email using the Resend API.

  For reference:
  * [Sending Email API docs](https://resend.com/docs/api-reference/emails/send-email)
  * [Sending Email in Batch API docs](https://resend.com/docs/api-reference/emails/send-batch-emails)

  **This adapter requires an API Client.** Swoosh comes with Hackney, Finch and Req out of the box.
  See the [installation section](https://hexdocs.pm/swoosh/Swoosh.html#module-installation)
  for details.

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Resend,
        api_key: "re_123456789"

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  ## Using with provider options

      import Swoosh.Email

      new()
      |> from("onboarding@resend.dev")
      |> to("user@example.com")
      |> subject("Hello!")
      |> html_body("<strong>Hello</strong>")
      |> put_provider_option(:tags, [%{name: "category", value: "confirm_email"}])
      |> put_provider_option(:scheduled_at, "2024-08-05T11:52:01.858Z")
      |> put_provider_option(:idempotency_key, "some-unique-key-123")
      |> header("X-Custom-Header", "CustomValue")

  ## Using Templates

      import Swoosh.Email

      new()
      |> from("onboarding@resend.dev")
      |> to("user@example.com")
      |> put_provider_option(:template, %{
        id: "my-template-id",
        variables: %{
          name: "John",
          action_url: "https://example.com"
        }
      })

  Note: When using a template, you cannot send `html_body` or `text_body` in the same email.
  The template's `from`, `subject`, and `reply_to` can be overridden in the email struct.

  ## Inline Images

  To embed images inline using Content-ID (CID):

      import Swoosh.Email

      new()
      |> from("onboarding@resend.dev")
      |> to("user@example.com")
      |> subject("Welcome!")
      |> html_body(~s(<h1>Hello!</h1><img src="cid:logo"/>))
      |> attachment(
        Swoosh.Attachment.new(
          {:data, File.read!("logo.png")},
          filename: "logo.png",
          content_type: "image/png",
          type: :inline,
          cid: "logo"
        )
      )

  ## Provider Options

    * `tags` (list of maps) - List of tag objects with `name` and `value` keys
      for categorizing emails (max 256 chars per value)

    * `scheduled_at` (string) - ISO 8601 formatted date-time string to schedule
      the email for later delivery (not supported in batch sending)

    * `idempotency_key` (string) - A unique key to prevent duplicate email sends.

    * `template` (map) - Template object with:
      * `id` (required) - The ID or alias of the published template
      * `variables` (optional) - Map of template variables (key/value pairs)

  ## Batch Sending

  This adapter supports `deliver_many/2` for sending multiple emails in a single
  API call using Resend's batch endpoint. Each email in the batch is independent
  and can have different recipients, subjects, content, and tags.

  Note: The batch endpoint has a maximum of 100 emails per request and does not
  support `scheduled_at` or `attachments` (including inline images).
  """

  use Swoosh.Adapter, required_config: [:api_key]

  alias Swoosh.Email

  @base_url "https://api.resend.com"
  @api_endpoint "/emails"
  @batch_endpoint "/emails/batch"

  defp base_url(config), do: config[:base_url] || @base_url

  def deliver(%Email{} = email, config \\ []) do
    headers = prepare_request_headers(config, email)
    body = email |> prepare_body() |> Swoosh.json_library().encode!()
    url = [base_url(config), @api_endpoint]

    case Swoosh.ApiClient.post(url, headers, body, email) do
      {:ok, code, _headers, body} when code >= 200 and code <= 399 ->
        {:ok, %{id: extract_id(body)}}

      {:ok, code, _headers, body} when code >= 400 ->
        case Swoosh.json_library().decode(body) do
          {:ok, error} -> {:error, {code, error}}
          {:error, _} -> {:error, {code, body}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def deliver_many(emails, config \\ [])

  def deliver_many([], _config) do
    {:ok, []}
  end

  def deliver_many([first_email | _] = emails, config) do
    # Validate that batch emails don't use unsupported features
    with :ok <- validate_batch_emails(emails) do
      headers = prepare_request_headers(config, first_email)
      body = emails |> prepare_batch_body() |> Swoosh.json_library().encode!()
      url = [base_url(config), @batch_endpoint]

      case Swoosh.ApiClient.post(url, headers, body, first_email) do
        {:ok, code, _headers, body} when code >= 200 and code <= 399 ->
          {:ok, extract_batch_ids(body)}

        {:ok, code, _headers, body} when code >= 400 ->
          case Swoosh.json_library().decode(body) do
            {:ok, error} -> {:error, {code, error}}
            {:error, _} -> {:error, {code, body}}
          end

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp validate_batch_emails(emails) do
    Enum.reduce_while(emails, :ok, fn email, _acc ->
      cond do
        has_scheduled_at?(email) ->
          {:halt, {:error, "scheduled_at is not supported in batch email sending"}}

        has_attachments?(email) ->
          {:halt, {:error, "attachments are not supported in batch email sending"}}

        true ->
          {:cont, :ok}
      end
    end)
  end

  defp has_scheduled_at?(%Email{provider_options: %{scheduled_at: _}}), do: true
  defp has_scheduled_at?(_), do: false

  defp has_attachments?(%Email{attachments: []}), do: false
  defp has_attachments?(%Email{attachments: _}), do: true

  defp prepare_request_headers(config, email) do
    headers = [
      {"Authorization", "Bearer #{config[:api_key]}"},
      {"Content-Type", "application/json"},
      {"User-Agent", "swoosh/#{Swoosh.version()}"}
    ]

    if idempotency_key = email.provider_options[:idempotency_key] do
      [{"Idempotency-Key", idempotency_key} | headers]
    else
      headers
    end
  end

  defp extract_id(body) do
    body
    |> Swoosh.json_library().decode!()
    |> Map.get("id")
  end

  defp extract_batch_ids(body) do
    body
    |> Swoosh.json_library().decode!()
    |> Map.get("data", [])
    |> Enum.map(&%{id: Map.get(&1, "id")})
  end

  defp prepare_batch_body(emails) do
    Enum.map(emails, &prepare_body/1)
  end

  defp prepare_body(email) do
    %{}
    |> prepare_from(email)
    |> prepare_to(email)
    |> prepare_cc(email)
    |> prepare_bcc(email)
    |> prepare_reply_to(email)
    |> prepare_subject(email)
    |> prepare_text(email)
    |> prepare_html(email)
    |> prepare_attachments(email)
    |> prepare_tags(email)
    |> prepare_scheduled_at(email)
    |> prepare_template(email)
    |> prepare_headers_body(email)
  end

  defp prepare_from(body, %{from: {name, email}}) when name not in [nil, ""] do
    Map.put(body, "from", "#{name} <#{email}>")
  end

  defp prepare_from(body, %{from: {_name, email}}) do
    Map.put(body, "from", email)
  end

  defp prepare_to(body, %{to: to}) do
    Map.put(body, "to", Enum.map(to, &format_recipient/1))
  end

  defp prepare_cc(body, %{cc: []}), do: body

  defp prepare_cc(body, %{cc: cc}) do
    Map.put(body, "cc", Enum.map(cc, &format_recipient/1))
  end

  defp prepare_bcc(body, %{bcc: []}), do: body

  defp prepare_bcc(body, %{bcc: bcc}) do
    Map.put(body, "bcc", Enum.map(bcc, &format_recipient/1))
  end

  defp prepare_reply_to(body, %{reply_to: nil}), do: body

  defp prepare_reply_to(body, %{reply_to: reply_to}) do
    Map.put(body, "reply_to", format_recipient(reply_to))
  end

  defp prepare_subject(body, %{subject: subject}) when subject != "" do
    Map.put(body, "subject", subject)
  end

  defp prepare_subject(body, _), do: body

  defp prepare_text(body, %{text_body: nil}), do: body

  defp prepare_text(body, %{text_body: text}) do
    Map.put(body, "text", text)
  end

  defp prepare_html(body, %{html_body: nil}), do: body

  defp prepare_html(body, %{html_body: html}) do
    Map.put(body, "html", html)
  end

  defp prepare_attachments(body, %{attachments: []}), do: body

  defp prepare_attachments(body, %{attachments: attachments}) do
    Map.put(
      body,
      "attachments",
      Enum.map(attachments, fn attachment ->
        attachment_data = %{
          filename: attachment.filename,
          content: Swoosh.Attachment.get_content(attachment, :base64)
        }

        # Only add content_id for inline attachments (type: :inline with cid)
        case {attachment.type, attachment.cid} do
          {:inline, cid} when not is_nil(cid) ->
            Map.put(attachment_data, "content_id", cid)

          _ ->
            attachment_data
        end
      end)
    )
  end

  defp prepare_tags(body, %{provider_options: %{tags: tags}}) when is_list(tags) do
    Map.put(body, "tags", tags)
  end

  defp prepare_tags(body, _), do: body

  defp prepare_scheduled_at(body, %{provider_options: %{scheduled_at: scheduled_at}}) do
    Map.put(body, "scheduled_at", scheduled_at)
  end

  defp prepare_scheduled_at(body, _), do: body

  defp prepare_template(body, %{provider_options: %{template: template}}) when is_map(template) do
    Map.put(body, "template", template)
  end

  defp prepare_template(body, _), do: body

  defp prepare_headers_body(body, %{headers: headers}) when map_size(headers) > 0 do
    formatted_headers =
      Enum.map(headers, fn {key, value} -> %{name: key, value: value} end)

    Map.put(body, "headers", formatted_headers)
  end

  defp prepare_headers_body(body, _), do: body

  defp format_recipient({name, email}) when name not in [nil, ""] do
    "#{name} <#{email}>"
  end

  defp format_recipient({_name, email}), do: email
end
