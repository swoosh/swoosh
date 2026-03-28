defmodule Swoosh.Adapters.Sandbox.Storage do
  @moduledoc false

  use GenServer

  @table :swoosh_sandbox_emails

  # Public API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def checkout do
    GenServer.call(__MODULE__, {:checkout, self()})
  end

  def checkin do
    GenServer.call(__MODULE__, {:checkin, self()})
  end

  def allow(owner_pid, allowed_pid) do
    GenServer.call(__MODULE__, {:allow, owner_pid, allowed_pid})
  end

  def set_shared(pid) do
    GenServer.call(__MODULE__, {:set_shared, pid})
  end

  def get_shared do
    GenServer.call(__MODULE__, :get_shared)
  end

  def find_owner(callers) do
    GenServer.call(__MODULE__, {:find_owner, callers})
  end

  def push(owner_pid, email) do
    GenServer.call(__MODULE__, {:push, owner_pid, email})
  end

  def all(owner_pid) do
    case :ets.lookup(@table, owner_pid) do
      [{^owner_pid, emails}] -> emails
      [] -> []
    end
  end

  def flush(owner_pid) do
    GenServer.call(__MODULE__, {:flush, owner_pid})
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    :ets.new(@table, [:set, :named_table, :public, {:read_concurrency, true}])
    {:ok, %{owners: MapSet.new(), allowed: %{}, shared: nil, monitors: %{}}}
  end

  @impl true
  def handle_call({:checkout, pid}, _from, state) do
    if MapSet.member?(state.owners, pid) do
      {:reply, {:error, :already_checked_out}, state}
    else
      ref = Process.monitor(pid)
      :ets.insert(@table, {pid, []})

      new_state = %{
        state
        | owners: MapSet.put(state.owners, pid),
          monitors: Map.put(state.monitors, ref, pid)
      }

      {:reply, :ok, new_state}
    end
  end

  def handle_call({:checkin, pid}, _from, state) do
    {:reply, :ok, do_checkin(pid, state)}
  end

  def handle_call({:allow, owner_pid, allowed_pid}, _from, state) do
    if MapSet.member?(state.owners, owner_pid) do
      {:reply, :ok, %{state | allowed: Map.put(state.allowed, allowed_pid, owner_pid)}}
    else
      {:reply, {:error, :not_checked_out}, state}
    end
  end

  def handle_call({:set_shared, pid}, _from, state) do
    {:reply, :ok, %{state | shared: pid}}
  end

  def handle_call(:get_shared, _from, state) do
    {:reply, state.shared, state}
  end

  def handle_call({:find_owner, callers}, _from, state) do
    result =
      Enum.find_value(callers, fn pid ->
        cond do
          MapSet.member?(state.owners, pid) -> {:ok, pid}
          owner = Map.get(state.allowed, pid) -> {:ok, owner}
          true -> nil
        end
      end)

    {:reply, result || :no_owner, state}
  end

  def handle_call({:push, owner_pid, email}, _from, state) do
    existing =
      case :ets.lookup(@table, owner_pid) do
        [{^owner_pid, emails}] -> emails
        [] -> []
      end

    :ets.insert(@table, {owner_pid, [email | existing]})
    send(owner_pid, {:email, email})
    {:reply, :ok, state}
  end

  def handle_call({:flush, owner_pid}, _from, state) do
    emails =
      case :ets.lookup(@table, owner_pid) do
        [{^owner_pid, emails}] -> emails
        [] -> []
      end

    :ets.insert(@table, {owner_pid, []})
    {:reply, emails, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, pid, _}, state) do
    if Map.has_key?(state.monitors, ref) do
      {:noreply, do_checkin(pid, state)}
    else
      {:noreply, state}
    end
  end

  # Internal helpers

  defp do_checkin(pid, state) do
    :ets.delete(@table, pid)

    {to_demonitor, monitors} =
      Enum.split_with(state.monitors, fn {_ref, p} -> p == pid end)

    Enum.each(to_demonitor, fn {ref, _} -> Process.demonitor(ref, [:flush]) end)

    allowed =
      state.allowed
      |> Enum.reject(fn {allowed_pid, owner_pid} ->
        owner_pid == pid or allowed_pid == pid
      end)
      |> Map.new()

    %{
      state
      | owners: MapSet.delete(state.owners, pid),
        allowed: allowed,
        shared: if(state.shared == pid, do: nil, else: state.shared),
        monitors: Map.new(monitors)
    }
  end
end
