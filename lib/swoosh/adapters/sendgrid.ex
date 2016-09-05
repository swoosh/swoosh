defmodule Swoosh.Adapters.Sendgrid do
  @moduledoc ~S"""
  An adapter that sends email using the Sendgrid API.

  For reference: [Sendgrid API docs](https://sendgrid.com/docs/API_Reference/Web_API_v3/Mail/index.html://sendgrid.com/docs/API_Reference/Web_API_v3/Mail/index.html)

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

  alias Swoosh.Email

  @base_url "https://api.sendgrid.com/v3"
  @api_endpoint "/mail.send"

  def deliver(%Email{} = email, config \\ []) do
    headers = [{"Content-Type", "application/x-www-form-urlencoded"},
               {"User-Agent", "swoosh/#{Swoosh.version}"},
               {"Authorization", "Bearer #{config[:api_key]}"}]
    body = email |> prepare_body() |> Plug.Conn.Query.encode
    url = [base_url(config), @api_endpoint]

    case :hackney.post(url, headers, body, [:with_body]) do
      {:ok, code, _headers, _body} when code >= 200 and code <= 399 ->
        {:ok, %{}}
      {:ok, code, _headers, body} when code > 399 ->
        {:error, {code, Poison.decode!(body)}}
      {:error, reason} ->
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
    |> prepare_content(email)
    |> prepare_reply_to(email)
    |> prepare_custom_vars(email)
  end

  # example custom_vars
  # 
  # %{"my_var" => %{"my_message_id": 123}, 
  #   "my_other_var" => %{"my_other_id": 1, "stuff": 2}}
  defp prepare_custom_vars(body, %Email{provider_options: %{custom_args: my_vars}}) do
    Map.put(body, :custom_args, my_vars |> Poison.encode!)
  end   
  defp prepare_custom_vars(body, _email), do: body

  defp email_item({"", email}), do: %{email: email}
  defp email_item({name, email}), do: %{email: email, name: name}
  defp email_item(email), do: %{email: email}

  defp prepare_from(body, %Email{from: from}), do: Map.put(body, :from, from |> email_item |> Poison.encode!)

  defp prepare_to(body, %Email{to: to}), do: Map.put(body, :to, to |> Enum.map(&(&1 |> email_item)) |> Poison.encode!)

  defp prepare_cc(body, %Email{cc: []}), do: body
  defp prepare_cc(body, %Email{cc: cc}), do: Map.put(body, :cc, cc |> Enum.map(&(&1 |> email_item)) |> Poison.encode!)

  defp prepare_bcc(body, %Email{bcc: []}), do: body
  defp prepare_bcc(body, %Email{bcc: bcc}), do: Map.put(body, :bcc, bcc |> Enum.map(&(&1 |> email_item)) |> Poison.encode!)

  defp prepare_subject(body, %Email{subject: subject}), do: Map.put(body, :subject, subject)

  defp prepare_content(body, %Email{html_body: html, text_body: text}), do: Map.put(body, :content, [%{"text/html" => html, "text/plain": text}] |> Poison.encode!)
  defp prepare_content(body, %Email{html_body: html}), do: Map.put(body, :content, [%{"text/html" => html}] |> Poison.encode!)
  defp prepare_content(body, %Email{text_body: text}), do: Map.put(body, :content, [%{"text/plain": text}] |> Poison.encode!)

  defp prepare_reply_to(body, %Email{reply_to: nil}), do: body
  defp prepare_reply_to(body, %Email{reply_to: reply_to}), do: Map.put(body, :reply_to, reply_to |> email_item |> Poison.encode!)
end
