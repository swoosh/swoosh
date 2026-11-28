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

  Set `:base_url` to send requests to a different host. It defaults to
  `https://api.cloudflare.com`. Leave out the `/client/v4` path, which the adapter
  appends.

  Set a subject and include a text or HTML body. Cloudflare supports a single
  reply-to address. An email with multiple reply-to addresses returns
  `{:error, :multiple_reply_to_not_supported}`.

  Set From, To, Cc, Bcc, Subject, and Reply-To through their corresponding
  `Swoosh.Email` functions. Cloudflare rejects the entire request if you set
  any of these through `Swoosh.Email.header/3`, including an additional
  Reply-To address. See the
  [email header rules](https://developers.cloudflare.com/email-service/reference/headers/)
  for permitted custom headers.

  Give each attachment a filename. A missing or empty filename returns
  `{:error, :attachment_filename_required}`. Cloudflare applies its
  [sending limits](https://developers.cloudflare.com/email-service/platform/limits/)
  to each request.

  ## Delivery results

  When Cloudflare reports acceptance, the adapter returns `{:ok, result}`.
  Inspect `:delivered`, `:queued`, `:permanent_bounces`, and
  `:suppressed_recipients` for individual outcomes. The result can be
  `{:ok, result}` even if every recipient bounced or was suppressed. Fields
  that Cloudflare omits or returns with an unexpected type default to `nil`
  for `:id` and `[]` for recipient lists.

  If a 2xx response cannot be read or has no explicit success flag, the adapter
  returns `{:error, {:acceptance_unknown, status, body}}`. Check Cloudflare's
  activity log before retrying because the first request may have sent the email.

  An HTTP or API failure returns `{:error, {status, body}}`. The body is decoded
  when it contains valid JSON. Transport errors are returned by the API client.

  A 5xx response or a transport error, such as a receive timeout, can also happen
  after Cloudflare has accepted the email. Check the activity log before retrying
  these too.
  """

  @behaviour Swoosh.Adapter

  alias Swoosh.Attachment
  alias Swoosh.Email

  @base_url "https://api.cloudflare.com"

  @impl true
  def validate_config(config) do
    invalid_keys =
      Enum.reject([:account_id, :api_token], fn key -> valid_config?(key, config[key]) end)

    case invalid_keys do
      [] ->
        :ok

      keys ->
        raise ArgumentError,
              "expected #{inspect(keys)} to be set to non-empty strings " <>
                "(#{Enum.map_join(keys, "; ", &config_rule/1)})"
    end
  end

  defp valid_config?(:account_id, value) do
    is_binary(value) and Regex.match?(~r/\A[a-zA-Z0-9_-]+\z/, value)
  end

  # HTTP clients can echo a rejected header value, token included, in their errors
  defp valid_config?(:api_token, value) do
    is_binary(value) and Regex.match?(~r/\A[!-~]+\z/, value)
  end

  defp config_rule(:account_id) do
    "account_id may contain only ASCII letters, digits, hyphens, and underscores"
  end

  defp config_rule(:api_token) do
    "api_token may contain only printable ASCII characters without whitespace"
  end

  @impl true
  def deliver(%Email{reply_to: [_, _ | _]}, _config) do
    {:error, :multiple_reply_to_not_supported}
  end

  def deliver(%Email{} = email, config) do
    with :ok <- validate_attachment_filenames(email.attachments) do
      url = "#{base_url(config)}/client/v4/accounts/#{config[:account_id]}/email/sending/send"

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

  defp base_url(config) do
    case String.trim_trailing(config[:base_url] || "", "/") do
      "" -> @base_url
      base_url -> base_url
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
      {:ok, %{"success" => true} = response} when status in 200..299 ->
        {:ok, delivery_outcomes(response["result"])}

      {:ok, %{"success" => false} = response} ->
        {:error, {status, response}}

      {:ok, decoded} ->
        response_error(status, decoded)

      {:error, _reason} ->
        response_error(status, body)
    end
  end

  defp handle_response({:error, reason}), do: {:error, reason}

  defp response_error(status, body) when status in 200..299 do
    {:error, {:acceptance_unknown, status, body}}
  end

  defp response_error(status, body), do: {:error, {status, body}}

  defp delivery_outcomes(result) when is_map(result) do
    id = result["message_id"]

    %{
      id: if(is_binary(id), do: id),
      delivered: recipient_list(result["delivered"]),
      queued: recipient_list(result["queued"]),
      permanent_bounces: recipient_list(result["permanent_bounces"]),
      suppressed_recipients: recipient_list(result["suppressed_recipients"])
    }
  end

  defp delivery_outcomes(_result), do: delivery_outcomes(%{})

  defp recipient_list(value) when is_list(value), do: Enum.filter(value, &is_binary/1)
  defp recipient_list(_value), do: []
end
