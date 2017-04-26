defmodule Swoosh.Adapters.Postmark do
  @moduledoc ~S"""
  An adapter that sends email using the Postmark API.

  For reference: [Postmark API docs](http://developer.postmarkapp.com/developer-send-api.html)

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Postmark,
        api_key: "my-api-key"

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end
  """

  use Swoosh.Adapter, required_config: [:api_key]

  alias Swoosh.Email

  @base_url     "https://api.postmarkapp.com"
  @api_endpoint "/email"

  def deliver(%Email{} = email, config \\ []) do
    headers = prepare_headers(config)
    params = email |> prepare_body |> Poison.encode!
    url = [base_url(config), api_endpoint(email)]

    case :hackney.post(url, headers, params, [:with_body]) do
      {:ok, 200, _headers, body} ->
        {:ok, %{id: Poison.decode!(body)["MessageID"]}}
      {:ok, code, _headers, body} when code > 399 ->
        {:error, {code, Poison.decode!(body)}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp base_url(config), do: config[:base_url] || @base_url

  defp prepare_headers(config) do
    [{"User-Agent", "swoosh/#{Swoosh.version}"},
     {"X-Postmark-Server-Token", config[:api_key]},
     {"Content-Type", "application/json"},
     {"Accept", "application/json"}]
  end

  defp api_endpoint(%{provider_options: %{template_id: _, template_model: _}}),
    do: @api_endpoint <> "/withTemplate"
  defp api_endpoint(_email),
    do: @api_endpoint

  defp prepare_body(email) do
    %{}
    |> prepare_from(email)
    |> prepare_to(email)
    |> prepare_subject(email)
    |> prepare_html(email)
    |> prepare_text(email)
    |> prepare_cc(email)
    |> prepare_bcc(email)
    |> prepare_attachments(email)
    |> prepare_reply_to(email)
    |> prepare_template(email)
  end

  defp prepare_from(body, %{from: from}), do: Map.put(body, "From", prepare_recipient(from))

  defp prepare_to(body, %{to: to}), do: Map.put(body, "To", prepare_recipients(to))

  defp prepare_cc(body, %{cc: []}), do: body
  defp prepare_cc(body, %{cc: cc}), do: Map.put(body, "Cc", prepare_recipients(cc))

  defp prepare_bcc(body, %{bcc: []}), do: body
  defp prepare_bcc(body, %{bcc: bcc}), do: Map.put(body, "Bcc", prepare_recipients(bcc))

  defp prepare_attachments(body, %{attachments: []}), do: body
  defp prepare_attachments(body, %{attachments: attachments}) do
    Map.put(body, "Attachments", Enum.map(attachments, &%{
      "Name" => &1.filename,
      "ContentType" => &1.content_type,
      "Content" => &1.path |> File.read! |> Base.encode64
    }))
  end

  defp prepare_reply_to(body, %{reply_to: nil}), do: body
  defp prepare_reply_to(body, %{reply_to: {_name, address}}), do: Map.put(body, "ReplyTo", address)

  defp prepare_recipients(recipients) do
    recipients
    |> Enum.map(&prepare_recipient(&1))
    |> Enum.join(",")
  end

  defp prepare_recipient({"", address}), do: address
  defp prepare_recipient({name, address}), do: "\"#{name}\" <#{address}>"

  defp prepare_subject(body, %{subject: ""}), do: body
  defp prepare_subject(body, %{subject: subject}), do: Map.put(body, "Subject", subject)

  defp prepare_text(body, %{text_body: nil}), do: body
  defp prepare_text(body, %{text_body: text_body}), do: Map.put(body, "TextBody", text_body)

  defp prepare_html(body, %{html_body: nil}), do: body
  defp prepare_html(body, %{html_body: html_body}), do: Map.put(body, "HtmlBody", html_body)

  # example custom vars
  #
  # %{
  #   "template_id"    => 123,
  #   "template_model" => %{"name": 1, "company": 2}
  # }
  defp prepare_template(body, %{provider_options: provider_options}),
    do: Enum.reduce(provider_options, body, &put_in_body/2)
  defp prepare_template(body, _email), do: body

  defp put_in_body({:template_model, val}, body_acc),
    do: Map.put(body_acc, "TemplateModel", val)
  defp put_in_body({:template_id, val}, body_acc),
    do: Map.put(body_acc, "TemplateId", val)
  defp put_in_body(_, body_acc), do: body_acc
end
