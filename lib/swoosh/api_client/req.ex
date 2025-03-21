defmodule Swoosh.ApiClient.Req do
  @moduledoc """
  Req-based ApiClient for Swoosh.

      config :swoosh, :api_client, Swoosh.ApiClient.Req

  Any `client_options` that are set will be passed along to `Req.post` but the
  following keys will be overwritten as they are set by Swoosh explicitly:
    * `headers`
    * `body`
    * `decode_body` - set to false as Adapters expect the raw response
  """

  require Logger

  @behaviour Swoosh.ApiClient
  @user_agent {"User-Agent", "swoosh/#{Swoosh.version()}"}

  @impl true
  def init do
    unless Code.ensure_loaded?(Req) do
      Logger.error("""
      Could not find req dependency.

      Please add :req to your dependencies:

          {:req, "~> 0.4"}

      Or set your own Swoosh.ApiClient:

          config :swoosh, :api_client, MyAPIClient
      """)

      raise "missing req dependency"
    end

    _ = Application.ensure_all_started(:req)
    :ok
  end

  @impl true
  def post(url, headers, body, %Swoosh.Email{} = email) do
    url = IO.iodata_to_binary(url)

    options = email.private[:client_options] || []

    # Set `decode_body` option to false as Swoosh's Mailgun adapter expects
    # that the body is a binary. Req will run `Jason.decode` itself and
    # `response.body` will already be a map if it is not set.
    required_options = [
      headers: [@user_agent | headers],
      body: body,
      decode_body: false
    ]

    options = Keyword.merge(options, required_options)

    case Req.post(url, options) do
      {:ok, response} ->
        headers = Req.get_headers_list(response)
        {:ok, response.status, headers, response.body}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
