defmodule Swoosh.Adapters.Local.Storage.Manager do
  @moduledoc ~S"""
  Manages the creation/monitoring of the global in-memory storage driver,
  `Swoosh.Adapters.Local.Storage.Memory`
  """

  use GenServer

  def start_link(args \\ []) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @doc false
  def init(_args) do
    {:ok, restart_or_monitor()}
  end

  @doc false
  def handle_info({:DOWN, _, :process, _, :normal}, _) do
    # In case the process is stopped normally with `stop/0`
    {:stop, :normal, %{}}
  end

  def handle_info({:DOWN, _, :process, _, _reason}, _) do
    # Try to either restart the global GenServer or monitor the newly
    # created one.
    Process.sleep(:rand.uniform(1800) + 200)
    {:noreply, restart_or_monitor()}
  end

  defp restart_or_monitor() do
    case Swoosh.Adapters.Local.Storage.Memory.start() do
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end
    |> Process.monitor()

    %{}
  end
end
