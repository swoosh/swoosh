defmodule Swoosh.Adapters.Local.Storage.MemoryTest do
  use ExUnit.Case

  alias Swoosh.Adapters.Local.Storage.Memory

  setup do
    Memory.delete_all()
    :ok
  end

  test "start_link/0 starts with an empty mailbox" do
    {:ok, pid} = GenServer.start_link(Memory, [])
    count = GenServer.call(pid, :all) |> Enum.count
    assert count == 0
  end

  test "push an email into the mailbox" do
    Memory.push(%Swoosh.Email{})
    assert Memory.all() |> Enum.count() == 1
  end

  test "get an email from the mailbox" do
    Memory.push(%Swoosh.Email{})
    %Swoosh.Email{headers: %{"Message-ID" => id}} = Memory.push(%Swoosh.Email{subject: "Hello, Avengers!"})
    Memory.push(%Swoosh.Email{})
    assert %Swoosh.Email{subject: "Hello, Avengers!"} = Memory.get(id)
  end

  test "pop an email from the mailbox" do
    Memory.push(%Swoosh.Email{subject: "Test 1"})
    Memory.push(%Swoosh.Email{subject: "Test 2"})
    assert Memory.all() |> Enum.count() == 2

    email = Memory.pop()
    assert email.subject == "Test 2"
    assert Memory.all() |> Enum.count() == 1

    email = Memory.pop()
    assert email.subject == "Test 1"
    assert Memory.all() |> Enum.count() == 0
  end

  test "delete all the emails in the mailbox" do
    Memory.push(%Swoosh.Email{})
    Memory.push(%Swoosh.Email{})
    assert Memory.all() |> Enum.count() == 2

    Memory.delete_all()
    assert Memory.all() |> Enum.count() == 0
  end
end
