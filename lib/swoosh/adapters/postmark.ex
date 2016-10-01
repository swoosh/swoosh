defmodule Swoosh.Adapters.Postmark do
  @moduledoc ~S"""
  An adapter that sends email using the Postmark API.

  For reference: [Postmark API docs](http://developer.postmarkapp.com/developer-send-api.html)

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter:  Swoosh.Adapters.Postmark,
        api_key:  "my-api-key",
        template: true # optional

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
    url     = prepare_url(config)
    params  = prepare_body(email)

    make_request(url, headers, params)
  end

  defp prepare_headers(config) do
    [
      {"User-Agent",              "swoosh/#{Swoosh.version}"},
      {"X-Postmark-Server-Token", config[:api_key]},
      {"Content-Type",            "application/json"},
      {"Accept",                  "application/json"}
    ]
  end

  defp prepare_url(config),
    do: [base_url(config), api_endpoint(config)]

  defp base_url(config),
    do: config[:base_url] || @base_url

  defp api_endpoint([template: template])
  when not is_nil(template),
    do: @api_endpoint <>  "/withTemplate"
  defp api_endpoint(_config),
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
    |> prepare_reply_to(email)
    |> prepare_template_id(email)
    |> prepare_template_model(email)
    |> Poison.encode!()
  end

  defp prepare_from(body, %Email{from: {_name, address}}), do: Map.put(body, "From", address)

  defp prepare_to(body, %Email{to: to}), do: Map.put(body, "To", prepare_recipients(to))

  defp prepare_cc(body, %Email{cc: []}), do: body
  defp prepare_cc(body, %Email{cc: cc}), do: Map.put(body, "Cc", prepare_recipients(cc))

  defp prepare_bcc(body, %Email{bcc: []}),  do: body
  defp prepare_bcc(body, %Email{bcc: bcc}), do: Map.put(body, "Bcc", prepare_recipients(bcc))

  defp prepare_reply_to(body, %Email{reply_to: nil}),              do: body
  defp prepare_reply_to(body, %Email{reply_to: {_name, address}}), do: Map.put(body, "ReplyTo", address)

  defp prepare_recipients(recipients) do
    recipients
    |> Enum.map(&prepare_recipient/1)
    |> Enum.join(",")
  end

  defp prepare_recipient({"",   address}), do: address
  defp prepare_recipient({name, address}), do: "\"#{name}\" <#{address}>"

  defp prepare_subject(body, %Email{subject: subject}), do: Map.put(body, "Subject", subject)

  defp prepare_text(body, %Email{text_body: nil}),       do: body
  defp prepare_text(body, %Email{text_body: text_body}), do: Map.put(body, "TextBody", text_body)

  defp prepare_html(body, %Email{html_body: nil}),       do: body
  defp prepare_html(body, %Email{html_body: html_body}), do: Map.put(body, "HtmlBody", html_body)

  defp prepare_template_id(body, %{template_id: nil}),         do: body
  defp prepare_template_id(body, %{template_id: template_id}), do: Map.put(body, "TemplateId", template_id)
  defp prepare_template_id(body, _email),                      do: body

  defp prepare_template_model(body, %{template_model: nil}),            do: body
  defp prepare_template_model(body, %{template_model: template_model}), do: Map.put(body, "TemplateModel", template_model)
  defp prepare_template_model(body, _email),                            do: body

  defp make_request(url, headers, params) do
    case :hackney.post(url, headers, params, [:with_body]) do
      {:ok, 200, _headers, body} ->
        {:ok, %{id: Poison.decode!(body)["MessageID"]}}
      {:ok, code, _headers, body} when code > 399 ->
        {:error, {code, Poison.decode!(body)}}
      {:error, reason} ->
        {:error, reason}
    end
  end
end
