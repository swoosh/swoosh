defmodule Swoosh.Adapters.Mailpit do
  @moduledoc ~s"""
  An adapter that sends email to a self-hosted Mailpit server via its HTTP API.

  For reference: [Mailpit API docs](https://mailpit.axllent.org/docs/api-v1/)

  **This adapter requires an API Client.** Swoosh comes with Hackney, Finch and Req out of the box.
  See the [installation section](https://hexdocs.pm/swoosh/Swoosh.html#module-installation)
  for details.

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Mailpit,
        base_url: "https://mailpit.example.com",
        api_key: "YnJ...0Rw=="  # optional, for Basic Auth

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  ## Using with provider options

      import Swoosh.Email

      new()
      |> from({"Raife Hastings", "raife@example.com"})
      |> to({"Jed Haverford", "jed@example.com"})
      |> reply_to("raife.hastings@example.com")
      |> cc("eliza@example.com")
      |> cc({"Jules Landry", "jules@example.com"})
      |> bcc("james.reece@example.com")
      |> bcc({"Ben Edwards", "ben@example.com"})
      |> subject("Hello there")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")
      |> put_provider_option(:tags, ["welcome", "transactional"])

  ## Provider Options

  Supported provider options are the following:

  #### Inserted into request body

    * `:tags` (list of strings) - Mailpit tags
  """

  use Swoosh.Adapter, required_config: [:base_url]

  alias Swoosh.Email

  @api_endpoint "/api/v1/send"

  @provider_options_body_fields [:tags]

  def deliver(%Email{} = email, config \\ []) do
    headers = build_headers(config)
    body = email |> prepare_body() |> Swoosh.json_library().encode!()
    url = prepare_url(config)

    case Swoosh.ApiClient.post(url, headers, body, email) do
      {:ok, code, _headers, body} when code in 200..399 ->
        decoded = Swoosh.json_library().decode!(body)
        {:ok, %{id: decoded["ID"]}}

      {:ok, code, _headers, body} when code >= 400 ->
        case Swoosh.json_library().decode(body) do
          {:ok, error} -> {:error, {code, error}}
          {:error, _} -> {:error, {code, body}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp prepare_url(config), do: [base_url(config), @api_endpoint]

  defp base_url(config), do: config[:base_url]

  defp build_headers(config) do
    base = [
      {"Accept", "application/json"},
      {"Content-Type", "application/json"},
      {"User-Agent", "swoosh/#{Swoosh.version()}"}
    ]

    case config[:api_key] do
      api_key when is_binary(api_key) -> [{"Authorization", "Basic #{api_key}"} | base]
      _ -> base
    end
  end

  defp prepare_body(email) do
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
    |> prepare_custom_headers(email)
    |> prepare_provider_options(email)
  end

  defp recipient({name, email}) when is_binary(name) and name != "" and is_binary(email),
    do: %{"Email" => email, "Name" => name}

  defp recipient({_, email}) when is_binary(email),
    do: %{"Email" => email}

  defp recipient(email) when is_binary(email),
    do: %{"Email" => email}

  defp recipient_email({_, email}) when is_binary(email), do: email
  defp recipient_email(email) when is_binary(email), do: email
  defp recipient_email(_), do: nil

  defp prepare_from(body, %{from: from}),
    do: Map.put(body, "From", recipient(from))

  defp prepare_from(body, _), do: body

  defp prepare_to(body, %{to: to}) when is_list(to) and to != [],
    do: Map.put(body, "To", Enum.map(to, &recipient/1))

  defp prepare_to(body, _), do: body

  defp prepare_cc(body, %{cc: []}), do: body
  defp prepare_cc(body, %{cc: cc}), do: Map.put(body, "Cc", Enum.map(cc, &recipient/1))
  defp prepare_cc(body, _), do: body

  defp prepare_bcc(body, %{bcc: []}), do: body

  defp prepare_bcc(body, %{bcc: bcc}) do
    emails = Enum.flat_map(bcc, fn item -> [recipient_email(item)] end)
    Map.put(body, "Bcc", emails)
  end

  defp prepare_bcc(body, _), do: body

  defp prepare_subject(body, %{subject: subject}) when is_binary(subject),
    do: Map.put(body, "Subject", subject)

  defp prepare_subject(body, _), do: body

  defp prepare_text(body, %{text_body: nil}), do: body
  defp prepare_text(body, %{text_body: text}), do: Map.put(body, "Text", text)
  defp prepare_text(body, _), do: body

  defp prepare_html(body, %{html_body: nil}), do: body
  defp prepare_html(body, %{html_body: html}), do: Map.put(body, "HTML", html)
  defp prepare_html(body, _), do: body

  defp prepare_attachments(body, %{attachments: []}), do: body

  defp prepare_attachments(body, %{attachments: attachments}) do
    atts =
      Enum.map(attachments, fn attachment ->
        content = Swoosh.Attachment.get_content(attachment, :base64)

        att_map =
          %{
            "Filename" => attachment.filename,
            "Content" => content
          }
          |> maybe_put("ContentType", attachment.content_type)

        case attachment.type do
          :inline ->
            content_id = attachment.cid || attachment.filename
            Map.put(att_map, "ContentID", content_id)

          _ ->
            att_map
        end
      end)

    Map.put(body, "Attachments", atts)
  end

  defp prepare_attachments(body, _), do: body

  defp prepare_reply_to(body, %{reply_to: nil}), do: body

  defp prepare_reply_to(body, %{reply_to: reply_to}) do
    replies = List.wrap(reply_to)
    Map.put(body, "ReplyTo", Enum.map(replies, &recipient/1))
  end

  defp prepare_reply_to(body, _), do: body

  defp prepare_custom_headers(body, %{headers: headers}) when map_size(headers) == 0,
    do: body

  defp prepare_custom_headers(body, %{headers: headers}),
    do: Map.put(body, "Headers", headers)

  defp prepare_custom_headers(body, _), do: body

  defp prepare_provider_options(body, %{provider_options: opts}) do
    case Map.take(opts, @provider_options_body_fields) do
      map when map_size(map) > 0 -> Map.merge(body, map)
      _ -> body
    end
  end

  defp prepare_provider_options(body, _), do: body

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, _key, ""), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
