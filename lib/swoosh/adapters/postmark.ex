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

  alias HTTPoison.Response
  alias Swoosh.Email

  @base_url     "https://api.postmarkapp.com"
  @api_endpoint "/email"

  def deliver(%Email{} = email, config \\ []) do
    headers = prepare_headers(config)
    params = email |> prepare_body |> Poison.encode!

    case HTTPoison.post(base_url(config) <> @api_endpoint, params, headers) do
      {:ok, %Response{status_code: 200, body: body}} ->
        {:ok, %{id: Poison.decode!(body)["MessageID"]}}
      {:ok, %Response{status_code: code, body: body}} when code > 399 ->
        {:error, {code, Poison.decode!(body)}}
      {:error, %HTTPoison.Error{reason: reason}} ->
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
  end

  defp prepare_from(body, %Email{from: {_name, address}}), do: Map.put(body, "From", address)

  defp prepare_to(body, %Email{to: to}), do: Map.put(body, "To", prepare_recipients(to))

  defp prepare_cc(body, %Email{cc: []}), do: body
  defp prepare_cc(body, %Email{cc: cc}), do: Map.put(body, "Cc", prepare_recipients(cc))

  defp prepare_bcc(body, %Email{bcc: []}), do: body
  defp prepare_bcc(body, %Email{bcc: bcc}), do: Map.put(body, "Bcc", prepare_recipients(bcc))

  defp prepare_reply_to(body, %Email{reply_to: nil}), do: body
  defp prepare_reply_to(body, %Email{reply_to: {_name, address}}), do: Map.put(body, "ReplyTo", address)

  defp prepare_recipients(recipients) do
    recipients
    |> Enum.map(&prepare_recipient(&1))
    |> Enum.join(",")
  end

  defp prepare_recipient({"", address}), do: address
  defp prepare_recipient({name, address}), do: "\"#{name}\" <#{address}>"

  defp prepare_subject(body, %Email{subject: subject}), do: Map.put(body, "Subject", subject)

  defp prepare_text(body, %{text_body: nil}), do: body
  defp prepare_text(body, %{text_body: text_body}), do: Map.put(body, "TextBody", text_body)

  defp prepare_html(body, %{html_body: nil}), do: body
  defp prepare_html(body, %{html_body: html_body}), do: Map.put(body, "HtmlBody", html_body)
end
