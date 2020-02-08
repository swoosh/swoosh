defmodule Swoosh.TestTest do
  use ExUnit.Case, async: true

  import Swoosh.Email
  import Swoosh.TestAssertions

  defp deliver(%Swoosh.Email{} = email) do
    {:ok, _} = Swoosh.Adapters.Test.deliver(email, nil)
    email
  end

  test "send email in a task" do
    Task.start(fn ->
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Async Avengers!")
      |> deliver()
    end)

    Process.sleep(100)
    assert_email_sent(subject: "Async Avengers!")
  end

  test "send email via supervised task" do
    {:ok, sup} = start_supervised(Task.Supervisor)

    Task.Supervisor.async_nolink(sup, fn ->
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Async Super Avengers!")
      |> deliver()
    end)

    Process.sleep(100)
    assert_email_sent(subject: "Async Super Avengers!")
  end
end
