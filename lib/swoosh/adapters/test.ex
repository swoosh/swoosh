defmodule Swoosh.Adapters.Test do
  @moduledoc ~S"""
  An adapter that sends emails as messages to the current process.

  This is meant to be used during tests and works with the assertions found in
  the [Swoosh.TestAssertions](Swoosh.TestAssertions.html) module.

  For feature, browser, and E2E tests where the email is delivered from
  request-handling or LiveView processes, use the
  [Swoosh.Adapters.Sandbox](Swoosh.Adapters.Sandbox.html) adapter instead.

  ## Example

      # config/test.exs
      config :sample, Sample.Mailer,
        adapter: Swoosh.Adapters.Test

      # lib/sample/mailer.ex
      defmodule Sample.Mailer do
        use Swoosh.Mailer, otp_app: :sample
      end

  ## Simulating delivery failures

  Use `fail_next_delivery/2` to make the next deliveries return an error, for
  example to test how your code handles a failed delivery or retries it:

      test "retries when the delivery fails" do
        Swoosh.Adapters.Test.fail_next_delivery(:timeout)

        assert {:error, :timeout} = Sample.Mailer.deliver(email)
        assert {:ok, _} = Sample.Mailer.deliver(email)
      end
  """

  use Swoosh.Adapter

  @failure_key {__MODULE__, :failure}

  @doc """
  Makes the next `count` deliveries return `{:error, reason}`.

  The failure is stored in the current process, so `async: true` tests do not
  affect each other. It applies to the deliveries whose emails would be sent to
  the current process: deliveries from the current process or from processes it
  started (such as a `Task`), or from any process when the test uses
  `Swoosh.TestAssertions.set_swoosh_global/1`.

  A failed delivery does not send the email to the test process. After `count`
  failures, deliveries succeed again.
  """
  def fail_next_delivery(reason, count \\ 1) when is_integer(count) and count > 0 do
    counter = :atomics.new(1, [])
    :atomics.put(counter, 1, count)
    Process.put(@failure_key, {counter, reason})
    :ok
  end

  def deliver(email, _config) do
    with :ok <- check_failure() do
      for pid <- pids() do
        send(pid, {:email, email})
      end

      {:ok, %{}}
    end
  end

  def deliver_many(emails, _config) do
    with :ok <- check_failure() do
      for pid <- pids() do
        send(pid, {:emails, emails})
      end

      responses = for _email <- emails, do: %{}

      {:ok, responses}
    end
  end

  defp check_failure do
    Enum.find_value(pids(), :ok, fn pid ->
      with {counter, reason} <- get_failure(pid),
           remaining when remaining >= 0 <- :atomics.sub_get(counter, 1, 1) do
        {:error, reason}
      else
        _ -> nil
      end
    end)
  end

  # `:shared_test_process` may also be a registered name or `{name, node}`.
  # Only the dictionary of a local process can be read.
  defp get_failure({name, name_node}) when name_node == node(), do: get_failure(name)
  # An unregistered name resolves to nil, which must not be looked up again.
  defp get_failure(nil), do: nil
  defp get_failure(name) when is_atom(name), do: get_failure(Process.whereis(name))
  defp get_failure(pid) when pid == self(), do: Process.get(@failure_key)

  defp get_failure(pid) when is_pid(pid) and node(pid) == node() do
    with {:dictionary, dictionary} <- Process.info(pid, :dictionary),
         {_key, failure} <- List.keyfind(dictionary, @failure_key, 0) do
      failure
    else
      _ -> nil
    end
  end

  defp get_failure(_remote), do: nil

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
