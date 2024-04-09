defmodule Swoosh.Adapters.SocketLabs do
  @moduledoc ~S"""
  An adapter that sends email using the SocketLabs Injection API.

  For reference: [SocketLabs API docs](https://inject.docs.socketlabs.com/v1/documentation/introduction)

  **This adapter requires an API Client.** Swoosh comes with Hackney, Finch and Req out of the box.
  See the [installation section](https://hexdocs.pm/swoosh/Swoosh.html#module-installation)
  for details.

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer
        adapter: Swoosh.Adapters.SocketLabs,
        server_id: "",
        api_key: ""

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  ## Using with provider options

      import Swoosh.Email

      new()
      |> from({"Sisu", "sisu@example.com"})
      |> to("raya@example.com")
      |> put_provider_option(:api_template, "12345")
      |> put_provider_option(:charset, "12345")
      |> put_provider_option(:mailing_id, "12345")
      |> put_provider_option(:message_id, "12345")
      |> put_provider_option(:merge_data, %{
        "PerMessage" => %{
          "per_message1" => "value1",
          "per_message2" => "value2"
        },
        "Global" => %{
          "global1" => "value1",
          "global2" => "value2"
        }
      })

  ## Provider Options

    * `:api_template` (string) - `ApiTemplate`, identifier for a content in the
      Email Content Manager

    * `:charset` (string) - `Charset`, character set used when creating the
      email message and default to `UTF8`

    * `:mailing_id` (string) - special header used to track batches of email
      messages

    * `:message_id` (string) - special header used to track individual message

    * `:merge_data` (map) - data storage for inline Merge feature

  """

  use Swoosh.Adapter, required_config: [:server_id, :api_key]

  alias Swoosh.Email

  @base_url "https://inject.socketlabs.com/api/v1"
  @api_endpoint "/email"

  def deliver(%Email{} = email, config \\ []) do
    headers = [
      {"Content-Type", "application/json"},
      {"User-Agent", "swoosh/#{Swoosh.version()}"}
    ]

    authentication = %{
      "serverId" => config[:server_id],
      "APIKey" => config[:api_key]
    }

    messages = Map.put(%{}, "Messages", [prepare_messages(email)])

    body =
      messages
      |> Map.merge(authentication)
      |> Swoosh.json_library().encode!()

    url = [base_url(config), @api_endpoint]

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
    do: body |> Swoosh.json_library().decode! |> parse_response

  defp parse_response(%{
         "ErrorCode" => error_code,
         "MessageResults" => results,
         "TransactionReceipt" => receipt
       }),
       do: %{response_code: error_code, message_results: results, receipt: receipt}

  defp base_url(config), do: config[:base_url] || @base_url

  defp prepare_messages(email) do
    %{}
    |> prepare_from(email)
    |> prepare_to(email)
    |> prepare_cc(email)
    |> prepare_bcc(email)
    |> prepare_subject(email)
    |> prepare_text(email)
    |> prepare_html(email)
    |> prepare_attachments(email)
    |> prepare_reply_to(email)
    |> prepare_api_template(email)
    |> prepare_message_id(email)
    |> prepare_mailing_id(email)
    |> prepare_charset(email)
    |> prepare_custom_headers(email)
    |> prepare_merge_data(email)
  end

  defp prepare_item({nil, address}), do: %{"emailAddress" => address}
  defp prepare_item({"", address}), do: prepare_item(address)
  defp prepare_item({name, address}), do: %{"friendlyName" => name, "emailAddress" => address}
  defp prepare_item(address), do: prepare_item({nil, address})

  defp prepare_from(body, %{from: from}), do: Map.put(body, "From", prepare_item(from))

  defp prepare_to(body, %{to: []}), do: body
  defp prepare_to(body, %{to: to}), do: prepare_recipients(body, to, "To")

  defp prepare_cc(body, %{cc: []}), do: body
  defp prepare_cc(body, %{cc: cc}), do: prepare_recipients(body, cc, "CC")

  defp prepare_bcc(body, %{bcc: []}), do: body
  defp prepare_bcc(body, %{bcc: bcc}), do: prepare_recipients(body, bcc, "BCC")

  defp prepare_recipients(body, recipients, type) do
    recipients = Enum.map(recipients, &prepare_item/1)

    Map.put(body, type, recipients)
  end

  defp prepare_subject(body, %{subject: subject}), do: Map.put(body, "Subject", subject)

  defp prepare_text(body, %{text_body: nil}), do: body
  defp prepare_text(body, %{text_body: text_body}), do: Map.put(body, "TextBody", text_body)

  defp prepare_html(body, %{html_body: nil}), do: body
  defp prepare_html(body, %{html_body: html_body}), do: put_in(body, ["HtmlBody"], html_body)

  defp prepare_attachments(body, %{attachments: []}), do: body

  defp prepare_attachments(body, %{attachments: attachments}) do
    attachments =
      Enum.map(attachments, fn attachment ->
        %{
          "Name" => attachment.filename,
          "ContentType" => attachment.content_type,
          "Content" => Swoosh.Attachment.get_content(attachment, :base64),
          "ContentId" => attachment.filename
        }
      end)

    Map.put(body, "Attachments", attachments)
  end

  defp prepare_reply_to(body, %{reply_to: nil}), do: body

  defp prepare_reply_to(body, %{reply_to: reply_to}),
    do: Map.put(body, "ReplyTo", prepare_item(reply_to))

  defp prepare_api_template(body, %{provider_options: %{api_template: api_template}}) do
    Map.put(body, "ApiTemplate", api_template)
  end

  defp prepare_api_template(body, _), do: body

  defp prepare_message_id(body, %{provider_options: %{message_id: message_id}}) do
    Map.put(body, "MessageId", message_id)
  end

  defp prepare_message_id(body, _), do: body

  defp prepare_mailing_id(body, %{provider_options: %{mailing_id: mailing_id}}) do
    Map.put(body, "MailingId", mailing_id)
  end

  defp prepare_mailing_id(body, _), do: body

  defp prepare_charset(body, %{provider_options: %{charset: charset}}) do
    Map.put(body, "Charset", charset)
  end

  defp prepare_charset(body, _), do: body

  defp prepare_custom_headers(body, %{headers: headers}) when map_size(headers) == 0, do: body

  defp prepare_custom_headers(body, %{headers: headers}) do
    custom_headers = Map.merge(body[:headers] || %{}, headers)
    Map.put(body, "CustomHeaders", custom_headers)
  end

  defp prepare_merge_data(body, %{provider_options: %{merge_data: merge_data}}) do
    Map.put(body, "MergeData", merge_data)
  end

  defp prepare_merge_data(body, _), do: body
end
