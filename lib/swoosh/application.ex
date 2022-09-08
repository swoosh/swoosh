defmodule Swoosh.Application do
  use Application

  require Logger

  def start(_type, _args) do
    Swoosh.ApiClient.init()

    children =
      []
      |> runtime_children(:local)
      |> runtime_children(:serve_mailbox)

    opts = [strategy: :one_for_one, name: Swoosh.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp runtime_children(children, :local) do
    if Application.get_env(:swoosh, :local, true) do
      [Swoosh.Adapters.Local.Storage.Manager | children]
    else
      children
    end
  end

  if Code.ensure_loaded?(Plug.Cowboy) do
    defp runtime_children(children, :serve_mailbox) do
      if Application.get_env(:swoosh, :serve_mailbox) do
        {:ok, _} = Application.ensure_all_started(:plug_cowboy)

        port = Application.get_env(:swoosh, :preview_port, 4000)

        Logger.info(
          "Running Swoosh mailbox preview server with Cowboy using http on port #{port}"
        )

        [
          Plug.Cowboy.child_spec(
            scheme: :http,
            plug: Plug.Swoosh.MailboxPreview,
            options: [port: port]
          )
          | children
        ]
      else
        children
      end
    end
  else
    defp runtime_children(children, :serve_mailbox) do
      if Application.get_env(:swoosh, :serve_mailbox) do
        Logger.warn("""
        Could not start preview server.

        Please add :plug_cowboy to your dependencies:
          {:plug_cowboy, ">= 1.0.0"}

        And then recompile swoosh:

          mix deps.get
          mix deps.clean --build swoosh
          mix deps.compile swoosh
        """)
      end

      children
    end
  end
end
