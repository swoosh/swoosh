defmodule Swoosh.Adapters.Lettermint do
  @moduledoc ~S"""
  An adapter that sends email using the Lettermint API.

  For reference: [Lettermint API docs](https://docs.lettermint.co/api-reference/endpoint/send)

  **This adapter requires an API Client.** Swoosh comes with Hackney, Finch and Req out of the box.
  See the [installation section](https://hexdocs.pm/swoosh/Swoosh.html#module-installation)
  for details.

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Lettermint,
        api_token: "my-api-token"

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  ## Using with provider options

      import Swoosh.Email

      new()
      |> from("nora@example.com")
      |> to("shushu@example.com")
      |> subject("Hello, Wally!")
      |> text_body("Hello")
      |> put_provider_option(:metadata, %{campaign: "welcome"})
      |> put_provider_option(:idempotency_key, "unique-key-123")

  ## Provider Options

    * `metadata` (map) - Custom tracking metadata
    * `idempotency_key` (string) - Unique key to prevent duplicate sends

  """

  use Swoosh.Adapter, required_config: [:api_token]

  alias Swoosh.Email

  @base_url "https://api.lettermint.co/v1"
  @api_endpoint "/send"

  defp base_url(config), do: config[:base_url] || @base_url

  def deliver(%Email{} = email, config \\ []) do
    headers = prepare_headers(config, email)
    body = email |> prepare_payload() |> Swoosh.json_library().encode!
    url = [base_url(config), @api_endpoint]

    case Swoosh.ApiClient.post(url, headers, body, email) do
      {:ok, 202, _headers, body} ->
        case Swoosh.json_library().decode(body) do
          {:ok, %{"message_id" => message_id, "status" => status}} ->
            {:ok, %{id: message_id, status: status}}

          {:ok, response} ->
            {:ok, %{id: Map.get(response, "message_id"), status: Map.get(response, "status")}}

          {:error, _} ->
            {:error, {202, body}}
        end

      {:ok, code, _headers, body} when code >= 400 ->
        case Swoosh.json_library().decode(body) do
          {:ok, error} -> {:error, {code, error}}
          {:error, _} -> {:error, {code, body}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp prepare_headers(config, email) do
    base_headers = [
      {"Accept", "application/json"},
      {"Content-Type", "application/json"},
      {"User-Agent", "swoosh/#{Swoosh.version()}"},
      {"x-lettermint-token", config[:api_token]}
    ]

    case get_idempotency_key(email) do
      nil -> base_headers
      key -> [{"Idempotency-Key", key} | base_headers]
    end
  end

  defp get_idempotency_key(%{provider_options: %{idempotency_key: key}}), do: key
  defp get_idempotency_key(_), do: nil

  defp prepare_payload(email) do
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
    |> prepare_metadata(email)
    |> prepare_attachments(email)
  end

  defp prepare_from(payload, %{from: from}), do: Map.put(payload, "from", format_email(from))

  defp prepare_to(payload, %{to: to}) do
    Map.put(payload, "to", Enum.map(to, &format_email/1))
  end

  defp prepare_cc(payload, %{cc: []}), do: payload

  defp prepare_cc(payload, %{cc: cc}) do
    Map.put(payload, "cc", Enum.map(cc, &format_email/1))
  end

  defp prepare_bcc(payload, %{bcc: []}), do: payload

  defp prepare_bcc(payload, %{bcc: bcc}) do
    Map.put(payload, "bcc", Enum.map(bcc, &format_email/1))
  end

  defp prepare_reply_to(payload, %{reply_to: nil}), do: payload

  defp prepare_reply_to(payload, %{reply_to: reply_to}) do
    Map.put(payload, "reply_to", [format_email(reply_to)])
  end

  defp prepare_subject(payload, %{subject: ""}), do: payload

  defp prepare_subject(payload, %{subject: subject}),
    do: Map.put(payload, "subject", subject)

  defp prepare_subject(payload, _), do: payload

  defp prepare_text_content(payload, %{text_body: nil}), do: payload

  defp prepare_text_content(payload, %{text_body: text_content}) do
    Map.put(payload, "text", text_content)
  end

  defp prepare_html_content(payload, %{html_body: nil}), do: payload

  defp prepare_html_content(payload, %{html_body: html_content}) do
    Map.put(payload, "html", html_content)
  end

  defp prepare_email_headers(payload, %{headers: map}) when map_size(map) == 0, do: payload

  defp prepare_email_headers(payload, %{headers: headers}) do
    Map.put(payload, "headers", headers)
  end

  defp prepare_metadata(payload, %{provider_options: %{metadata: metadata}})
       when is_map(metadata) do
    Map.put(payload, "metadata", metadata)
  end

  defp prepare_metadata(payload, _), do: payload

  defp prepare_attachments(payload, %{attachments: []}), do: payload

  defp prepare_attachments(payload, %{attachments: attachments}) do
    Map.put(
      payload,
      "attachments",
      Enum.map(
        attachments,
        &%{
          filename: &1.filename,
          content: Swoosh.Attachment.get_content(&1, :base64)
        }
      )
    )
  end

  defp format_email({name, email}) when name in [nil, ""], do: email
  defp format_email({name, email}), do: "#{name} <#{email}>"
  defp format_email(email) when is_binary(email), do: email
end
