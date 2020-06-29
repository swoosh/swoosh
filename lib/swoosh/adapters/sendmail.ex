defmodule Swoosh.Adapters.Sendmail do
  @moduledoc ~S"""
  An adapter that sends email using the sendmail binary.

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Sendmail,
        cmd_path: "/usr/bin/sendmail",
        cmd_args: "-N delay,failure,success",
        qmail: true # Default false

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end
  """

  use Swoosh.Adapter, required_deps: [gen_smtp: :mimemail]

  alias Swoosh.Email
  alias Swoosh.Adapters.SMTP.Helpers

  @impl true
  def deliver(%Email{} = email, config) do
    body = Helpers.body(email, config)
    port = Port.open({:spawn, cmd(email, config)}, [:binary])
    Port.command(port, body)
    Port.close(port)
    {:ok, %{}}
  end

  @doc false
  def cmd(email, config) do
    sender = Helpers.sender(email) |> shell_escape()
    "#{cmd_path(config)} -f#{sender}#{cmd_args(config)}"
  end

  @doc false
  def cmd_path(config) do
    default =
      case config[:qmail] do
        true -> "/var/qmail/bin/qmail-inject"
        _ -> "/usr/sbin/sendmail"
      end

    config[:cmd_path] || default
  end

  @doc false
  def cmd_args(config) do
    case config[:qmail] do
      true -> ""
      _ -> " -oi -t"
    end
    <>
    case config[:cmd_args] do
      nil -> ""
      args -> " #{args}"
    end
  end

  @doc false
  def shell_escape(s) do
    "'" <> String.replace(s, "'", "'\\''") <> "'"
  end
end
