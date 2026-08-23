defmodule Swoosh.Adapters.TurboSMTP do
  @moduledoc ~S"""
  An adapter that sends email using the TurboSMTP API.

  For reference: [TurboSMTP API docs](https://serversmtp.com/turbo-api/)

  **This adapter requires an API Client.** Swoosh comes with Hackney, Finch and Req out of the box.
  See the [installation section](https://hexdocs.pm/swoosh/Swoosh.html#module-installation)
  for details.

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.TurboSMTP,
        consumer_key: "my-consumer-key",
        consumer_secret: "my-consumer-secret"

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  ## Sending from the EU region

  TurboSMTP serves the EU from a separate host. Point `base_url` at it:

      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.TurboSMTP,
        consumer_key: "my-consumer-key",
        consumer_secret: "my-consumer-secret",
        base_url: "https://api.eu.turbo-smtp.com/api/v2"

  ## Inline images

  Use Swoosh's usual inline attachments. The adapter takes care of a TurboSMTP
  quirk on the way out: the API builds each inline part's Content-ID as
  `<content_id@sender-domain>`, so a bare `cid:` reference never matches and the
  image arrives as an ordinary attachment. References are qualified with the
  sender's domain automatically, so this renders inline:

      import Swoosh.Email

      new()
      |> from("nora@example.com")
      |> to("shushu@example.com")
      |> subject("Hello, Wally!")
      |> html_body(~s|<img src="cid:logo.png">|)
      |> attachment(Swoosh.Attachment.new("/data/logo.png", type: :inline))

  A `cid` that already carries a domain is left alone.

  ## Using with provider options

      import Swoosh.Email

      new()
      |> from("nora@example.com")
      |> to("shushu@example.com")
      |> subject("Hello, Wally!")
      |> text_body("Hello")
      |> put_provider_option(:reference_id, "3a1f9d7e-0c4b-4f3a-9c1e-2b6d5a7f8e90")
      |> put_provider_option(:campaign_id, "welcome-2024")

  ## Provider Options

    * `reference_id` (string) - `reference_id`, a UUID of your own that TurboSMTP
      echoes back on delivery events
    * `campaign_id` (string) - `X-campaign-ID`, groups sends in the dashboard
    * `mime_raw` (string) - `mime_raw`, a complete MIME message to send verbatim

  ## Display names in recipients

  TurboSMTP splits `to`, `cc` and `bcc` on commas before it parses RFC 5322
  quoted strings, so a comma inside a recipient's display name is torn apart and
  the send is rejected. The adapter returns `{:error, {:invalid_recipient, name}}`
  for that case rather than letting the API answer with a parse error naming a
  fragment of the name. `from` and `reply_to` are not comma-split and accept it.
  """

  use Swoosh.Adapter, required_config: [:consumer_key, :consumer_secret]

  alias Swoosh.Attachment
  alias Swoosh.Email

  @base_url "https://api.turbo-smtp.com/api/v2"
  @api_endpoint "/mail/send"

  defp base_url(config), do: config[:base_url] || @base_url

  def deliver(%Email{} = email, config \\ []) do
    with {:ok, payload} <- prepare_payload(email) do
      headers = prepare_headers(config)
      body = Swoosh.json_library().encode!(payload)
      url = [base_url(config), @api_endpoint]

      case Swoosh.ApiClient.post(url, headers, body, email) do
        {:ok, code, _headers, body} when code in 200..299 ->
          handle_success(code, body)

        {:ok, code, _headers, body} ->
          {:error, {code, decode_body(body)}}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp handle_success(code, body) do
    case Swoosh.json_library().decode(body) do
      {:ok, %{"mid" => mid}} -> {:ok, %{id: to_string(mid)}}
      {:ok, response} -> {:ok, response}
      {:error, _} -> {:error, {code, body}}
    end
  end

  defp decode_body(body) do
    case Swoosh.json_library().decode(body) do
      {:ok, decoded} -> decoded
      {:error, _} -> body
    end
  end

  defp prepare_headers(config) do
    [
      {"Accept", "application/json"},
      {"Content-Type", "application/json"},
      {"User-Agent", "swoosh/#{Swoosh.version()}"},
      {"consumerKey", config[:consumer_key]},
      {"consumerSecret", config[:consumer_secret]}
    ]
  end

  defp prepare_payload(email) do
    with {:ok, payload} <- prepare_recipients(%{}, email) do
      payload =
        payload
        |> prepare_from(email)
        |> prepare_subject(email)
        |> prepare_content(email)
        |> prepare_custom_headers(email)
        |> prepare_attachments(email)
        # qualify_inline_cids reads payload["attachments"], so it must run after
        # prepare_attachments — otherwise cids are silently left unqualified.
        |> qualify_inline_cids(email)
        |> prepare_provider_options(email)

      {:ok, payload}
    end
  end

  defp prepare_from(payload, %{from: from}), do: Map.put(payload, "from", format_email(from))

  defp prepare_recipients(payload, email) do
    fields = [{"to", email.to}, {"cc", email.cc}, {"bcc", email.bcc}]

    Enum.reduce_while(fields, {:ok, payload}, fn
      {_field, []}, acc ->
        {:cont, acc}

      {field, recipients}, {:ok, payload} ->
        case join_recipients(recipients) do
          {:ok, joined} -> {:cont, {:ok, Map.put(payload, field, joined)}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
    end)
  end

  defp join_recipients(recipients) do
    case Enum.find(recipients, &comma_in_display_name?/1) do
      nil -> {:ok, Enum.map_join(recipients, ",", &format_email/1)}
      {name, _address} -> {:error, {:invalid_recipient, name}}
    end
  end

  defp comma_in_display_name?({name, _address}) when is_binary(name),
    do: String.contains?(name, ",")

  defp comma_in_display_name?(_recipient), do: false

  defp prepare_subject(payload, %{subject: nil}), do: payload
  defp prepare_subject(payload, %{subject: ""}), do: payload
  defp prepare_subject(payload, %{subject: subject}), do: Map.put(payload, "subject", subject)

  defp prepare_content(payload, email) do
    payload
    |> put_unless_nil("content", email.text_body)
    |> put_unless_nil("html_content", email.html_body)
  end

  defp prepare_custom_headers(payload, email) do
    case custom_headers(email) do
      headers when map_size(headers) == 0 -> payload
      headers -> Map.put(payload, "custom_headers", headers)
    end
  end

  defp custom_headers(%{headers: headers, reply_to: nil}), do: headers

  defp custom_headers(%{headers: headers, reply_to: reply_to}) when is_list(reply_to) do
    Map.put(headers, "Reply-To", Enum.map_join(reply_to, ",", &format_email/1))
  end

  defp custom_headers(%{headers: headers, reply_to: reply_to}) do
    Map.put(headers, "Reply-To", format_email(reply_to))
  end

  defp prepare_attachments(payload, %{attachments: []}), do: payload

  defp prepare_attachments(payload, %{attachments: attachments}) do
    Map.put(payload, "attachments", Enum.map(attachments, &prepare_attachment/1))
  end

  defp prepare_attachment(%Attachment{} = attachment) do
    prepared = %{
      "name" => attachment.filename,
      "type" => attachment.content_type,
      "content" => Attachment.get_content(attachment, :base64)
    }

    case attachment.type do
      :inline -> Map.put(prepared, "content_id", attachment.cid || attachment.filename)
      _ -> prepared
    end
  end

  # Without this the send still succeeds and the image just arrives as an ordinary
  # attachment, so the bug is invisible until someone opens the mail.
  defp qualify_inline_cids(%{"html_content" => html} = payload, %{from: from})
       when is_binary(html) do
    case sender_domain(from) do
      nil -> payload
      domain -> Map.put(payload, "html_content", qualify(html, payload["attachments"], domain))
    end
  end

  defp qualify_inline_cids(payload, _email), do: payload

  defp qualify(html, nil, _domain), do: html

  defp qualify(html, attachments, domain) do
    attachments
    |> Enum.map(& &1["content_id"])
    |> Enum.reject(&(is_nil(&1) or String.contains?(&1, "@")))
    |> case do
      [] ->
        html

      cids ->
        alternation = Enum.map_join(cids, "|", &Regex.escape/1)
        pattern = Regex.compile!("cid:(#{alternation})(?![\\w.@-])")
        Regex.replace(pattern, html, "cid:\\1@#{domain}")
    end
  end

  defp sender_domain(from) do
    {_name, address} = normalize_email(from)

    case String.split(address, "@") do
      [_local, domain] when domain != "" -> domain
      _ -> nil
    end
  end

  defp prepare_provider_options(payload, %{provider_options: options}) do
    payload
    |> put_unless_nil("reference_id", options[:reference_id])
    |> put_unless_nil("X-campaign-ID", options[:campaign_id])
    |> put_unless_nil("mime_raw", options[:mime_raw])
  end

  defp put_unless_nil(payload, _key, nil), do: payload
  defp put_unless_nil(payload, key, value), do: Map.put(payload, key, value)

  defp format_email(email) do
    case normalize_email(email) do
      {name, address} when name in [nil, ""] -> address
      {name, address} -> "#{name} <#{address}>"
    end
  end

  defp normalize_email({name, address}), do: {name, address}
  defp normalize_email(address) when is_binary(address), do: {nil, address}
end
