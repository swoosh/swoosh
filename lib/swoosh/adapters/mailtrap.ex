defmodule Swoosh.Adapters.Mailtrap do
  @provider_options_body_fields [
    :custom_variables,
    :category
  ]

  @moduledoc ~s"""
  An adapter that sends email using the Mailtrap API.

  For reference: [Mailtrap API docs](https://api-docs.mailtrap.io/docs/mailtrap-api-docs/67f1d70aeb62c-send-email)

  **This adapter requires an API Client.** Swoosh comes with Hackney, Finch and Req out of the box.
  See the [installation section](https://hexdocs.pm/swoosh/Swoosh.html#module-installation)
  for details.

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Mailtrap,
        api_key: "my-api-key"

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  ## Sandbox mode

  For [sandbox mode](https://api-docs.mailtrap.io/docs/mailtrap-api-docs/bcf61cdc1547e-send-email-early-access), use the following config:

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Mailtrap,
        api_key: "my-api-key",
        sandbox_inbox_id: "111111"

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
      |> put_provider_option(:custom_variables, %{
        my_var: %{my_message_id: 123},
        my_other_var: %{my_other_id: 1, stuff: 2}
      })
      |> put_provider_option(:category, "welcome")

  ## Provider Options

  Supported provider options are the following:

  #### Inserted into request body

    * `:category` (string) - an email category

    * `:custom_variables` (map) - a map containing fields


  """

  use Swoosh.Adapter, required_config: [:api_key]

  alias Swoosh.Email

  @base_url "https://send.api.mailtrap.io"
  @sandbox_base_url "https://sandbox.api.mailtrap.io"
  @api_endpoint "/api/send"

  def deliver(%Email{} = email, config \\ []) do
    headers = [
      {"Content-Type", "application/json"},
      {"User-Agent", "swoosh/#{Swoosh.version()}"},
      {"Authorization", "Bearer #{config[:api_key]}"}
    ]

    body = email |> prepare_body() |> Swoosh.json_library().encode!
    url = prepare_url(config)

    case Swoosh.ApiClient.post(url, headers, body, email) do
      {:ok, code, _headers, body} when code >= 200 and code <= 399 ->
        {:ok, %{ids: Swoosh.json_library().decode!(body)["message_ids"]}}

      {:ok, code, _headers, body} when code >= 400 ->
        case Swoosh.json_library().decode(body) do
          {:ok, error} -> {:error, {code, error}}
          {:error, _} -> {:error, {code, body}}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp prepare_url(config) do
    if config[:sandbox_inbox_id] do
      base_url = config[:base_url] || @sandbox_base_url
      [base_url, Path.join([@api_endpoint, config[:sandbox_inbox_id]])]
    else
      [base_url(config), @api_endpoint]
    end
  end

  defp base_url(config),
    do: config[:base_url] || @base_url

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
    |> prepare_provider_options_body_fields(email)
  end

  defp email_item({"", email}), do: %{email: email}
  defp email_item({name, email}), do: %{email: email, name: name}
  defp email_item(email), do: %{email: email}

  defp reply_to_item({_, email}), do: email
  defp reply_to_item(email), do: email

  defp prepare_from(body, %{from: from}),
    do: Map.put(body, :from, from |> email_item)

  defp prepare_to(body, %{to: to}),
    do: Map.put(body, :to, to |> Enum.map(&email_item(&1)))

  defp prepare_cc(body, %{cc: []}), do: body

  defp prepare_cc(body, %{cc: cc}),
    do: Map.put(body, :cc, cc |> Enum.map(&email_item(&1)))

  defp prepare_bcc(body, %{bcc: []}), do: body

  defp prepare_bcc(body, %{bcc: bcc}),
    do: Map.put(body, :bcc, bcc |> Enum.map(&email_item(&1)))

  defp prepare_subject(body, %{subject: subject}),
    do: Map.put(body, :subject, subject)

  defp prepare_text(body, %{text_body: nil}), do: body

  defp prepare_text(body, %{text_body: text}),
    do: Map.put(body, :text, text)

  defp prepare_html(body, %{html_body: nil}), do: body

  defp prepare_html(body, %{html_body: html}),
    do: Map.put(body, :html, html)

  defp prepare_attachments(body, %{attachments: []}), do: body

  defp prepare_attachments(body, %{attachments: attachments}) do
    attachments =
      Enum.map(attachments, fn attachment ->
        attachment_info = %{
          filename: attachment.filename,
          type: attachment.content_type,
          content: Swoosh.Attachment.get_content(attachment, :base64)
        }

        extra =
          case attachment.type do
            :inline -> %{disposition: "inline", content_id: attachment.filename}
            :attachment -> %{disposition: "attachment"}
          end

        Map.merge(attachment_info, extra)
      end)

    Map.put(body, :attachments, attachments)
  end

  defp prepare_reply_to(body, %{reply_to: nil}), do: body

  defp prepare_reply_to(body, %{reply_to: reply_to}) do
    Map.put(body, :headers, %{"Reply-To" => reply_to_item(reply_to)})
  end

  defp prepare_custom_headers(body, %{headers: headers})
       when map_size(headers) == 0,
       do: body

  defp prepare_custom_headers(%{headers: body_headers} = body, %{headers: headers}) do
    Map.put(body, :headers, Map.merge(headers, body_headers))
  end

  defp prepare_custom_headers(body, %{headers: headers}),
    do: Map.put(body, :headers, headers)

  defp prepare_provider_options_body_fields(body, %{provider_options: provider_options}) do
    Map.merge(body, Map.take(provider_options, @provider_options_body_fields))
  end
end
