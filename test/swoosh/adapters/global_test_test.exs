defmodule Swoosh.Adapters.GlobalTestTest do
  use ExUnit.Case

  import Swoosh.Email
  import Swoosh.TestAssertions

  defmodule Mailer do
    use GenServer

    @impl true
    def init([]) do
      {:ok, []}
    end

    def deliver(pid, %Swoosh.Email{} = email) do
      GenServer.call(pid, {:deliver, email})
    end

    @impl true
    def handle_call({:deliver, email}, _from, state) do
      {:ok, _} = Swoosh.Adapters.Test.deliver(email, nil)
      {:reply, email, state}
    end
  end

  setup :set_swoosh_global

  test "global deliver" do
    email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Global async Avengers!")

    {:ok, pid} = GenServer.start_link(Mailer, [])

    Mailer.deliver(pid, email)

    assert_email_sent(subject: "Global async Avengers!")
  end

  describe "with a named shared test process" do
    setup do
      Process.register(self(), :swoosh_collector)

      email =
        new()
        |> from("tony.stark@example.com")
        |> to("steve.rogers@example.com")
        |> subject("Named Avengers!")

      {:ok, email: email, destinations: [:swoosh_collector, {:swoosh_collector, node()}]}
    end

    test "delivers to it", %{email: email, destinations: destinations} do
      for destination <- destinations do
        Application.put_env(:swoosh, :shared_test_process, destination)

        assert {:ok, %{}} = Swoosh.Adapters.Test.deliver(email, nil)
        assert_email_sent(subject: "Named Avengers!")
      end
    end

    test "fails deliveries when it has a failure armed", %{
      email: email,
      destinations: destinations
    } do
      for destination <- destinations do
        Application.put_env(:swoosh, :shared_test_process, destination)
        Swoosh.Adapters.Test.fail_next_delivery(:timeout, 2)

        task = Task.async(fn -> Swoosh.Adapters.Test.deliver(email, nil) end)

        assert {:error, :timeout} = Task.await(task)
        assert {:error, :timeout} = Swoosh.Adapters.Test.deliver(email, nil)
        refute_email_sent()
      end
    end
  end
end
