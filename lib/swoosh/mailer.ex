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
      iex> email = new |> from("tony@stark.com") |> to("steve@rogers.com")
      %Swoosh.Email{from: {"", "tony@stark.com"}, ...}
      iex> Mailer.deliver(email)
      :ok

  You can also pass an extra config argument to `deliver/2` that will be merged
  with your Mailer's config:

      # in an IEx console
      iex> email = new |> from("tony@stark.com") |> to("steve@rogers.com")
      %Swoosh.Email{from: {"", "tony@stark.com"}, ...}
      iex> Mailer.deliver(email, domain: "jarvis.com")
      :ok
  """

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
    end
  end

  def deliver(_adapter, %Swoosh.Email{from: nil}, _config) do
    raise ArgumentError, "expected \"from\" to be set"
  end
  def deliver(_adapter, %Swoosh.Email{from: {_name, nil}}, _config) do
    raise ArgumentError, "expected \"from\" address to be set"
  end
  def deliver(_adapter, %Swoosh.Email{to: nil}, _config) do
    raise ArgumentError, "expected \"to\" to be set"
  end
  def deliver(_adapter, %Swoosh.Email{to: []}, _config) do
    raise ArgumentError, "expected \"to\" not to be empty"
  end
  def deliver(_adapter, %Swoosh.Email{subject: nil}, _config) do
    raise ArgumentError, "expected \"subject\" to be set"
  end
  def deliver(_adapter, %Swoosh.Email{html_body: nil, text_body: nil}, _config) do
    raise ArgumentError, "expected \"html_body\" or \"text_body\" to be set"
  end
  def deliver(adapter, %Swoosh.Email{} = email, config) do
    config = config |> Swoosh.Mailer.parse_runtime_config()

    case adapter.validate_config(config) do
      {:ok} -> adapter.deliver(email, config)
      {:error, message} -> {:error, message}
    end
  end
  def deliver(_adapter, email, _config) do
    raise ArgumentError, "expected %Swoosh.Email{}, got #{inspect email}"
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

