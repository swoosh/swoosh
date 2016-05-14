defmodule Swoosh.Adapters.Local.Storage.Memory do
  @moduledoc ~S"""
  In-memory storage driver used by the
  [Swoosh.Adapters.Local](Swoosh.Adapters.Local.html) module.

  The emails in this mailbox are stored in memory and won't persist once your
  application is stopped.
  """

  use GenServer

  @doc """
  Starts the server
  """
  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Stops the server
  """
  def stop() do
    GenServer.stop(__MODULE__)
  end

  @doc ~S"""
  Push a new email into the mailbox.

  In order to make it easy to fetch a single email, a `Message-ID` header is
  added to the email before being stored.

  ## Examples

      iex> email = new |> from("tony@stark.com")
      %Swoosh.Email{from: {"", "tony@stark.com"}, [...]}
      iex> Memory.push(email)
      %Swoosh.Email{from: {"", "tony@stark.com"}, headers: %{"Message-ID": "A1B2C3"}, [...]}
  """
  def push(email) do
    GenServer.call(__MODULE__, {:push, email})
  end

  @doc ~S"""
  Pop the last email from the mailbox.

  ## Examples

      iex> email = new |> from("tony@stark.com")
      %Swoosh.Email{from: {"", "tony@stark.com"}, [...]}
      iex> Memory.push(email)
      %Swoosh.Email{from: {"", "tony@stark.com"}, headers: %{"Message-ID": "A1B2C3"}, [...]}
      iex> Memory.all() |> Enum.count()
      1
      iex> Memory.pop()
      %Swoosh.Email{from: {"", "tony@stark.com"}, headers: %{"Message-ID": "A1B2C3"}, [...]}
      iex> Memory.all() |> Enun.count()
      0
  """
  def pop() do
    GenServer.call(__MODULE__, :pop)
  end

  @doc ~S"""
  Get a specific email from the mailbox.

  ## Examples

      iex> email = new |> from("tony@stark.com")
      %Swoosh.Email{from: {"", "tony@stark.com"}, [...]}
      iex> Memory.push(email)
      %Swoosh.Email{from: {"", "tony@stark.com"}, headers: %{"Message-ID": "A1B2C3"}, [...]}
      iex> Memory.get("A1B2C3")
      %Swoosh.Email{from: {"", "tony@stark.com"}, headers: %{"Message-ID": "A1B2C3"}, [...]}
  """
  def get(id) do
    GenServer.call(__MODULE__, {:get, id})
  end

  @doc ~S"""
  List all the emails in the mailbox.

  ## Examples

      iex> email = new |> from("tony@stark.com")
      %Swoosh.Email{from: {"", "tony@stark.com"}, [...]}
      iex> Memory.push(email)
      %Swoosh.Email{from: {"", "tony@stark.com"}, headers: %{"Message-ID": "A1B2C3"}, [...]}
      iex> Memory.all()
      [%Swoosh.Email{from: {"", "tony@stark.com"}, headers: %{"Message-ID": "A1B2C3"}, [...]}]
  """
  def all() do
    GenServer.call(__MODULE__, :all)
  end

  @doc ~S"""
  Delete all the emails currently in the mailbox.

  ## Examples

      iex> email = new |> from("tony@stark.com")
      %Swoosh.Email{from: {"", "tony@stark.com"}, [...]}
      iex> Memory.push(email)
      %Swoosh.Email{from: {"", "tony@stark.com"}, headers: %{"Message-ID": "A1B2C3"}, [...]}
      iex> Memory.delete_all()
      :ok
      iex> Memory.list()
      []
  """
  def delete_all() do
    GenServer.call(__MODULE__, :delete_all)
  end

  # Callbacks

  def init(_args) do
    {:ok, []}
  end

  def handle_call({:push, email}, _from, state) do
    id = :crypto.rand_bytes(16) |> Base.encode16
    email = email |> Swoosh.Email.header("Message-ID", id)
    {:reply, email, [email] ++ state}
  end

  def handle_call(:pop, _from, [h|t]) do
    {:reply, h, t}
  end

  def handle_call({:get, id}, _from, state) do
    email = Enum.find(state, nil, fn %Swoosh.Email{headers: %{"Message-ID" => mid}} -> mid == id end)
    {:reply, email, state}
  end

  def handle_call(:all, _from, state) do
    {:reply, state, state}
  end

  def handle_call(:delete_all, _from, _state) do
    {:reply, :ok, []}
  end
end
