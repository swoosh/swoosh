defmodule Swoosh.Adapters.MailKite do
  @moduledoc ~S"""
  An adapter that sends email using the MailKite API.

  For reference: [MailKite API docs](https://mailkite.dev/docs/api-reference)

  **This adapter requires an API Client.** Swoosh comes with Hackney, Finch and Req out of the box.
  See the [installation section](https://hexdocs.pm/swoosh/Swoosh.html#module-installation)
  for details.

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.MailKite,
        api_key: "mk_live_my-api-key"

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  The `from` address must belong to a domain verified in your MailKite account.

  ## Attachments

  Regular attachments are sent inline as base64. MailKite attachments carry no
  `Content-ID`, so inline (`type: :inline`) attachments cannot be expressed and
  `deliver/2` returns `{:error, :inline_attachments_not_supported}` rather than
  silently sending them as regular attachments. Host the image and reference it
  by URL in your HTML instead.

  ## Using with provider options

      import Swoosh.Email

      new()
      |> from("nora@example.com")
      |> to("shushu@example.com")
      |> subject("Hello, Wally!")
      |> text_body("Hello")
      |> put_provider_option(:metadata, %{order_id: "ord_8812"})
      |> put_provider_option(:track_opens, true)
      |> put_provider_option(:scheduled_at, "2030-01-01T00:00:00Z")

  ## Provider Options

    * `metadata` (map) - `metadata`, scalar key/value pairs stored server-side on
      the message and echoed back on reads; never emitted as a MIME header

    * `template_id` (string) - `templateId`, send from a saved MailKite template
      (`tpl_…` or `base_…`); explicit subject/html/text override the template's

    * `template_data` (map) - `templateData`, values substituted into the
      template's `{{merge_tags}}`

    * `in_reply_to` (string) - `inReplyTo`, the `Message-ID` this email replies
      to, so MailKite sets the threading headers

    * `scheduled_at` (string or integer) - `scheduledAt`, send later: an ISO 8601
      timestamp or a millisecond epoch. The response then carries the scheduled
      send id and `status: "scheduled"`

    * `track_opens` (boolean) - `trackOpens`, override the sending domain's
      open-tracking default for this email

    * `track_clicks` (boolean) - `trackClicks`, override the sending domain's
      click-tracking default for this email

  """

  use Swoosh.Adapter, required_config: [:api_key]

  alias Swoosh.Email

  @base_url "https://api.mailkite.dev"
  @api_endpoint "/v1/send"

  @provider_options %{
    metadata: "metadata",
    template_id: "templateId",
    template_data: "templateData",
    in_reply_to: "inReplyTo",
    scheduled_at: "scheduledAt",
    track_opens: "trackOpens",
    track_clicks: "trackClicks"
  }

  def deliver(%Email{} = email, config \\ []) do
    with {:ok, payload} <- prepare_payload(email) do
      headers = prepare_headers(config)
      body = Swoosh.json_library().encode!(payload)
      url = [base_url(config), @api_endpoint]

      url |> Swoosh.ApiClient.post(headers, body, email) |> handle_response()
    end
  end

  defp base_url(config), do: config[:base_url] || @base_url

  defp prepare_headers(config) do
    [
      {"Accept", "application/json"},
      {"Content-Type", "application/json"},
      {"User-Agent", "swoosh/#{Swoosh.version()}"},
      {"Authorization", "Bearer #{config[:api_key]}"}
    ]
  end

  defp prepare_payload(%{attachments: attachments} = email) do
    if Enum.any?(attachments, &(&1.type == :inline)) do
      {:error, :inline_attachments_not_supported}
    else
      payload =
        %{}
        |> prepare_from(email)
        |> prepare_to(email)
        |> prepare_cc(email)
        |> prepare_bcc(email)
        |> prepare_reply_to(email)
        |> prepare_subject(email)
        |> prepare_text_content(email)
        |> prepare_html_content(email)
        |> prepare_email_headers(email)
        |> prepare_attachments(email)
        |> prepare_provider_options(email)

      {:ok, payload}
    end
  end

  defp prepare_from(payload, %{from: from}), do: Map.put(payload, "from", format_address(from))

  defp prepare_to(payload, %{to: to}), do: Map.put(payload, "to", Enum.map(to, &format_address/1))

  defp prepare_cc(payload, %{cc: []}), do: payload
  defp prepare_cc(payload, %{cc: cc}), do: Map.put(payload, "cc", Enum.map(cc, &format_address/1))

  defp prepare_bcc(payload, %{bcc: []}), do: payload

  defp prepare_bcc(payload, %{bcc: bcc}),
    do: Map.put(payload, "bcc", Enum.map(bcc, &format_address/1))

  # MailKite takes a single Reply-To address; a list is joined the way a mail
  # client would render the header.
  defp prepare_reply_to(payload, %{reply_to: nil}), do: payload

  defp prepare_reply_to(payload, %{reply_to: reply_to}) when is_list(reply_to) do
    Map.put(payload, "replyTo", Enum.map_join(reply_to, ", ", &format_address/1))
  end

  defp prepare_reply_to(payload, %{reply_to: reply_to}) do
    Map.put(payload, "replyTo", format_address(reply_to))
  end

  defp prepare_subject(payload, %{subject: subject}) when subject in [nil, ""], do: payload
  defp prepare_subject(payload, %{subject: subject}), do: Map.put(payload, "subject", subject)

  defp prepare_text_content(payload, %{text_body: nil}), do: payload
  defp prepare_text_content(payload, %{text_body: text}), do: Map.put(payload, "text", text)

  defp prepare_html_content(payload, %{html_body: nil}), do: payload
  defp prepare_html_content(payload, %{html_body: html}), do: Map.put(payload, "html", html)

  defp prepare_email_headers(payload, %{headers: headers}) when map_size(headers) == 0,
    do: payload

  defp prepare_email_headers(payload, %{headers: headers}),
    do: Map.put(payload, "headers", headers)

  defp prepare_attachments(payload, %{attachments: []}), do: payload

  defp prepare_attachments(payload, %{attachments: attachments}) do
    Map.put(payload, "attachments", Enum.map(attachments, &prepare_attachment/1))
  end

  defp prepare_attachment(attachment) do
    %{
      "filename" => attachment.filename,
      "contentType" => attachment.content_type,
      "content" => Swoosh.Attachment.get_content(attachment, :base64)
    }
  end

  defp prepare_provider_options(payload, %{provider_options: provider_options}) do
    Enum.reduce(@provider_options, payload, fn {option, key}, acc ->
      case Map.fetch(provider_options, option) do
        {:ok, value} -> Map.put(acc, key, value)
        :error -> acc
      end
    end)
  end

  # Display names are quoted unless they are a plain run of atom characters,
  # matching how MailKite's other integrations render RFC 5322 mailboxes.
  defp format_address({name, address}) when name in [nil, ""], do: address

  defp format_address({name, address}) do
    if Regex.match?(~r/\A[A-Za-z0-9 .'\-]+\z/, name) do
      "#{name} <#{address}>"
    else
      escaped = String.replace(name, ~r/(["\\])/, "\\\\\\1")
      "\"#{escaped}\" <#{address}>"
    end
  end

  defp format_address(address) when is_binary(address), do: address

  defp handle_response({:ok, code, _headers, body}) when code in 200..299 do
    case Swoosh.json_library().decode(body) do
      {:ok, %{"id" => id} = response} ->
        {:ok, %{id: id, status: response["status"]}}

      {:ok, response} ->
        {:ok, response}

      {:error, _} ->
        {:error, {code, body}}
    end
  end

  defp handle_response({:ok, code, _headers, body}) do
    case Swoosh.json_library().decode(body) do
      {:ok, error} -> {:error, {code, error}}
      {:error, _} -> {:error, {code, body}}
    end
  end

  defp handle_response({:error, reason}), do: {:error, reason}
end
