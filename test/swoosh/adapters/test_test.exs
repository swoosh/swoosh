defmodule Swoosh.Adapters.TestTest do
  use ExUnit.Case, async: true

  import Swoosh.Email
  import Swoosh.TestAssertions

  defp deliver(%Swoosh.Email{} = email) do
    {:ok, _} = Swoosh.Adapters.Test.deliver(email, nil)
    email
  end

  defp deliver_many(emails = [_ | _]) do
    {:ok, _} = Swoosh.Adapters.Test.deliver_many(emails, nil)
    emails
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

  describe "deliver_many/2" do
    test "We can deliver_many from a task" do
      Task.start(fn ->
        chalmers =
          new()
          |> from("skinner@example.com")
          |> to("super_nintendo_chalmers@example.com")
          |> subject("Steamed Hams?")

        mother =
          new()
          |> from("skinner@example.com")
          |> to("mother@example.com")
          |> subject("Steamed Hams?")

        deliver_many([chalmers, mother])
      end)

      assert_receive {:emails, emails}
      assert [chalmers, mother] = emails
      assert chalmers.from == {"", "skinner@example.com"}
      assert chalmers.to == [{"", "super_nintendo_chalmers@example.com"}]
      assert chalmers.subject == "Steamed Hams?"

      assert mother.from == {"", "skinner@example.com"}
      assert mother.to == [{"", "mother@example.com"}]
      assert mother.subject == "Steamed Hams?"
    end

    test "we can deliver_many in a supervised task" do
      {:ok, sup} = start_supervised(Task.Supervisor)

      Task.Supervisor.async_nolink(sup, fn ->
        tony =
          new()
          |> from("tony.stark@example.com")
          |> to("steve.rogers@example.com")
          |> subject("Async Super Avengers!")

        mike =
          new()
          |> from("mike.wazowski.com")
          |> to("sulley@example.com")
          |> subject("Go get him googly bear")

        deliver_many([tony, mike])
      end)

      assert_receive {:emails, emails}
      assert [chalmers, mother] = emails
      assert chalmers.from == {"", "tony.stark@example.com"}
      assert chalmers.to == [{"", "steve.rogers@example.com"}]
      assert chalmers.subject == "Async Super Avengers!"

      assert mother.from == {"", "mike.wazowski.com"}
      assert mother.to == [{"", "sulley@example.com"}]
      assert mother.subject == "Go get him googly bear"
    end
  end
end
