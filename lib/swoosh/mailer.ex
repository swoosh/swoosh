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

  Note that the configuration is set into your mailer at compile time. If you
  need to reference config at runtime you can use a tuple like
  `{:system, "ENV_VAR"}`.

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
  """

  alias Swoosh.DeliveryError

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      {otp_app, adapter, config} = Swoosh.Mailer.parse_config(__MODULE__, opts)

      @adapter adapter
      @config config

      def __adapter__, do: @adapter

      def deliver(email, config \\ [])
      def deliver(email, config) do
        Swoosh.Mailer.deliver(@adapter, email, Keyword.merge(@config, config))
      end

      def deliver!(email, config \\ [])
      def deliver!(email, config) do
        case deliver(email, config) do
          {:ok, result} -> result
          {:error, reason} -> raise DeliveryError, reason: reason
          {:error, reason, payload} -> raise DeliveryError, reason: reason, payload: payload
        end
      end
    end
  end

  def deliver(_adapter, %Swoosh.Email{from: nil}, _config) do
    {:error, :from_not_set}
  end
  def deliver(_adapter, %Swoosh.Email{from: {_name, address}}, _config) when address in ["", nil] do
    {:error, :from_not_set}
  end
  def deliver(adapter, %Swoosh.Email{} = email, config) do
    config = Swoosh.Mailer.parse_runtime_config(config)

    :ok = adapter.validate_config(config)
    adapter.deliver(email, config)
  end

  @doc """
  Parses the OTP configuration at compile time.
  """
  def parse_config(mailer, opts) do
    otp_app = Keyword.fetch!(opts, :otp_app)
    config = Application.get_env(otp_app, mailer, [])
    adapter = opts[:adapter] || config[:adapter]

    unless adapter do
      raise ArgumentError, "missing :adapter configuration in " <>
                           "config #{inspect otp_app}, #{inspect mailer}"
    end

    {otp_app, adapter, config}
  end

  @doc """
  Parses the OTP configuration at run time.

  This function will transform all the {:system, "ENV_VAR"} tuples into their
  respective values grabbed from the process environment.
  """
  def parse_runtime_config(config) do
    Enum.map config, fn
      {key, {:system, env_var}} -> {key, System.get_env(env_var)}
      {key, value} -> {key, value}
    end
  end
end

