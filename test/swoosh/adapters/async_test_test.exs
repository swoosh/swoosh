defmodule Swoosh.Adapters.AsyncTestTest do
  use ExUnit.Case, async: true

  import Swoosh.Email
  import Swoosh.TestAssertions

  defmodule SendingInModule do
    use GenServer

    def start_link(_) do
      GenServer.start_link(__MODULE__, [])
    end

    def init(_) do
      {:ok, []}
    end

    def handle_call({:send, email}, _from, state) do
      deliver(email)
      {:reply, :ok, state}
    end

    def handle_cast({:send, email}, state) do
      deliver(email)
      {:noreply, state}
    end

    defp deliver(email) do
      Swoosh.Adapters.AsyncTest.deliver(email, nil)
    end
  end

  setup do
    {:ok, pid} = start_supervised(SendingInModule)

    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Async Super Avengers!")

    {:ok, pid: pid, email: email}
  end

  test "send email in call", %{pid: pid, email: email} do
    spawn fn -> GenServer.call(pid, {:send, email}) end
    Process.sleep(100)
    assert_email_sending_in pid, email
  end

  test "send email in cast", %{pid: pid, email: email} do
    GenServer.cast(pid, {:send, email})
    assert_email_sending_in pid, email
  end
end
