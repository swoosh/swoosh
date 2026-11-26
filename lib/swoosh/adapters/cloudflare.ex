defmodule Swoosh.Adapters.Cloudflare do
  @moduledoc ~S"""
  An adapter that sends email using the [Cloudflare Email Sending REST API](https://developers.cloudflare.com/email-service/api/send-emails/rest-api/).

  Enable [Email Sending](https://developers.cloudflare.com/email-service/get-started/send-emails/)
  for your sender domain and create a Cloudflare API token with the Email Sending
  Write permission for your account. This adapter uses a configured Swoosh API
  client. See the [installation section](https://hexdocs.pm/swoosh/Swoosh.html#module-installation).

  ## Example

      # config/runtime.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Cloudflare,
        account_id: System.fetch_env!("CLOUDFLARE_ACCOUNT_ID"),
        api_token: System.fetch_env!("CLOUDFLARE_API_TOKEN")

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  Set a subject and include a text or HTML body. Cloudflare supports a single
  reply-to address. An email with multiple reply-to addresses returns
  `{:error, :multiple_reply_to_not_supported}`.

  Give each attachment a filename. A missing or empty filename returns
  `{:error, :attachment_filename_required}`. Cloudflare applies its
  [email header rules](https://developers.cloudflare.com/email-service/reference/headers/)
  and [sending limits](https://developers.cloudflare.com/email-service/platform/limits/)
  to each request.

  ## Delivery results

  A successful API request returns `{:ok, result}`. The result contains the
  message ID under `:id` when Cloudflare provides one, plus the recipient lists
  under `:delivered`, `:queued`, `:permanent_bounces`, and
  `:suppressed_recipients`. Inspect these lists for individual delivery outcomes.

  An HTTP or API failure returns `{:error, {status, body}}`. The body is decoded
  when it contains valid JSON. Transport errors are returned by the API client.
  """

  @behaviour Swoosh.Adapter

  alias Swoosh.Attachment
  alias Swoosh.Email

  @base_url "https://api.cloudflare.com"

  @impl true
  def validate_config(config) do
    invalid_keys =
      Enum.reject([:account_id, :api_token], fn key ->
        value = config[key]
        is_binary(value) and value != ""
      end)

    case invalid_keys do
      [] -> :ok
      keys -> raise ArgumentError, "expected #{inspect(keys)} to be set to non-empty strings"
    end
  end

  @impl true
  def deliver(%Email{reply_to: [_, _ | _]}, _config) do
    {:error, :multiple_reply_to_not_supported}
  end

  def deliver(%Email{} = email, config) do
    with :ok <- validate_attachment_filenames(email.attachments) do
      base_url = config[:base_url] || @base_url
      url = "#{base_url}/client/v4/accounts/#{config[:account_id]}/email/sending/send"

      headers = [
        {"Accept", "application/json"},
        {"Content-Type", "application/json"},
        {"Authorization", "Bearer #{config[:api_token]}"}
      ]

      body = email |> prepare_payload() |> Swoosh.json_library().encode!()

      url
      |> Swoosh.ApiClient.post(headers, body, email)
      |> handle_response()
    end
  end

  defp prepare_payload(email) do
    reply_to = email.reply_to |> List.wrap() |> List.first()

    %{from: format_address(email.from), subject: email.subject}
    |> put_field(:to, Enum.map(email.to, &format_address/1))
    |> put_field(:cc, Enum.map(email.cc, &format_address/1))
    |> put_field(:bcc, Enum.map(email.bcc, &format_address/1))
    |> put_field(:reply_to, format_address(reply_to))
    |> put_field(:text, email.text_body)
    |> put_field(:html, email.html_body)
    |> put_field(:headers, email.headers)
    |> put_field(:attachments, Enum.map(email.attachments, &format_attachment/1))
  end

  defp put_field(payload, _, value) when value in [nil, [], %{}], do: payload
  defp put_field(payload, key, value), do: Map.put(payload, key, value)

  defp format_address(nil), do: nil
  defp format_address({name, address}) when name in [nil, ""], do: address
  defp format_address({name, address}), do: %{address: address, name: name}

  defp validate_attachment_filenames(attachments) do
    if Enum.all?(attachments, fn %{filename: name} -> is_binary(name) and name != "" end) do
      :ok
    else
      {:error, :attachment_filename_required}
    end
  end

  defp format_attachment(attachment) do
    payload = %{
      content: Attachment.get_content(attachment, :base64),
      disposition: Atom.to_string(attachment.type),
      filename: attachment.filename,
      type: attachment.content_type || MIME.from_path(attachment.filename)
    }

    case attachment.type do
      :inline -> Map.put(payload, :content_id, attachment.cid || attachment.filename)
      :attachment -> payload
    end
  end

  defp handle_response({:ok, status, _headers, body}) do
    case Swoosh.json_library().decode(body) do
      {:ok, decoded} -> handle_decoded_response(status, decoded)
      {:error, _reason} -> {:error, {status, body}}
    end
  end

  defp handle_response({:error, reason}), do: {:error, reason}

  defp handle_decoded_response(status, %{"success" => true, "result" => result} = response)
       when status in 200..299 do
    with %{"delivered" => delivered, "queued" => queued, "permanent_bounces" => bounces}
         when is_list(delivered) and is_list(queued) and is_list(bounces) <- result,
         suppressed when is_list(suppressed) <- Map.get(result, "suppressed_recipients", []),
         id when is_binary(id) or is_nil(id) <- result["message_id"] do
      {:ok,
       %{
         id: id,
         delivered: delivered,
         queued: queued,
         permanent_bounces: bounces,
         suppressed_recipients: suppressed
       }}
    else
      _ -> {:error, {status, response}}
    end
  end

  defp handle_decoded_response(status, response), do: {:error, {status, response}}
end
