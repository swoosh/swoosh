if Code.ensure_loaded?(:gen_smtp_client) do
  defmodule Swoosh.Adapters.SMTP do
    @moduledoc ~S"""
    An adapter that sends email using the SMTP protocol.

    Underneath this adapter uses the
    [gen_smtp](https://github.com/Vagabond/gen_smtp) library.

    ## Example
        # mix.exs
        def application do
          [applications: [:swoosh, :gen_smtp]]
        end

        # config/config.exs
        config :sample, Sample.Mailer,
          adapter: Swoosh.Adapters.SMTP,
          relay: "smtp.avengers.com",
          username: "tonystark",
          password: "ilovepepperpotts",
          tls: :always,
          auth: :always,
          dkim: [
            s: "default", d: "domain.com",
            private_key: {:pem_plain, File.read!("priv/keys/domain.private")}
          ]

        # lib/sample/mailer.ex
        defmodule Sample.Mailer do
          use Swoosh.Mailer, otp_app: :sample
        end
    """

    use Swoosh.Adapter, required_config: [:relay]

    alias Swoosh.Email
    alias Swoosh.Adapters.SMTP.Helpers

    def deliver(%Email{} = email, config) do
      sender = Helpers.sender(email)
      recipients = all_recipients(email)
      body = Helpers.body(email, config)
      case :gen_smtp_client.send_blocking({sender, recipients, body}, config) do
        receipt when is_binary(receipt) -> {:ok, receipt}
        {:error, type, message} -> {:error, {type, message}}
        {:error, reason} -> {:error, reason}
      end
    end

    defp all_recipients(email) do
      [email.to, email.cc, email.bcc]
      |> Enum.concat()
      |> Enum.map(fn {_name, address} -> address end)
      |> Enum.uniq
    end
  end
end
