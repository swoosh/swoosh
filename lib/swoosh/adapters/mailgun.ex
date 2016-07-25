defmodule Swoosh.Adapters.Mailgun do
  @moduledoc ~S"""
  An adapter that sends email using the Mailgun API.

  For reference: [Mailgun API docs](https://documentation.mailgun.com/api-sending.html#sending)

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

  use Swoosh.Adapter, required_config: [:api_key, :domain]

  alias Swoosh.Email

  @base_url     "https://api.mailgun.net/v3"
  @api_endpoint "/messages"

  def deliver(%Email{} = email, config \\ []) do
    headers = prepare_headers(email, config)
    params = email |> prepare_body |> Plug.Conn.Query.encode
    url = [base_url(config), "/", config[:domain], @api_endpoint]

    case :hackney.post(url, headers, params, [:with_body]) do
      {:ok, 200, _headers, body} ->
        {:ok, %{id: Poison.decode!(body)["id"]}}
      {:ok, 401, _headers, body} ->
        {:error, {401, body}}
      {:ok, code, _headers, body} when code > 399 ->
        {:error, {code, Poison.decode!(body)}}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp base_url(config), do: config[:base_url] || @base_url

  defp prepare_headers(email, config) do
    [{"User-Agent", "swoosh/#{Swoosh.version}"},
     {"Authorization", "Basic #{auth(config)}"},
     {"Content-Type", content_type(email)}]
  end

  defp auth(config), do: Base.encode64("api:#{config[:api_key]}")

  defp content_type(%Email{attachments: nil}), do: "application/x-www-form-urlencoded"
  defp content_type(%Email{attachments: []}), do: "application/x-www-form-urlencoded"
  defp content_type(%Email{}), do: "multipart/form-data"

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
    |> prepare_custom_vars(email)
  end

  # example custom_vars
  # 
  # %{"my_var" => %{"my_message_id": 123}, 
  #   "my_other_var" => %{"my_other_id": 1, "stuff": 2}}
  defp prepare_custom_vars(body, %Email{provider_options: %{custom_vars: my_vars}}) do
    my_vars 
    |> Enum.reduce(body, fn({k, v}, body_acc) -> Map.put(body_acc, "v:#{k}", Poison.encode!(v)) end)
  end   
  defp prepare_custom_vars(body, _email), do: body


  defp prepare_from(body, %Email{from: from}), do: Map.put(body, :from, prepare_recipient(from))

  defp prepare_to(body, %Email{to: to}), do: Map.put(body, :to, prepare_recipients(to))

  defp prepare_reply_to(body, %Email{reply_to: nil}), do: body
  defp prepare_reply_to(body, %Email{reply_to: {_name, address}}), do: Map.put(body, "h:Reply-To", address)

  defp prepare_cc(body, %Email{cc: []}), do: body
  defp prepare_cc(body, %Email{cc: cc}), do: Map.put(body, :cc, prepare_recipients(cc))

  defp prepare_bcc(body, %Email{bcc: []}), do: body
  defp prepare_bcc(body, %Email{bcc: bcc}), do: Map.put(body, :bcc, prepare_recipients(bcc))

  defp prepare_recipients(recipients) do
    recipients
    |> Enum.map(&prepare_recipient(&1))
    |> Enum.join(",")
  end

  defp prepare_recipient({"", address}), do: address
  defp prepare_recipient({name, address}), do: "#{name} <#{address}>"

  defp prepare_subject(body, %Email{subject: subject}), do: Map.put(body, :subject, subject)

  defp prepare_text(body, %{text_body: nil}), do: body
  defp prepare_text(body, %{text_body: text_body}), do: Map.put(body, :text, text_body)

  defp prepare_html(body, %{html_body: nil}), do: body
  defp prepare_html(body, %{html_body: html_body}), do: Map.put(body, :html, html_body)
end
