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
end
