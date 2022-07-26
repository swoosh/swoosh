defmodule Swoosh.Adapters.SMTP do
  @moduledoc ~S"""
  An adapter that sends email using the SMTP protocol.

  Underneath this adapter uses the
  [gen_smtp](https://github.com/Vagabond/gen_smtp) library, add it to your mix.exs file.

  ## Example
      # mix.exs
      def deps do
        [
         {:swoosh, "~> 1.3"},
         {:gen_smtp, "~> 1.1"}
        ]
      end

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.SMTP,
        relay: "smtp.avengers.com",
        username: "tonystark",
        password: "ilovepepperpotts",
        ssl: true,
        tls: :always,
        auth: :always,
        port: 1025,
        dkim: [
          s: "default", d: "domain.com",
          private_key: {:pem_plain, File.read!("priv/keys/domain.private")}
        ],
        retries: 2,
        no_mx_lookups: false

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end
  """

  use Swoosh.Adapter, required_config: [:relay], required_deps: [gen_smtp: :gen_smtp_client]

  alias Swoosh.Email
  alias Swoosh.Adapters.SMTP.Helpers

  @impl true
  def deliver(%Email{} = email, config) do
    sender = Helpers.sender(email)
    recipients = all_recipients(email)
    body = Helpers.body(email, config)

    case :gen_smtp_client.send_blocking(
           {sender, recipients, body},
           gen_smtp_config(config)
         ) do
      receipt when is_binary(receipt) -> {:ok, receipt}
      {:error, type, message} -> {:error, {type, message}}
      {:error, reason} -> {:error, reason}
    end
  end

  @config_transformations %{
    port: &String.to_integer/1,
    retries: &String.to_integer/1,
    ssl: {&String.to_atom/1, [true, false]},
    tls: {&String.to_atom/1, [:always, :never, :if_available]},
    auth: {&String.to_atom/1, [:always, :never, :if_available]},
    no_mx_lookups: {&String.to_atom/1, [true, false]}
  }
  @config_keys Map.keys(@config_transformations)

  def gen_smtp_config(config) do
    Enum.map(config, fn {key, value} -> enforce_type!(key, value) end)
  end

  defp enforce_type!(key, value) when key in @config_keys and is_binary(value) do
    case Map.get(@config_transformations, key) do
      {func, valid_values} ->
        value = func.(value)

        if value in valid_values do
          {key, value}
        else
          raise ArgumentError, """
          #{key} is not configured properly,
          got: #{value}, expected one of the following:
          #{valid_values |> Enum.map_join(", ", &inspect/1)}
          """
        end

      func ->
        {key, func.(value)}
    end
  end

  defp enforce_type!(key, value)
       when key in [:username, :password, :relay] and not is_binary(value) do
    raise ArgumentError, """
    #{key} is not configured properly,
    got: #{inspect(value)}, expected a string
    """
  end

  defp enforce_type!(key, value), do: {key, value}

  defp all_recipients(email) do
    [email.to, email.cc, email.bcc]
    |> Enum.concat()
    |> Enum.map(fn {_name, address} -> address end)
    |> Enum.uniq()
  end
end
