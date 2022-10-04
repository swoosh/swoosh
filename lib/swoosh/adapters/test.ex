defmodule Swoosh.Adapters.Test do
  @moduledoc ~S"""
  An adapter that sends emails as messages to the current process.

  This is meant to be used during tests and works with the assertions found in
  the [Swoosh.TestAssertions](Swoosh.TestAssertions.html) module.

  ## Example

      # config/test.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Test

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end
  """

  use Swoosh.Adapter

  @impl true
  def deliver(email, _config) do
    for pid <- pids() do
      send(pid, {:email, email})
    end

    {:ok, %{}}
  end

  @impl true
  def deliver_many(emails, _config) do
    for pid <- pids() do
      send(pid, {:emails, emails})
    end

    responses = for _email <- emails, do: %{}

    {:ok, responses}
  end

  # Essentially finds all of the processes that tried to send an email (in the test)
  # and sends an email to that process.
  defp pids do
    if pid = Application.get_env(:swoosh, :shared_test_process) do
      [pid]
    else
      Enum.uniq([self() | List.wrap(Process.get(:"$callers"))])
    end
  end
end
