defmodule Swoosh.Adapters.CustomerIO do
  @moduledoc ~s"""
  An adapter that sends email using the CustomerIO API.

  For reference: [CustomerIO API docs](https://customer.io/docs/api/#tag/Transactional)

  **This adapter requires an API Client.** Swoosh comes with Hackney, Finch and Req out of the box.
  See the [installation section](https://hexdocs.pm/swoosh/Swoosh.html#module-installation)
  for details.

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.CustomerIO,
        api_key: "my-api-key"

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  ## Using with provider options

      import Swoosh.Email

      new()
      |> from({"Xu Shang-Chi", "xu.shangchi@example.com"})
      |> to({"Katy", "katy@example.com"})
      |> reply_to("xu.xialing@example.com")
      |> cc("yingli@example.com")
      |> cc({"Xu Wenwu", "xu.wenwu@example.com"})
      |> bcc("yingnan@example.com")
      |> bcc({"Jon Jon", "jonjon@example.com"})
      |> subject("Hello, Ten Rings!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")
      |> put_provider_option(:disable_css_preprocessing, true)
      |> put_provider_option(:disable_message_retention, true)
      |> put_provider_option(:fake_bcc, true)
      |> put_provider_option(:message_data, %{
        my_var: %{my_message_id: 123},
        my_other_var: %{my_other_id: 1, stuff: 2}
      })
      |> put_provider_option(:preheader, "this is the preview")
      |> put_provider_option(:queue_draft, true)
      |> put_provider_option(:send_at, 1617260400)
      |> put_provider_option(:send_to_unsubscribed, true)
      |> put_provider_option(:tracked, false)
      |> put_provider_option(:transactional_message_id, 44)


  ## Provider Options

  Supported provider options are the following:

  #### Inserted into request body

    * `:disable_css_preprocessing` (boolean) - Set to true to disable CSS preprocessing.
       This setting overrides the CSS preprocessing setting on the transactional_message_id
       as set in the user interface. Transactional emails have CSS preprocessing enabled by
       default.

    * `:disable_message_retention` (boolean) - If true, the message body is not
      retained in delivery history. Setting this value overrides the value set
      in the settings of your transactional_message_id.

    * `:identifiers` (map) - Identifies the person represented by your transactional
      message by one of, and only one of, id, email, or cio_id.

    * `:fake_bcc` (boolean) - If true, rather than sending true copies to BCC
      addresses, Customer.io sends a copy of the message with the subject line
      containing the recipient address(es).

    * `:message_data` (map) - An object containing the key-value pairs referenced
        using liquid in your message, see `:transactional_message_id`.

    * `:preheader` (string) - Also known as "preview text", this is the block of
      text that users see next to, or underneath, the subject line in their inbox.

    * `:queue_draft` (boolean) - If true, your transactional message is held as
      a draft in Customer.io and not sent directly to your audience. You must go
      to the Deliveries and Drafts page to send your message.

    * `:send_at` (integer) - A unix timestamp determining when the message will be sent.
      The timestamp can be up to 90 days in the future. If this value is in the past,
      your message is sent immediately.

    * `:send_to_unsubscribed` (boolean) - If false, your message is not sent to
      unsubscribed recipients. Setting this value overrides the value set in the
      settings of your transactional_message_id.

    * `:tracked"` (boolean) - If true, Customer.io tracks opens and link clicks
      in your message.

    * `:transactional_message_id` (integer or string) - The transactional message template that
      you want to use for your message. You can call the template by its numerical ID
      or by the Trigger Name that you assigned the template (case insensitive).
  """

  use Swoosh.Adapter, required_config: [:api_key]

  alias Swoosh.Email

  import Swoosh.Email.Render

  @base_url "https://api.customer.io/v1"
  @api_endpoint "/send/email"
  @provider_options_body_fields [
    :disable_css_preprocessing,
    :disable_message_retention,
    :fake_bcc,
    :identifiers,
    :preheader,
    :message_data,
    :queue_draft,
    :send_at,
    :send_to_unsubscribed,
    :tracked,
    :transactional_message_id
  ]

  @impl Swoosh.Adapter
  def deliver(%Email{} = email, config \\ []) do
    headers = [
      {"Content-Type", "application/json"},
      {"User-Agent", "swoosh/#{Swoosh.version()}"},
      {"Authorization", "Bearer #{config[:api_key]}"}
    ]

    body = email |> prepare_body() |> Swoosh.json_library().encode!
    url = [base_url(config), @api_endpoint]

    with {:ok, code, _headers, body} when code >= 200 and code <= 399 <-
           Swoosh.ApiClient.post(url, headers, body, email),
         {:ok, data} <- Swoosh.json_library().decode(body) do
      {:ok, %{id: data["delivery_id"]}}
    else
      {:ok, code, _headers, body} when code >= 400 ->
        case Swoosh.json_library().decode(body) do
          {:ok, error} -> {:error, {code, error}}
          {:error, _} -> {:error, {code, body}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp base_url(config), do: config[:base_url] || @base_url

  defp prepare_body(email) do
    %{}
    |> prepare_from(email)
    |> prepare_to(email)
    |> prepare_bcc(email)
    |> prepare_subject(email)
    |> prepare_content(email)
    |> prepare_attachments(email)
    |> prepare_reply_to(email)
    |> prepare_custom_headers(email)
    |> prepare_provider_options_body_fields(email)
  end

  defp prepare_from(body, %Email{from: nil}), do: body
  defp prepare_from(body, %Email{from: from}), do: Map.put(body, :from, render_recipient(from))

  defp prepare_to(body, %Email{to: to}),
    do: Map.put(body, :to, render_recipient(to))

  defp prepare_bcc(body, %Email{bcc: []}), do: body

  defp prepare_bcc(body, %Email{bcc: bcc}),
    do: Map.put(body, :bcc, render_recipient(bcc))

  defp prepare_reply_to(body, %Email{reply_to: nil}), do: body

  defp prepare_reply_to(body, %Email{reply_to: reply_to}),
    do: Map.put(body, :reply_to, render_recipient(reply_to))

  defp prepare_subject(body, %Email{subject: nil}), do: body
  defp prepare_subject(body, %Email{subject: ""}), do: body
  defp prepare_subject(body, %Email{subject: subject}), do: Map.put(body, :subject, subject)

  defp prepare_content(body, %Email{html_body: nil, text_body: nil}), do: body

  defp prepare_content(body, %Email{html_body: nil, text_body: text_body}),
    do: Map.put(body, :plaintext_body, text_body)

  defp prepare_content(body, %Email{html_body: html_body, text_body: nil}),
    do: Map.put(body, :body, html_body)

  defp prepare_content(body, %Email{html_body: html_body, text_body: text_body}),
    do: Map.merge(body, %{body: html_body, plaintext_body: text_body})

  defp prepare_attachments(body, %Email{attachments: []}), do: body

  defp prepare_attachments(body, %Email{attachments: attachments}) do
    attachments =
      Enum.map(attachments, &%{&1.filename => Swoosh.Attachment.get_content(&1, :base64)})

    Map.put(body, :attachments, attachments)
  end

  defp prepare_custom_headers(body, %Email{headers: headers})
       when map_size(headers) == 0,
       do: body

  defp prepare_custom_headers(body, %Email{headers: headers}) do
    headers = Enum.map(headers, fn {header, value} -> %{header => value} end)
    Map.put(body, :headers, headers)
  end

  defp prepare_provider_options_body_fields(body, %Email{provider_options: provider_options}) do
    Map.merge(body, Map.take(provider_options, @provider_options_body_fields))
  end
end
