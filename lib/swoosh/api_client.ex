defmodule Swoosh.ApiClient do
  @moduledoc """
  Specification for a Swoosh API client.

  It can be set to your own client with:

      config :swoosh, :api_client, MyAPIClient

  """

  @type url :: binary()
  @type headers :: [{binary(), binary()}]
  @type body :: binary()
  @type status :: pos_integer()

  @doc """
  Callback to initializes the given api client.
  """
  @callback init() :: :ok

  @doc """
  Callback invoked when posting to a given URL.
  """
  @callback post(url, headers, body, Swoosh.Email.t) ::
              {:ok, status, headers, body} | {:error, term()}

  @optional_callback init: 1

  @doc """
  API used by adapters to post to a given URL with headers, body, and e-mail.
  """
  def post(url, headers, body, email) do
    api_client().post(url, headers, body, email)
  end

  @doc false
  def init do
    client = api_client()

    if Code.ensure_loaded?(client) and function_exported?(client, :init, 0) do
      :ok = client.init()
    end

    :ok
  end

  defp api_client do
    Application.fetch_env!(:swoosh, :api_client)
  end
end

defmodule Swoosh.ApiClient.Hackney do
  @moduledoc """
  Built-in hackney-based ApiClient.
  """

  require Logger

  @behaviour Swoosh.ApiClient
  @user_agent {"User-Agent", "swoosh/#{Swoosh.version()}"}

  @impl true
  def init do
    unless Code.ensure_loaded?(:hackney) do
      Logger.error """
      Could not find hackney dependency.

      Please add :hackney to your dependencies:

          {:hackney, "~> 1.9"}

      Or set your own Swoosh.ApiClient:

          config :swoosh, :api_client, MyAPIClient
      """

      raise "missing hackney dependency"
    end

    _ = Application.ensure_all_started(:hackney)
    :ok
  end

  @impl true
  def post(url, headers, body, %Swoosh.Email{} = email) do
    hackney_options = email.private[:hackney_options] || []

    :hackney.post(
      url,
      [@user_agent | headers],
      body,
      [:with_body | hackney_options]
    )
  end
end
