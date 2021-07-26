defmodule Swoosh.Mailer do
  @moduledoc ~S"""
  Defines a mailer.

  A mailer is a wrapper around an adapter that makes it easy for you to swap the
  adapter without having to change your code.

  It is also responsible for doing some sanity checks before handing down the
  email to the adapter.

  When used, the mailer expects `:otp_app` as an option.
  The `:otp_app` should point to an OTP application that has the mailer
  configuration. For example, the mailer:

      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  Could be configured with:

      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Sendgrid,
        api_key: "SG.x.x"

  Most of the configuration that goes into the config is specific to the adapter,
  so check the adapter's documentation for more information.

  Per module configuration is also supported, it has priority over mix configs:

      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample,
          adapter: Swoosh.Adapters.Sendgrid,
          api_key: "SG.x.x"
      end

  System environment variables can be specified with `{:system, "ENV_VAR_NAME"}`:

      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.SMTP,
        relay: "smtp.sendgrid.net"
        username: {:system, "SMTP_USERNAME"},
        password: {:system, "SMTP_PASSWORD"},
        tls: :always

  ## Examples

  Once configured you can use your mailer like this:

      # in an IEx console
      iex> email = new |> from("tony.stark@example.com") |> to("steve.rogers@example.com")
      %Swoosh.Email{from: {"", "tony.stark@example.com"}, ...}
      iex> Mailer.deliver(email)
      :ok

  You can also pass an extra config argument to `deliver/2` that will be merged
  with your Mailer's config:

      # in an IEx console
      iex> email = new |> from("tony.stark@example.com") |> to("steve.rogers@example.com")
      %Swoosh.Email{from: {"", "tony.stark@example.com"}, ...}
      iex> Mailer.deliver(email, domain: "jarvis.com")
      :ok

  ## Telemetry

  Each mailer outputs the following telemetry events:

  - `[:swoosh, :deliver, :start]`: occurs when `Mailer.deliver/2` begins.
  - `[:swoosh, :deliver, :stop]`: occurs when `Mailer.deliver/2` completes.
  - `[:swoosh, :deliver, :exception]`: occurs when `Mailer.deliver/2` throws an exception.
  - `[:swoosh, :deliver_many, :start]`: occurs when `Mailer.deliver_many/2` begins.
  - `[:swoosh, :deliver_many, :stop]`: occurs when `Mailer.deliver_many/2` completes.
  - `[:swoosh, :deliver_many, :exception]`: occurs when `Mailer.deliver_many/2` throws an exception.

  ### Capturing events

  You can capture events by calling `:telemetry.attach/4` or `:telemetry.attach_many/4`. Here's an example:

      # tracks the number of emails sent successfully/errored
      defmodule MyHandler do
        def handle_event([:swoosh, :deliver, :stop], _measurements, metadata, _config) do
          StatsD.increment("mail.sent.success", 1, %{mailer: metadata.mailer})
        end

        def handle_event([:swoosh, :deliver, :exception], _measurements, metadata, _config) do
          StatsD.increment("mail.sent.failure", 1, %{mailer: metadata.mailer})
        end

        def handle_event([:swoosh, :deliver_many, :stop], _measurements, metadata, _config) do
          StatsD.increment("mail.sent.success", length(metadata.emails), %{mailer: metadata.mailer})
        end

        def handle_event([:swoosh, :deliver_many, :exception], _measurements, metadata, _config) do
          StatsD.increment("mail.sent.failure", length(metadata.emails), %{mailer: metadata.mailer})
        end
      end

  in `c:Application.start/2` callback:

      :telemetry.attach_many("my-handler", [
         [:swoosh, :deliver, :stop],
         [:swoosh, :deliver, :exception],
         [:swoosh, :deliver_many, :stop],
         [:swoosh, :deliver_many, :exception],
       ], &MyHandler.handle_event/4, nil)
  """

  alias Swoosh.DeliveryError

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      alias Swoosh.Mailer

      @otp_app Keyword.fetch!(opts, :otp_app)
      @mailer_config opts

      @spec deliver(Swoosh.Email.t(), Keyword.t()) :: {:ok, term} | {:error, term}
      def deliver(email, config \\ [])

      def deliver(email, config) do
        metadata = %{email: email, config: config}

        instrument(:deliver, metadata, fn ->
          Mailer.deliver(email, parse_config(config))
        end)
      end

      @spec deliver!(Swoosh.Email.t(), Keyword.t()) :: term | no_return
      def deliver!(email, config \\ [])

      def deliver!(email, config) do
        case deliver(email, config) do
          {:ok, result} -> result
          {:error, reason} -> raise DeliveryError, reason: reason
        end
      end

      @spec deliver_many(list(%Swoosh.Email{}), Keyword.t()) :: {:ok, term} | {:error, term}
      def deliver_many(emails, config \\ [])

      def deliver_many(emails, config) do
        metadata = %{emails: emails, config: config}

        instrument(:deliver_many, metadata, fn ->
          Mailer.deliver_many(emails, parse_config(config))
        end)
      end

      @on_load :validate_dependency

      @doc false
      def validate_dependency do
        adapter = Keyword.get(parse_config([]), :adapter)
        Mailer.validate_dependency(adapter)
      end

      defp parse_config(config) do
        Mailer.parse_config(@otp_app, __MODULE__, @mailer_config, config)
      end

      defp instrument(key, metadata, fun) do
        metadata = Map.merge(metadata, %{mailer: __MODULE__})

        :telemetry.span([:swoosh, key], metadata, fn ->
          case fun.() do
            {:ok, result} -> {{:ok, result}, Map.put(metadata, :result, result)}
            {:error, error} -> {{:error, error}, Map.put(metadata, :error, error)}
          end
        end)
      end
    end
  end

  def deliver(%Swoosh.Email{from: nil}, _config) do
    {:error, :from_not_set}
  end

  def deliver(%Swoosh.Email{from: {_name, address}}, _config)
      when address in ["", nil] do
    {:error, :from_not_set}
  end

  def deliver(%Swoosh.Email{} = email, config) do
    adapter = Keyword.fetch!(config, :adapter)

    :ok = adapter.validate_config(config)
    adapter.deliver(email, config)
  end

  def deliver_many(emails, config) do
    adapter = Keyword.fetch!(config, :adapter)

    :ok = adapter.validate_config(config)
    adapter.deliver_many(emails, config)
  end

  @doc """
  Parse configs in the following order, later ones taking priority:

  1. mix configs
  2. compiled configs in Mailer module
  3. dynamic configs passed into the function
  4. system envs
  """
  def parse_config(otp_app, mailer, mailer_config, dynamic_config) do
    Application.get_env(otp_app, mailer, [])
    |> Keyword.merge(mailer_config)
    |> Keyword.merge(dynamic_config)
    |> Swoosh.Mailer.interpolate_env_vars()
  end

  @doc """
  Interpolate system environment variables in the configuration.

  This function will transform all the {:system, "ENV_VAR"} tuples into their
  respective values grabbed from the process environment.
  """
  def interpolate_env_vars(config) do
    Enum.map(config, fn
      {key, {:system, env_var}} -> {key, System.get_env(env_var)}
      {key, value} -> {key, value}
    end)
  end

  @doc false
  def validate_dependency(adapter) do
    require Logger

    with adapter when not is_nil(adapter) <- adapter,
         {:module, _} <- Code.ensure_loaded(adapter),
         true <- function_exported?(adapter, :validate_dependency, 0),
         :ok <- adapter.validate_dependency() do
      :ok
    else
      no_match when no_match in [nil, false] ->
        :ok

      {:error, :nofile} ->
        Logger.error("#{adapter} does not exist")
        :abort

      {:error, deps} when is_list(deps) ->
        Logger.error(Swoosh.Mailer.missing_deps_message(adapter, deps))
        :abort
    end
  end

  @doc false
  def missing_deps_message(adapter, deps) do
    deps =
      deps
      |> Enum.map(fn
        {lib, module} -> "#{module} from #{inspect(lib)}"
        module -> inspect(module)
      end)
      |> Enum.map(&"\n- #{&1}")

    """
    The following dependencies are required to use #{inspect(adapter)}:
    #{deps}
    """
  end
end
