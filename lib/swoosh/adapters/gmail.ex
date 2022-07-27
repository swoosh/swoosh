defmodule Swoosh.Adapters.Gmail do
  @moduledoc """
  An adapter that sends email using Gmail api

  For reference: [Gmail API docs](https://developers.google.com/gmail/api)

  ## Dependency

  Gmail adapter requires `Mail` dependency to format message as RFC 2822 message.

      {:mail, ">= 0.0.0"}

  Because `Mail` library removes Bcc headers, they are being added after email is
  rendered, in adapter code.

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Gmail,
        access_token: {:system, "GMAIL_API_ACCESS_TOKEN"}

      # To deal with token refresh, it could be a better idea to pass the access token
      # in via deliver config explicitly, if you don't update the environment variable
      # periodically. e.g.
      MyMailer.deliver(my_email, access_token: my_access_token)

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  ## Required config parameters
    - `:access_token` valid OAuth2 access token
        Required scopes:
        - gmail.compose
      See https://developers.google.com/oauthplayground when developing
  """

  use Swoosh.Adapter, required_config: [:access_token], required_deps: [mail: Mail]

  alias Swoosh.Email

  @base_url "https://www.googleapis.com/upload/gmail/v1"
  @api_endpoint "/users/me/messages/send"

  @impl true
  def deliver(%Email{} = email, config) do
    url = [base_url(config), @api_endpoint]

    headers = [
      {"Authorization", "Bearer #{config[:access_token]}"},
      {"Content-Type", "message/rfc822"}
    ]

    body = prepare_body(email)

    case Swoosh.ApiClient.post(url, headers, body, email) do
      {:ok, 200, _headers, body} ->
        {:ok, parse_response(body)}

      {:ok, code, _headers, body} when code >= 400 and code <= 599 ->
        {:error, {code, parse_response(body)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_response(body) when is_binary(body),
    do: body |> Swoosh.json_library().decode! |> parse_response()

  defp parse_response(%{"id" => id, "threadId" => thread_id, "labelIds" => labels}) do
    %{id: id, thread_id: thread_id, labels: labels}
  end

  defp parse_response(%{"error" => %{"errors" => errors, "code" => code, "message" => message}}) do
    %{error: %{code: code, message: message}, errors: Enum.map(errors, &parse_error/1)}
  end

  defp parse_error(error) do
    %{
      domain: error["domain"],
      reason: error["reason"],
      message: error["message"],
      location_type: error["locationType"],
      location: error["location"]
    }
  end

  defp base_url(config), do: config[:base_url] || @base_url

  defp prepare_body(email) do
    Mail.build_multipart()
    |> prepare_from(email)
    |> prepare_to(email)
    |> prepare_cc(email)
    |> prepare_bcc(email)
    |> prepare_subject(email)
    |> prepare_text(email)
    |> prepare_html(email)
    |> prepare_attachments(email)
    |> prepare_reply_to(email)
    |> prepare_custom_headers(email)
    |> Mail.Renderers.RFC2822.render()
    # When message is rendered, bcc header will be removed and we need to prepend bcc list to the
    # beginning of the message. Gmail will handle it from there.
    # https://github.com/DockYard/elixir-mail/blob/v0.2.0/lib/mail/renderers/rfc_2822.ex#L139
    |> prepend_bcc(email)
  end

  defp prepare_from(body, %{from: nil}), do: body
  defp prepare_from(body, %{from: from}), do: Mail.put_from(body, from)

  defp prepare_to(body, %{to: []}), do: body
  defp prepare_to(body, %{to: to}), do: Mail.put_to(body, to)

  defp prepare_cc(body, %{cc: []}), do: body
  defp prepare_cc(body, %{cc: cc}), do: Mail.put_cc(body, cc)

  defp prepare_bcc(rendered_mail, %{bcc: []}), do: rendered_mail
  defp prepare_bcc(rendered_mail, %{bcc: bcc}), do: Mail.put_bcc(rendered_mail, bcc)

  defp prepend_bcc(rendered_message, %{bcc: []}), do: rendered_message

  defp prepend_bcc(rendered_message, %{bcc: bcc}),
    do: Mail.Renderers.RFC2822.render_header("bcc", bcc) <> "\r\n" <> rendered_message

  defp prepare_subject(body, %{subject: subject}), do: Mail.put_subject(body, subject)

  defp prepare_text(body, %{text_body: nil}), do: body
  defp prepare_text(body, %{text_body: text_body}), do: Mail.put_text(body, text_body)

  defp prepare_html(body, %{html_body: nil}), do: body
  defp prepare_html(body, %{html_body: html_body}), do: Mail.put_html(body, html_body)

  defp prepare_attachments(body, %{attachments: attachments}) do
    Enum.reduce(attachments, body, &prepare_attachment/2)
  end

  defp prepare_attachment(attachment, body) do
    Mail.put_attachment(body, {attachment.filename, Swoosh.Attachment.get_content(attachment)})
  end

  defp prepare_reply_to(body, %{reply_to: nil}), do: body
  defp prepare_reply_to(body, %{reply_to: reply_to}), do: Mail.put_reply_to(body, reply_to)

  defp prepare_custom_headers(body, %{headers: headers}) when headers == %{}, do: body

  defp prepare_custom_headers(body, %{headers: headers}) do
    Enum.reduce(headers, body, fn {key, value}, acc ->
      Mail.Message.put_header(acc, key, value)
    end)
  end
end
