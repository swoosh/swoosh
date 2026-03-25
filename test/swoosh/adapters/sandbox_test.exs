defmodule Swoosh.Adapters.SandboxTest do
  use ExUnit.Case, async: false

  import Swoosh.Email

  alias Swoosh.Adapters.Sandbox
  alias Swoosh.Adapters.Sandbox.Storage

  @config []

  setup do
    start_supervised!(Storage)
    :ok
  end

  defp sample_email do
    new()
    |> from("tony.stark@example.com")
    |> to("steve.rogers@example.com")
    |> subject("Avengers Assemble")
  end

  # 1. checkout + deliver
  test "checkout + deliver stores email and sends message to owner" do
    :ok = Sandbox.checkout()
    email = sample_email()
    {:ok, _} = Sandbox.deliver(email, @config)

    assert [^email] = Sandbox.all()
    assert_received {:email, ^email}
  end

  # 2. checkin cleanup
  test "checkin causes subsequent delivers to raise" do
    :ok = Sandbox.checkout()
    :ok = Sandbox.checkin()

    assert_raise RuntimeError, ~r/unregistered process/, fn ->
      Sandbox.deliver(sample_email(), @config)
    end
  end

  # 3. process monitor cleanup
  test "owner death clears inbox automatically" do
    owner =
      spawn(fn ->
        Sandbox.checkout()
        # Stay alive until told to stop
        receive do
          :stop -> :ok
        end
      end)

    # Wait for checkout to complete
    :timer.sleep(20)
    assert Storage.all(owner) == []

    # Insert an email directly to verify cleanup
    Storage.push(owner, sample_email())
    assert length(Storage.all(owner)) == 1

    # Kill the owner
    send(owner, :stop)
    ref = Process.monitor(owner)
    assert_receive {:DOWN, ^ref, :process, ^owner, _}

    # Give the Storage GenServer a moment to process the DOWN
    :timer.sleep(10)
    assert Storage.all(owner) == []
  end

  # 4. allow/2
  test "allow/2 routes delivery from allowed pid into owner inbox" do
    :ok = Sandbox.checkout()
    owner = self()

    child =
      spawn(fn ->
        {:ok, _} = Sandbox.deliver(sample_email(), @config)
      end)

    # Allow before the child delivers
    :ok = Sandbox.allow(owner, child)

    ref = Process.monitor(child)
    assert_receive {:DOWN, ^ref, :process, ^child, _}
    assert_received {:email, _}
    assert length(Sandbox.all()) == 1
  end

  # 5. $callers chain
  test "delivery from a Task (with $callers) routes into owner inbox" do
    :ok = Sandbox.checkout()
    email = sample_email()

    task = Task.async(fn -> Sandbox.deliver(email, @config) end)
    assert {:ok, _} = Task.await(task)

    assert_received {:email, ^email}
    assert [^email] = Sandbox.all()
  end

  # 6. shared mode
  test "shared mode delivers to shared owner from unrelated process" do
    :ok = Sandbox.set_shared(self())
    email = sample_email()

    pid = spawn(fn -> Sandbox.deliver(email, @config) end)
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, _}
    assert_received {:email, ^email}
    assert [^email] = Sandbox.all(self())
  end

  # 7. shared mode cleanup
  test "set_shared(nil) stops routing for unregistered processes" do
    :ok = Sandbox.set_shared(self())
    :ok = Sandbox.set_shared(nil)

    assert_raise RuntimeError, ~r/unregistered process/, fn ->
      Sandbox.deliver(sample_email(), @config)
    end
  end

  # 8. :on_unregistered :ignore
  test ":on_unregistered :ignore silently returns ok" do
    assert {:ok, _} = Sandbox.deliver(sample_email(), on_unregistered: :ignore)
  end

  # 9. multiple concurrent owners — no cross-contamination
  test "concurrent owners each see only their own emails" do
    parent = self()

    owner1 =
      spawn(fn ->
        Sandbox.checkout()
        email = new() |> from("a@example.com") |> to("b@example.com") |> subject("Owner1")
        Sandbox.deliver(email, @config)
        send(parent, {:done, :owner1, Sandbox.all()})

        receive do
          :stop -> Sandbox.checkin()
        end
      end)

    owner2 =
      spawn(fn ->
        Sandbox.checkout()
        email = new() |> from("c@example.com") |> to("d@example.com") |> subject("Owner2")
        Sandbox.deliver(email, @config)
        send(parent, {:done, :owner2, Sandbox.all()})

        receive do
          :stop -> Sandbox.checkin()
        end
      end)

    assert_receive {:done, :owner1, owner1_emails}
    assert_receive {:done, :owner2, owner2_emails}

    assert length(owner1_emails) == 1
    assert hd(owner1_emails).subject == "Owner1"

    assert length(owner2_emails) == 1
    assert hd(owner2_emails).subject == "Owner2"

    send(owner1, :stop)
    send(owner2, :stop)
  end

  # 10. flush/1
  test "flush/1 returns emails and clears inbox" do
    :ok = Sandbox.checkout()
    email = sample_email()
    {:ok, _} = Sandbox.deliver(email, @config)

    assert [^email] = Sandbox.flush()
    assert [] = Sandbox.all()
  end
end
