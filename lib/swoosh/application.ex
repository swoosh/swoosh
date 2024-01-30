defmodule Swoosh.Application do
  use Application

  require Logger

  def start(_type, _args) do
    Swoosh.ApiClient.init()
    children = local_children() ++ mailbox_children()
    opts = [strategy: :one_for_one, name: Swoosh.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp local_children do
    if Application.get_env(:swoosh, :local, true) do
      [Swoosh.Adapters.Local.Storage.Manager]
    else
      []
    end
  end

  cond do
    Code.ensure_loaded?(Plug.Cowboy) ->
      defp mailbox_children do
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
          ]
        else
          []
        end
      end

    Code.ensure_loaded?(Bandit) ->
      defp mailbox_children do
        if Application.get_env(:swoosh, :serve_mailbox) do
          {:ok, _} = Application.ensure_all_started(:bandit)
          port = Application.get_env(:swoosh, :preview_port, 4000)

          Logger.info(
            "Running Swoosh mailbox preview server with Bandit using http on port #{port}"
          )

          [Bandit.child_spec(plug: Plug.Swoosh.MailboxPreview, port: port)]
        else
          []
        end
      end

    true ->
      defp mailbox_children do
        if Application.get_env(:swoosh, :serve_mailbox) do
          Logger.warning("""
          Could not start preview server.

          Please add :plug_cowboy to your dependencies:

              {:plug_cowboy, ">= 1.0.0"}
          """)
        end

        []
      end
  end
end
