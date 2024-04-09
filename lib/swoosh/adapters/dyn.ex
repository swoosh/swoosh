defmodule Swoosh.Adapters.Dyn do
  @moduledoc ~S"""
  An adapter that sends email using the Dyn API.

  For reference: [Dyn API docs](https://help.dyn.com/email-rest-methods-api/sending-api/)

  **This adapter requires an API Client.** Swoosh comes with Hackney, Finch and Req out of the box.
  See the [installation section](https://hexdocs.pm/swoosh/Swoosh.html#module-installation)
  for details.

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Dyn,
        api_key: "my-api-key"

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  ## Sending sample email

      import Swoosh.Email

      new()
      |> from({"Christine", "christine@example.com"})
      |> to({"constance", "constance@example.com"})
      |> to("ming_fleetfoot@example.com")
      |> bcc([
        {"Dr. Xander Bravestone", "dr.xander_bravestone@example.com"},
        {"Prof. Sheldon Oberon", "prof.sheldon.oberon@example.com"}
      ])
      |> subject("Hello, People!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")

  """
  use Swoosh.Adapter, required_config: [:api_key]

  alias Swoosh.Email
  alias Swoosh.DeliveryError
  import Swoosh.Email.Render

  @base_url "https://emailapi.dynect.net"
  @api_endpoint "rest/json/send"

  def deliver(%Email{} = email, config \\ []) do
    headers = prepare_headers(email, config)
    url = [base_url(config), "/", @api_endpoint]

    body =
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
      |> add_auth_token(config[:api_key])
      |> encode_body

    case Swoosh.ApiClient.post(url, headers, body, email) do
      {:ok, 200, _headers, body} ->
        {:ok, Swoosh.json_library().decode!(body)["response"]["message"]}

      {:ok, 404, _headers, _body} ->
        {:error, "Not found"}

      {:ok, 503, _headers, _body} ->
        {:error, "Service Unavailable"}

      {:ok, _code, _headers, body} ->
        {:error, "Error: #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp base_url(config), do: config[:base_url] || @base_url

  defp prepare_headers(email, _config) do
    [{"User-Agent", "swoosh/#{Swoosh.version()}"}, {"Content-Type", content_type(email)}]
  end

  defp content_type(%{attachments: []}), do: "application/x-www-form-urlencoded"
  defp content_type(%{}), do: "multipart/form-data"

  defp prepare_from(body, %{from: from}), do: Map.put(body, :from, render_recipient(from))

  defp prepare_to(body, %{to: to}), do: Map.put(body, :to, render_recipient(to))

  defp prepare_reply_to(body, %{reply_to: nil}), do: body
  defp prepare_reply_to(body, %{reply_to: {_name, address}}), do: Map.put(body, :replyto, address)

  defp prepare_cc(body, %{cc: []}), do: body

  defp prepare_cc(body, %{cc: ccs}) do
    ccs
    |> Enum.with_index(1)
    |> Enum.map(fn {cc, counter} -> {"cc[#{counter}]", render_recipient(cc)} end)
    |> Enum.into(body)
  end

  defp prepare_bcc(body, %{bcc: []}), do: body

  defp prepare_bcc(body, %{bcc: bccs}) do
    bccs
    |> Enum.with_index(1)
    |> Enum.map(fn {bcc, counter} -> {"bcc[#{counter}]", render_recipient(bcc)} end)
    |> Enum.into(body)
  end

  defp prepare_subject(body, %{subject: subject}), do: Map.put(body, :subject, subject)

  defp prepare_text(body, %{text_body: nil}), do: body
  defp prepare_text(body, %{text_body: text_body}), do: Map.put(body, :bodytext, text_body)

  defp prepare_html(body, %{html_body: nil}), do: body
  defp prepare_html(body, %{html_body: html_body}), do: Map.put(body, :bodyhtml, html_body)

  defp prepare_attachments(body, %{attachments: []}), do: body

  defp prepare_attachments(_body, _email) do
    raise DeliveryError, reason: :unsupported_feature, payload: :attachments
  end

  defp add_auth_token(body, api_key), do: Map.put(body, :apikey, api_key)

  defp encode_body(body), do: URI.encode_query(body)
end
