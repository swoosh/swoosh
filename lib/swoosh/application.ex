defmodule Swoosh.Application do
  use Application

  require Logger

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Swoosh.Adapters.Local.Storage.Memory, [])
    ]

    children =
      if Application.get_env(:swoosh, :serve_mailbox) do
        cowboy = Application.ensure_all_started(:cowboy)
        plug = Application.ensure_all_started(:plug)
        port = Application.get_env(:swoosh, :preview_port, 4000)

        case {cowboy, plug} do
          {{:ok, _}, {:ok, _}} ->
            Logger.info("Running Swoosh mailbox preview server with Cowboy using http on port #{port}")
            [Plug.Adapters.Cowboy.child_spec(:http, Plug.Swoosh.MailboxPreview, [], port: port) | children]
          _ ->
            Logger.warn("Could not start preview server on port #{port}. Please ensure plug and cowboy" <>
              " are in your dependency list.")
            []
        end
      else
        children
      end

    opts = [strategy: :one_for_one, name: Swoosh.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
