defmodule Swoosh.Adapters.SMTP2GO do
  @moduledoc ~S"""
  An adapter that sends email using the SMTP2GO API.

  For reference: [SMTP2GO API docs](https://apidoc.smtp2go.com/documentation/#/POST%20/email/send)

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.SMTP2GO,
        api_key: "my-api-key"

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  ## Usage

      import Swoosh.Email

      new()
      |> from({"Tony", "ironman@example.com"})
      |> to({"Thanos", "thanos@example.com"})
      |> reply_to("avengers@example.com")
      |> cc("hulk@example.com")
      |> bcc({"Steve Rogers", "steve.rogers@example.com"})
      |> subject("I'm Ironman")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")

  with template:

      import Swoosh.Email

      new()
      |> from({"Tony", "ironman@example.com"})
      |> to({"Thanos", "thanos@example.com"})
      |> subject("I'm Ironman")
      |> put_provider_option(:template_id, "123456")
      |> put_provider_option(:template_data, %{"var1" => "value1"})

  """

  use Swoosh.Adapter,
    required_config: [:api_key],
    required_deps: [plug: Plug.Conn.Query]

  alias Swoosh.{Email, Attachment}

  require Logger

  @base_url "https://api.smtp2go.com/v3"
  @api_endpoint "email/send"

  @impl true
  def deliver(%Email{} = email, config \\ []) do
    body = email |> prepare_body(config) |> Swoosh.json_library().encode!()
    headers = prepare_headers(config)
    url = [base_url(config), "/", @api_endpoint]

    case Swoosh.ApiClient.post(url, headers, body, email) do
      {:ok, 200, _headers, body} ->
        %{"data" => %{"email_id" => email_id}} = Swoosh.json_library().decode!(body)
        {:ok, %{id: email_id}}

      {:ok, status_code, _headers, error}
      when status_code >= 400 ->
        %{"data" => %{"error_code" => error_code, "error" => error_message}} =
          Swoosh.json_library().decode!(error)

        Logger.debug(error_message)
        {:error, {status_code, error_code}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp base_url(config), do: config[:base_url] || @base_url

  defp prepare_headers(_) do
    [
      {"User-Agent", "swoosh/#{Swoosh.version()}"},
      {"Content-Type", "application/json"}
    ]
  end

  defp prepare_body(email, config) do
    %{}
    |> Map.put("api_key", config[:api_key])
    |> prepare_from(email)
    |> prepare_to(email)
    |> prepare_subject(email)
    |> prepare_html(email)
    |> prepare_text(email)
    |> prepare_cc(email)
    |> prepare_bcc(email)
    |> prepare_attachments(email)
    |> prepare_template_data(email)
    |> prepare_template(email)
    |> prepare_custom_headers(email)
  end

  defp prepare_custom_headers(body, %{headers: headers}) do
    Map.put(
      body,
      "custom_headers",
      Enum.map(headers, fn {k, v} -> %{"header" => k, "value" => v} end)
    )
  end

  defp prepare_attachments(body, %{attachments: []}), do: body

  defp prepare_attachments(body, %{attachments: attachments}) do
    {normal_attachments, inline_attachments} =
      Enum.split_with(attachments, fn %{type: type} -> type == :attachment end)

    body
    |> Map.put("attachments", Enum.map(normal_attachments, &prepare_attachment/1))
    |> Map.put("inlines", Enum.map(inline_attachments, &prepare_attachment/1))
  end

  defp prepare_attachment(attachment) do
    %{
      "mimetype" => attachment.content_type,
      "filename" => attachment.filename,
      "fileblob" => Attachment.get_content(attachment, :base64)
    }
  end

  defp prepare_recipients(recipients),
    do: Enum.map(recipients, &prepare_recipient(&1))

  defp prepare_recipient({"", address}),
    do: address

  defp prepare_recipient({name, address}),
    do: "#{name} <#{address}>"

  defp prepare_recipient(other), do: prepare_recipient(Swoosh.Email.Recipient.format(other))

  defp prepare_from(body, %{from: from}),
    do: Map.put(body, "sender", prepare_recipient(from))

  defp prepare_to(body, %{to: to}),
    do: Map.put(body, "to", prepare_recipients(to))

  defp prepare_cc(body, %{cc: []}), do: body

  defp prepare_cc(body, %{cc: cc}),
    do: Map.put(body, "cc", prepare_recipients(cc))

  defp prepare_bcc(body, %{bcc: []}), do: body

  defp prepare_bcc(body, %{bcc: bcc}),
    do: Map.put(body, "bcc", prepare_recipients(bcc))

  defp prepare_subject(body, %{subject: subject}),
    do: Map.put(body, "subject", subject)

  defp prepare_text(body, %{text_body: nil}), do: body

  defp prepare_text(body, %{text_body: text_body}),
    do: Map.put(body, "text_body", text_body)

  defp prepare_html(body, %{html_body: nil}), do: body

  defp prepare_html(body, %{html_body: html_body}),
    do: Map.put(body, "html_body", html_body || "")

  defp prepare_template_data(body, %{provider_options: %{template_data: data}}) do
    Map.put(body, "template_data", data)
  end

  defp prepare_template_data(body, _email), do: body

  defp prepare_template(body, %{provider_options: %{template_id: template_id}}) do
    Map.put(body, "template_id", template_id)
  end

  defp prepare_template(body, _email), do: body
end
