defmodule Swoosh.Adapters.Mailjet do
  @moduledoc ~S"""
  An adapter that sends email using the Mailjet API.

  For reference: [Mailjet API docs](https://dev.mailjet.com/guides/#send-api-v3-1)

  ## Dependency

  Mailjet adapter requires `Plug` to work properly.

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Mailjet,
        api_key: "my-api-key",
        secret: "my-secret-key"

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end
  """

  use Swoosh.Adapter, required_config: [:api_key, :secret], required_deps: [plug: Plug.Conn.Query]

  alias Swoosh.{Email, Attachment}

  @base_url "https://api.mailjet.com/v3.1"
  @api_endpoint "send"

  def deliver(%Email{} = email, config \\ []) do
    headers = prepare_headers(config)
    url = [base_url(config), "/", @api_endpoint]

    case :hackney.post(url, headers, prepare_body(email), [:with_body]) do
      {:ok, 200, _headers, body} ->
        {:ok, %{id: get_message_id(body)}}

      {:ok, error_code, _headers, body} when error_code >= 400 ->
        {:error, {error_code, Swoosh.json_library().decode!(body)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # MessageHref: https://api.mailjet.com/v3/REST/message/#{message_id}
  defp get_message_id(%{"Messages" => [%{"To" => [%{"MessageID" => message_id}]}]}) do
    message_id
  end
  defp get_message_id(body) when is_binary(body) do
    body
    |> Swoosh.json_library().decode!
    |> get_message_id
  end

  defp base_url(config), do: config[:base_url] || @base_url

  defp prepare_headers(config) do
    [
      {"User-Agent", "swoosh/#{Swoosh.version()}"},
      {"Authorization", "Basic #{auth(config)}"},
      {"Content-Type", "application/json"}
    ]
  end

  defp auth(config), do: Base.encode64("#{config[:api_key]}:#{config[:secret]}")

  defp prepare_body(email) do
    %{}
    |> prepare_from(email)
    |> prepare_to(email)
    |> prepare_subject(email)
    |> prepare_html(email)
    |> prepare_text(email)
    |> prepare_cc(email)
    |> prepare_bcc(email)
    |> prepare_reply_to(email)
    |> prepare_attachments(email)
    |> prepare_variables(email)
    |> prepare_template_id(email)
    |> prepare_custom_headers(email)
    |> wrap_into_messages
    |> Swoosh.json_library.encode!()
  end

  defp wrap_into_messages(body), do: %{Messages: [body]}

  defp prepare_custom_headers(body, %{headers: headers}), do: Map.put(body, "Headers", headers)

  defp prepare_attachments(body, %{attachments: []}), do: body
  defp prepare_attachments(body, %{attachments: attachments}) do
    {normal_attachments, inline_attachments} =
      Enum.split_with(attachments, fn %{type: type} -> type == :attachment end)

    body
    |> Map.put("Attachments", Enum.map(normal_attachments, &prepare_attachment/1))
    |> Map.put("InlinedAttachments", Enum.map(inline_attachments, &prepare_attachment/1))
  end

  defp prepare_attachment(attachment) do
    %{
      "ContentType" => attachment.content_type,
      "Filename" => attachment.filename,
      "Base64Content" => Attachment.get_content(attachment, :base64)
    }
  end

  defp prepare_recipients(recipients), do: Enum.map(recipients, &prepare_recipient(&1))

  defp prepare_recipient({name, address}), do: %{"Name" => name, "Email" => address}

  defp prepare_from(body, %{from: from}), do: Map.put(body, "From", prepare_recipient(from))

  defp prepare_to(body, %{to: to}), do: Map.put(body, "To", prepare_recipients(to))

  defp prepare_reply_to(body, %{reply_to: nil}), do: body
  defp prepare_reply_to(body, %{reply_to: reply_to}),
    do: Map.put(body, "ReplyTo", prepare_recipient(reply_to))

  defp prepare_cc(body, %{cc: []}), do: body
  defp prepare_cc(body, %{cc: cc}), do: Map.put(body, "Cc", prepare_recipients(cc))

  defp prepare_bcc(body, %{bcc: []}), do: body
  defp prepare_bcc(body, %{bcc: bcc}), do: Map.put(body, "Bcc", prepare_recipients(bcc))

  defp prepare_subject(body, %{subject: subject}), do: Map.put(body, "Subject", subject)

  defp prepare_text(body, %{text_body: nil}), do: body
  defp prepare_text(body, %{text_body: text_body}), do: Map.put(body, "TextPart", text_body)

  defp prepare_html(body, %{html_body: nil}), do: body
  defp prepare_html(body, %{html_body: html_body}), do: Map.put(body, "HTMLPart", html_body)

  defp prepare_variables(body, %{provider_options: %{variables: variables}}) do
    Map.put(body, "Variables", variables)
  end

  defp prepare_variables(body, _email), do: body

  defp prepare_template_id(body, %{provider_options: %{template_id: template_id}}) do
    body
    |> Map.put("TemplateID", template_id)
    |> Map.put("TemplateLanguage", true)
  end

  defp prepare_template_id(body, _email), do: body
end
