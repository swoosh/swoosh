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

  use Swoosh.Adapter, required_deps: [mail: Mail]

  alias Swoosh.Email

  @base_url "https://www.googleapis.com/upload/gmail/v1"
  @api_endpoint "/users/me/messages/send"

  def deliver(%Email{} = email, config \\ []) do
    access_token = config[:access_token] || raise("access_token is required")

    headers = [
      {"Authorization", "Bearer #{access_token}"},
      {"Content-Type", "application/json"}
    ]

    url = [base_url(config), @api_endpoint]

    encoded_email = prepare_body(email) |> Base.url_encode64()

    body =
      %{}
      |> Map.put("raw", encoded_email)
      |> Swoosh.json_library().encode!()

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

  def prepare_body(email) do
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
      |> parse_bcc(email)
  end

  defp prepare_from(body, %{from: nil}), do: body
  defp prepare_from(body, %{from: from}), do: Mail.put_from(body, from)

  defp prepare_to(body, %{to: []}), do: body
  defp prepare_to(body, %{to: to}), do: Mail.put_to(body, to)

  defp prepare_cc(body, %{cc: []}), do: body
  defp prepare_cc(body, %{cc: cc}), do: Mail.put_cc(body, cc)

  defp prepare_bcc(rendered_mail, %{bcc: []}), do: rendered_mail
  defp prepare_bcc(rendered_mail, %{bcc: bcc}), do: Mail.put_bcc(rendered_mail, bcc)

  defp parse_bcc(rendered_message, %{bcc: []}), do: rendered_message
  defp parse_bcc(rendered_message, %{bcc: bcc}),
    do: Mail.Renderers.RFC2822.render_header("bcc", bcc) <> "\r\n" <> rendered_message

  defp prepare_subject(body, %{subject: subject}), do: Mail.put_subject(body, subject)

  defp prepare_text(body, %{text_body: nil}), do: body
  defp prepare_text(body, %{text_body: text_body}), do: Mail.put_text(body, text_body)

  defp prepare_html(body, %{html_body: nil}), do: body
  defp prepare_html(body, %{html_body: html_body}), do: Mail.put_html(body, html_body)

  defp prepare_attachments(body, %{attachments: attachments}) do
    Enum.reduce(attachments, body, &prepare_attachment/2)
  end

  defp prepare_attachment(%{data: nil, path: path, filename: filename}, body) do
    data = File.read!(path)
    Mail.put_attachment(body, {filename, data})
  end

  defp prepare_attachment(%{data: data, filename: filename}, body) do
    Mail.put_attachment(body, {filename, data})
  end

  defp prepare_reply_to(body, %{reply_to: nil}), do: body
  defp prepare_reply_to(body, %{reply_to: reply_to}), do: Mail.put_reply_to(body, reply_to)
end
