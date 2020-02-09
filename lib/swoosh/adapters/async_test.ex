defmodule Swoosh.Adapters.AsyncTest do
  use Swoosh.Adapter

  def deliver(email, _config) do
    receive do
      {:email, pid} ->
        send(pid, {:email, self(), email})
    after
      500 -> raise "damn"
    end

    {:ok, %{}}
  end
end
