defmodule Swoosh.Adapters.Sendgrid do
  @moduledoc ~S"""
  An adapter that sends email using the Sendgrid API.

  For reference: [Sendgrid API docs](https://sendgrid.com/docs/API_Reference/Web_API/mail.htm://sendgrid.com/docs/API_Reference/Web_API/mail.html)

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Sendgrid,
        api_key: "my-api-key"

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end
  """

  use Swoosh.Adapter, required_config: [:api_key]

  alias HTTPoison.Response
  alias Swoosh.Email

  @base_url "https://api.sendgrid.com/api"
  @api_endpoint "/mail.send.json"

  def deliver(%Email{} = email, config \\ []) do
    headers = [{"Content-Type", "application/x-www-form-urlencoded"},
               {"User-Agent", "swoosh/#{Swoosh.version}"},
               {"Authorization", "Bearer #{config[:api_key]}"}]
    body = email |> prepare_body() |> Plug.Conn.Query.encode

    case HTTPoison.post(base_url(config) <> @api_endpoint, body, headers) do
      {:ok, %Response{status_code: code}} when code >= 200 and code <= 399 ->
        {:ok, %{}}
      {:ok, %Response{status_code: code, body: body}} when code > 399 ->
        {:error, {code, Poison.decode!(body)}}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  defp base_url(config), do: config[:base_url] || @base_url

  defp prepare_body(%Email{} = email) do
    %{}
    |> prepare_from(email)
    |> prepare_to(email)
    |> prepare_cc(email)
    |> prepare_bcc(email)
    |> prepare_subject(email)
    |> prepare_html_body(email)
    |> prepare_text_body(email)
    |> prepare_reply_to(email)
  end

  defp prepare_from(body, %Email{from: {"", address}}), do: Map.put(body, :from, address)
  defp prepare_from(body, %Email{from: {name, address}}) do
    body
    |> Map.put(:from, address)
    |> Map.put(:fromname, name)
  end

  defp prepare_to(body, %Email{to: to}) do
    {names, addresses} = Enum.unzip(to)
    body
    |> prepare_addresses(:to, addresses)
    |> prepare_names(:toname, names)
  end

  defp prepare_cc(body, %Email{cc: []}), do: body
  defp prepare_cc(body, %Email{cc: cc}) do
    {names, addresses} = Enum.unzip(cc)
    body
    |> prepare_addresses(:cc, addresses)
    |> prepare_names(:ccname, names)
  end

  defp prepare_bcc(body, %Email{bcc: []}), do: body
  defp prepare_bcc(body, %Email{bcc: bcc}) do
    {names, addresses} = Enum.unzip(bcc)
    body
    |> prepare_addresses(:bcc, addresses)
    |> prepare_names(:bccname, names)
  end

  defp prepare_subject(body, %Email{subject: subject}), do: Map.put(body, :subject, subject)

  defp prepare_html_body(body, %Email{html_body: nil}), do: body
  defp prepare_html_body(body, %Email{html_body: html_body}), do: Map.put(body, :html, html_body)

  defp prepare_text_body(body, %Email{text_body: nil}), do: body
  defp prepare_text_body(body, %Email{text_body: text_body}), do: Map.put(body, :text, text_body)

  defp prepare_reply_to(body, %Email{reply_to: nil}), do: body
  defp prepare_reply_to(body, %Email{reply_to: {_name, address}}), do: Map.put(body, :replyto, address)

  defp prepare_addresses(body, field, addresses), do: Map.put(body, field, addresses)
  defp prepare_names(body, field, names) do
    if list_empty?(names), do: body, else: Map.put(body, field, names)
  end

  defp list_empty?([]), do: true
  defp list_empty?(list) do
    Enum.all?(list, fn(el) -> el == "" || el == nil end)
  end
end
