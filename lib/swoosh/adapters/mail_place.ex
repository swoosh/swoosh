defmodule Swoosh.Adapters.MailPace do
  @moduledoc ~S"""

  An adapter that sends email using the MailPace API.

  For reference: [MailPace API docs](https://docs.mailpace.com/reference/overview/)

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.MailPace,
        api_key: "my-api-key"

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end
  """

  use Swoosh.Adapter, required_config: [:api_key]

  alias Swoosh.Email
  import Swoosh.Email.Render

  @endpoint "https://app.mailpace.com/api/v1/send"

  @impl true
  def deliver(%Email{} = email, config \\ []) do
    headers = prepare_headers(config)
    params = email |> prepare_body() |> Swoosh.json_library().encode!

    case Swoosh.ApiClient.post(endpoint(config), headers, params, email) do
      {:ok, 200, _headers, body} ->
        {:ok, Swoosh.json_library().decode!(body)}

      {:ok, code, _headers, body} when code > 399 ->
        case Swoosh.json_library().decode(body) do
          {:ok, error} -> {:error, {code, error}}
          {:error, _} -> {:error, {code, body}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp prepare_headers(config) do
    [
      {"User-Agent", "swoosh/#{Swoosh.version()}"},
      {"MailPace-Server-Token", config[:api_key]},
      {"Content-Type", "application/json"},
      {"Accept", "application/json"}
    ]
  end

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
  end

  defp prepare_from(body, %{from: from}), do: Map.put(body, "from", render_recipient(from))

  defp prepare_to(body, %{to: to}), do: Map.put(body, "to", render_recipient(to))

  defp prepare_cc(body, %{cc: []}), do: body
  defp prepare_cc(body, %{cc: cc}), do: Map.put(body, "cc", render_recipient(cc))

  defp prepare_bcc(body, %{bcc: []}), do: body
  defp prepare_bcc(body, %{bcc: bcc}), do: Map.put(body, "bcc", render_recipient(bcc))

  defp prepare_reply_to(body, %{reply_to: nil}), do: body

  defp prepare_reply_to(body, %{reply_to: reply_to_recipient}),
    do: Map.put(body, "replyto", render_recipient(reply_to_recipient))

  defp prepare_subject(body, %{subject: ""}), do: body
  defp prepare_subject(body, %{subject: subject}), do: Map.put(body, "subject", subject)

  defp prepare_text(body, %{text_body: nil}), do: body
  defp prepare_text(body, %{text_body: text_body}), do: Map.put(body, "textbody", text_body)

  defp prepare_html(body, %{html_body: nil}), do: body
  defp prepare_html(body, %{html_body: html_body}), do: Map.put(body, "htmlbody", html_body)

  defp prepare_attachments(body, %{attachments: []}), do: body

  defp prepare_attachments(body, %{attachments: attachments}) do
    attachments =
      Enum.map(attachments, fn %{content_type: content_type, filename: name} = attachment ->
        attachment_object = %{
          name: name,
          content: Swoosh.Attachment.get_content(attachment, :base64),
          content_type: content_type
        }

        if attachment.type == :inline do
          Map.put(attachment_object, :cid, attachment.cid)
        else
          attachment_object
        end
      end)

    Map.put(body, "attachments", attachments)
  end

  defp endpoint(config), do: config[:endpoint] || @endpoint
end
