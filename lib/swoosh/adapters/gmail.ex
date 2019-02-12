defmodule Swoosh.Adapters.Gmail do
  @moduledoc """
  An adapter that sends email using Gmail api

  For reference [Gmail API docs](https://developers.google.com/gmail/api)

  You don't need to set `from` address as google will set it for you.
  If you still want to include it, make sure it matches the account or
  it will be ignored.

  ## Dependency

  Gmail adapter requires `Mail` dependency to format message as RFC 2822 message.

  Because `Mail` library removes Bcc headers, they are being added after email is
  rendered.

  ## Example

      # config/congig.exs
      config :sample, Smaple.Mailer
        adapter: Swoosh.Adapters.Gmail,


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
    |> Mail.Renderers.RFC2822.render()
    # When message is rendered, bcc header will be removed and we need to prepend bcc list to the
    # begining of the message. Gmail will handle it from there.
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
end
