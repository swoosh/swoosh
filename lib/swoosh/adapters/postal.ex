defmodule Swoosh.Adapters.Postal do
  @moduledoc ~S"""
  An adapter that sends email using the Postal API.
  [Postal](https://docs.postalserver.io/) is open-source, self-hosted mail delivery platform.

  For reference: [Postal API docs](https://apiv1.postalserver.io/)

  **This adapter requires an API Client.** Swoosh comes with Hackney, Finch and Req out of the box.
  See the [installation section](https://hexdocs.pm/swoosh/Swoosh.html#module-installation)
  for details.

  ## Configuration options

  * `:api_key` - Postal API key.
  * `:base_url` - Base URL where Postal server is running.

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Postal,
        api_key: "my-api-key",
        base_url: "https://my-postal-server.com/"

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  ## Using with provider options

      import Swoosh.Email

      new()
      |> from({"T Stark", "tony.stark@example.com"})
      |> to({"Steve Rogers", "steve.rogers@example.com"})
      |> to("wasp.avengers@example.com")
      |> reply_to("office.avengers@example.com")
      |> cc({"Bruce Banner", "hulk.smash@example.com"})
      |> cc("thor.odinson@example.com")
      |> bcc({"Clinton Francis Barton", "hawk.eye@example.com"})
      |> bcc("beast.avengers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")
      |> put_provider_option(:tag, "avengers")
      |> put_provider_option(:bounce, true)
  """

  use Swoosh.Adapter,
    required_config: [:api_key, :base_url]

  alias Swoosh.Attachment
  alias Swoosh.Email
  import Swoosh.Email.Render

  @api_endpoint "/api/v1/send/message"

  @impl true
  def deliver(%Email{} = email, config \\ []) do
    body = prepare_body(email) |> Swoosh.json_library().encode!
    headers = prepare_headers(config)
    url = [base_url(config), @api_endpoint]

    case Swoosh.ApiClient.post(url, headers, body, email) do
      {:ok, 200, _headers, body} ->
        case Swoosh.json_library().decode!(body) do
          %{"status" => "success", "data" => data} ->
            {:ok, %{id: data["message_id"]}}

          %{"status" => _, "data" => data} ->
            {:error, {data["code"], data["message"]}}
        end

      {:ok, code, _headers, body} when code > 399 ->
        case Swoosh.json_library().decode(body) do
          {:ok, error} -> {:error, {code, error}}
          {:error, _} -> {:error, {code, body}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp base_url(config), do: config[:base_url]

  defp prepare_headers(config) do
    [
      {"User-Agent", "swoosh/#{Swoosh.version()}"},
      {"Content-Type", "application/json"},
      {"Accept", "application/json"},
      {"X-Server-API-Key", config[:api_key]}
    ]
  end

  defp prepare_body(%Email{} = email) do
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
    |> prepare_tag(email)
    |> prepare_bounce(email)
    |> prepare_custom_headers(email)
  end

  defp prepare_from(body, %Email{from: from}),
    do: Map.put(body, :from, render_recipient(from))

  defp prepare_to(body, %Email{to: to}),
    do: Map.put(body, :to, Enum.map(to, &render_recipient(&1)))

  defp prepare_cc(body, %Email{cc: []}), do: body

  defp prepare_cc(body, %Email{cc: cc}),
    do: Map.put(body, :cc, Enum.map(cc, &render_recipient(&1)))

  defp prepare_bcc(body, %Email{bcc: []}), do: body

  defp prepare_bcc(body, %Email{bcc: bcc}),
    do: Map.put(body, :bcc, Enum.map(bcc, &render_recipient(&1)))

  defp prepare_reply_to(body, %Email{reply_to: nil}), do: body

  defp prepare_reply_to(body, %Email{reply_to: reply_to}),
    do: Map.put(body, :reply_to, render_recipient(reply_to))

  defp prepare_subject(body, %Email{subject: subject}),
    do: Map.put(body, :subject, subject)

  defp prepare_text(body, %Email{text_body: nil}), do: body
  defp prepare_text(body, %Email{text_body: text_body}), do: Map.put(body, :plain_body, text_body)

  defp prepare_html(body, %Email{html_body: nil}), do: body
  defp prepare_html(body, %Email{html_body: html_body}), do: Map.put(body, :html_body, html_body)

  defp prepare_tag(body, %Email{provider_options: %{tag: tag}}), do: Map.put(body, :tag, tag)
  defp prepare_tag(body, _), do: body

  defp prepare_bounce(body, %Email{provider_options: %{bounce: bounce}}) when is_boolean(bounce),
    do: Map.put(body, :bounce, bounce)

  defp prepare_bounce(body, _), do: body

  defp prepare_custom_headers(body, %{headers: headers}) when map_size(headers) != 0,
    do: Map.put(body, :headers, headers)

  defp prepare_custom_headers(body, _), do: body

  defp prepare_attachments(body, %Email{attachments: []}), do: body

  defp prepare_attachments(body, %Email{attachments: attachments}),
    do: Map.put(body, :attachments, Enum.map(attachments, &prepare_attachment(&1)))

  defp prepare_attachment(%Attachment{} = attachment) do
    %{
      name: attachment.filename,
      content_type: attachment.content_type,
      data: Swoosh.Attachment.get_content(attachment, :base64)
    }
  end
end
