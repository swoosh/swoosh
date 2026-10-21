defmodule Swoosh.Adapters.Sendmail do
  @moduledoc ~S"""
  An adapter that sends email using the sendmail binary.

  The binary is executed directly, not through a shell, so `cmd_path` must be an
  absolute path (a relative one is looked up in `PATH`, which is deprecated) and
  `cmd_args` must be a list of arguments. A string `cmd_args` is
  deprecated: it is split into arguments honoring quotes and backslash escapes,
  but no other shell syntax (pipes, redirects, variables) is supported.

  ## Example

      # config/config.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Sendmail,
        cmd_path: "/usr/bin/sendmail",
        cmd_args: ["-N", "delay,failure,success"],
        qmail: true # Default false

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end
  """

  use Swoosh.Adapter, required_deps: [gen_smtp: :mimemail]

  require Logger

  alias Swoosh.Email
  alias Swoosh.Adapters.SMTP.Helpers

  def deliver(%Email{} = email, config) do
    body = Helpers.body(email, [{:keep_bcc, true} | config])

    port =
      Port.open({:spawn_executable, executable(config)}, [:binary, args: cmd_args(email, config)])

    Port.command(port, body)
    Port.close(port)
    {:ok, %{}}
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
  def executable(config) do
    path = cmd_path(config)

    with :relative <- Path.type(path),
         found when is_binary(found) <- System.find_executable(path) do
      Logger.warning("Deprecated relative sendmail cmd_path.  Pass an absolute path instead.")
      found
    else
      _ -> path
    end
  end

  @doc false
  def cmd_args(email, config) do
    ["-f", Helpers.sender(email)] ++
      if(config[:qmail], do: [], else: ["-oi", "-t"]) ++
      split_args(config[:cmd_args])
  end

  defp split_args(nil), do: []
  defp split_args(args) when is_list(args), do: args

  defp split_args(args) when is_binary(args) do
    Logger.warning("Deprecated string cmd_args in sendmail config.  Pass arg list instead.")
    OptionParser.split(args)
  end
end
