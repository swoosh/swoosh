defmodule Swoosh.Adapters.MsGraph do
  @moduledoc ~S"""
  An adapter that sends email using the Microsoft Graph API.

  For reference: [Microsoft Graph API docs](https://learn.microsoft.com/en-us/graph/api/user-sendmail)

  **This adapter requires an API Client.** Swoosh comes with Hackney, Finch and Req out of the box.
  See the [installation section](https://hexdocs.pm/swoosh/Swoosh.html#module-installation)
  for details.

  > ### Dependency {: .info}
  >
  > Microsoft Graph adapter requires `:gen_smtp` to work properly.
  > `:gen_smtp` is only used to encode the email body to MIME format.

  ## Configuration options

  * `:auth` - either a function, a {mod, func, args} tuple, or a string that returns/is an OAuth 2.0 access token.
  * `:base_url` - the base URL to use as the Microsoft Graph API endpoint.  Defaults to the standard Microsoft Graph API endpoint.

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.MsGraph,
        auth: fn -> Sample.OAuthTokenRequester.request_token() end

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  """

  use Swoosh.Adapter,
    required_config: [:auth],
    required_deps: [gen_smtp: :gen_smtp_client]

  require Logger
  alias Swoosh.Email

  @base_url "https://graph.microsoft.com/v1.0"

  def deliver(%Email{} = email, config \\ []) do
    Logger.debug("Delivering email using #{__MODULE__} Swoosh adapter: #{inspect(email)}")
    headers = prepare_headers(config)
    url = api_endpoint_url(email, config)
    body = encode_body(email, config)

    case Swoosh.ApiClient.post(url, headers, body, email) do
      # Per https://learn.microsoft.com/en-us/graph/api/user-sendmail?view=graph-rest-1.0&tabs=http#response
      # if successful, this method returns 202 Accepted response code. It doesn't return anything in the response body.
      {:ok, 202, _headers, body} ->
        Logger.debug("202 response, body: #{inspect(body)}")
        {:ok, %{}}

      # If the request body includes malformed MIME content, this method returns 400 Bad request and the following error message: "Invalid base64 string for MIME content."
      {:ok, 400, _headers, body} ->
        Logger.debug("400 response, body: #{inspect(body)}")
        {:error, {400, body}}

      # No other return codes are documented, but we'll treat them as an error.
      {:ok, code, _headers, body} ->
        Logger.debug("Unexpected response, code: #{code}, body: #{inspect(body)}")
        {:error, {code, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc false
  # Encodes the email to headers and MIME content, encoded in base64,
  # per https://learn.microsoft.com/en-us/graph/api/user-sendmail?view=graph-rest-1.0&tabs=http#request-body.
  def encode_body(email, config) do
    email
    |> Swoosh.Adapters.SMTP.Helpers.body(config)
    |> Base.encode64()
  end

  defp base_url(config), do: config[:base_url] || @base_url

  defp api_endpoint_url(email, config) do
    {_, from_email} = email.from
    "#{base_url(config)}/users/#{from_email}/sendMail"
  end

  defp prepare_headers(config) do
    [
      {"User-Agent", "swoosh/#{Swoosh.version()}"},
      {"Authorization", "Bearer #{auth(config)}"},
      # Per https://learn.microsoft.com/en-us/graph/api/user-sendmail?view=graph-rest-1.0&tabs=http#request-headers
      # we use a Content-Type of `text/plain` for MIME content.
      {"Content-Type", "text/plain"}
    ]
  end

  defp auth(config) do
    case config[:auth] do
      func when is_function(func, 0) ->
        func.()

      {m, f, a} when is_atom(m) and is_atom(f) and is_list(a) ->
        apply(m, f, a)

      token when is_binary(token) ->
        token

      nil ->
        raise "Missing required config :auth, it can be a function, a {mod, func, args} tuple, or a string"
    end
  end
end
