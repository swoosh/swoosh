defmodule Swoosh.Adapters.Mailgun do
  @moduledoc ~S"""
  An adapter that sends email using the Mailgun API.

  For reference: [Mailgun API docs](https://documentation.mailgun.com/api-sending.html#sending)

  ## Dependency
  
  Mailgun adapter requires `Plug` to work properly.

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Mailgun,
        api_key: "my-api-key",
        domain: "avengers.com"

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end
  """

  use Swoosh.Adapter, required_config: [:api_key, :domain], required_deps: [plug: Plug.Conn.Query]

  alias Swoosh.Email
  import Swoosh.Email.Render

  @base_url "https://api.mailgun.net/v3"
  @api_endpoint "/messages"

  def deliver(%Email{} = email, config \\ []) do
    headers = prepare_headers(email, config)
    url = [base_url(config), "/", config[:domain], @api_endpoint]

    case :hackney.post(url, headers, prepare_body(email), [:with_body]) do
      {:ok, 200, _headers, body} ->
        {:ok, %{id: Swoosh.json_library().decode!(body)["id"]}}

      {:ok, 401, _headers, body} ->
        {:error, {401, body}}

      {:ok, code, _headers, ""} when code > 399 ->
        {:error, {code, ""}}

      {:ok, code, _headers, body} when code > 399 ->
        {:error, {code, Swoosh.json_library().decode!(body)}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp base_url(config), do: config[:base_url] || @base_url

  defp prepare_headers(email, config) do
    [
      {"User-Agent", "swoosh/#{Swoosh.version()}"},
      {"Authorization", "Basic #{auth(config)}"},
      {"Content-Type", content_type(email)}
    ]
  end

  defp auth(config), do: Base.encode64("api:#{config[:api_key]}")

  defp content_type(%{attachments: []}), do: "application/x-www-form-urlencoded"
  defp content_type(%{}), do: "multipart/form-data"

  defp prepare_body(email) do
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
    |> prepare_custom_vars(email)
    |> prepare_recipient_vars(email)
    |> prepare_custom_headers(email)
    |> encode_body
  end

  # example custom_vars
  #
  # %{"my_var" => %{"my_message_id": 123},
  #   "my_other_var" => %{"my_other_id": 1, "stuff": 2}}
  defp prepare_custom_vars(body, %{provider_options: %{custom_vars: custom_vars}}) do
    Enum.reduce(custom_vars, body, fn {k, v}, body ->
      Map.put(body, "v:#{k}", Swoosh.json_library().encode!(v))
    end)
  end

  defp prepare_custom_vars(body, _email), do: body

  defp prepare_recipient_vars(body, %{provider_options: %{recipient_vars: recipient_vars}}) do
    Map.put(body, "recipient-variables", Swoosh.json_library().encode!(recipient_vars))
  end

  defp prepare_recipient_vars(body, _email), do: body

  defp prepare_custom_headers(body, %{headers: headers}) do
    Enum.reduce(headers, body, fn {k, v}, body -> Map.put(body, "h:#{k}", v) end)
  end

  defp prepare_attachments(body, %{attachments: []}), do: body

  defp prepare_attachments(body, %{attachments: attachments}) do
    {normal_attachments, inline_attachments} =
      Enum.split_with(attachments, fn %{type: type} -> type == :attachment end)

    body
    |> Map.put(:attachments, Enum.map(normal_attachments, &prepare_file(&1, "attachment")))
    |> Map.put(:inline, Enum.map(inline_attachments, &prepare_file(&1, "inline")))
  end

  defp prepare_file(attachment, type) do
    {:file, attachment.path,
     {"form-data", [{~s/"name"/, ~s/"#{type}"/}, {~s/"filename"/, ~s/"#{attachment.filename}"/}]},
     []}
  end

  defp prepare_from(body, %{from: from}), do: Map.put(body, :from, render_recipient(from))

  defp prepare_to(body, %{to: to}), do: Map.put(body, :to, render_recipient(to))

  defp prepare_reply_to(body, %{reply_to: nil}), do: body

  defp prepare_reply_to(body, %{reply_to: {_name, address}}),
    do: Map.put(body, "h:Reply-To", address)

  defp prepare_cc(body, %{cc: []}), do: body
  defp prepare_cc(body, %{cc: cc}), do: Map.put(body, :cc, render_recipient(cc))

  defp prepare_bcc(body, %{bcc: []}), do: body
  defp prepare_bcc(body, %{bcc: bcc}), do: Map.put(body, :bcc, render_recipient(bcc))

  defp prepare_subject(body, %{subject: subject}), do: Map.put(body, :subject, subject)

  defp prepare_text(body, %{text_body: nil}), do: body
  defp prepare_text(body, %{text_body: text_body}), do: Map.put(body, :text, text_body)

  defp prepare_html(body, %{html_body: nil}), do: body
  defp prepare_html(body, %{html_body: html_body}), do: Map.put(body, :html, html_body)

  defp encode_body(%{attachments: attachments, inline: inline} = params) do
    {:multipart,
     params
     |> Map.drop([:attachments, :inline])
     |> Enum.map(fn {k, v} -> {to_string(k), v} end)
     |> Kernel.++(attachments)
     |> Kernel.++(inline)}
  end

  defp encode_body(no_attachments), do: Plug.Conn.Query.encode(no_attachments)
end
