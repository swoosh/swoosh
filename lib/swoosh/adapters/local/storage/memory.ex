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
  def start_link(args \\ []) do
    case GenServer.start_link(__MODULE__, args, name: {:global, __MODULE__}) do
      {:ok, pid} ->
        {:ok, pid}
      {:error, {:already_started, pid}} ->
        Process.link(pid)
        {:ok, pid}
    end
  end

  @doc """
  Stops the server
  """
  def stop() do
    GenServer.stop({:global, __MODULE__})
  end

  @doc ~S"""
  Push a new email into the mailbox.

  In order to make it easy to fetch a single email, a `Message-ID` header is
  added to the email before being stored.

  ## Examples

      iex> email = new |> from("tony.stark@example.com")
      %Swoosh.Email{from: {"", "tony.stark@example.com"}, [...]}
      iex> Memory.push(email)
      %Swoosh.Email{from: {"", "tony.stark@example.com"}, headers: %{"Message-ID": "a1b2c3"}, [...]}
  """
  def push(email) do
    GenServer.call({:global, __MODULE__}, {:push, email})
  end

  @doc ~S"""
  Pop the last email from the mailbox.

  ## Examples

      iex> email = new |> from("tony.stark@example.com")
      %Swoosh.Email{from: {"", "tony.stark@example.com"}, [...]}
      iex> Memory.push(email)
      %Swoosh.Email{from: {"", "tony.stark@example.com"}, headers: %{"Message-ID": "a1b2c3"}, [...]}
      iex> Memory.all() |> Enum.count()
      1
      iex> Memory.pop()
      %Swoosh.Email{from: {"", "tony.stark@example.com"}, headers: %{"Message-ID": "a1b2c3"}, [...]}
      iex> Memory.all() |> Enun.count()
      0
  """
  def pop() do
    GenServer.call({:global, __MODULE__}, :pop)
  end

  @doc ~S"""
  Get a specific email from the mailbox.

  ## Examples

      iex> email = new |> from("tony.stark@example.com")
      %Swoosh.Email{from: {"", "tony.stark@example.com"}, [...]}
      iex> Memory.push(email)
      %Swoosh.Email{from: {"", "tony.stark@example.com"}, headers: %{"Message-ID": "a1b2c3"}, [...]}
      iex> Memory.get("A1B2C3")
      %Swoosh.Email{from: {"", "tony.stark@example.com"}, headers: %{"Message-ID": "a1b2c3"}, [...]}
  """
  def get(id) do
    GenServer.call({:global, __MODULE__}, {:get, id})
  end

  @doc ~S"""
  List all the emails in the mailbox.

  ## Examples

      iex> email = new |> from("tony.stark@example.com")
      %Swoosh.Email{from: {"", "tony.stark@example.com"}, [...]}
      iex> Memory.push(email)
      %Swoosh.Email{from: {"", "tony.stark@example.com"}, headers: %{"Message-ID": "a1b2c3"}, [...]}
      iex> Memory.all()
      [%Swoosh.Email{from: {"", "tony.stark@example.com"}, headers: %{"Message-ID": "a1b2c3"}, [...]}]
  """
  def all() do
    GenServer.call({:global, __MODULE__}, :all)
  end

  @doc ~S"""
  Delete all the emails currently in the mailbox.

  ## Examples

      iex> email = new |> from("tony.stark@example.com")
      %Swoosh.Email{from: {"", "tony.stark@example.com"}, [...]}
      iex> Memory.push(email)
      %Swoosh.Email{from: {"", "tony.stark@example.com"}, headers: %{"Message-ID": "a1b2c3"}, [...]}
      iex> Memory.delete_all()
      :ok
      iex> Memory.list()
      []
  """
  def delete_all() do
    GenServer.call({:global, __MODULE__}, :delete_all)
  end

  # Callbacks

  def init(_args) do
    {:ok, []}
  end

  def handle_call({:push, email}, _from, emails) do
    id = :crypto.strong_rand_bytes(16) |> Base.encode16() |> String.downcase()
    email =
      email
      |> Swoosh.Email.header("Message-ID", id)
      |> Swoosh.Email.put_private(:sent_at, DateTime.utc_now() |> DateTime.to_iso8601())

    attachments_with_data =
      Enum.map(email.attachments, fn attachment ->
        %{attachment | data: Swoosh.Attachment.get_content(attachment)}
      end)

    email = %{email | attachments: attachments_with_data}
    {:reply, email, [email | emails]}
  end

  def handle_call(:pop, _from, [h | t]) do
    {:reply, h, t}
  end

  def handle_call({:get, id}, _from, emails) do
    email =
      Enum.find(emails, fn %{headers: %{"Message-ID" => msg_id}} ->
        msg_id == String.downcase(id)
      end)

    {:reply, email, emails}
  end

  def handle_call(:all, _from, emails) do
    {:reply, emails, emails}
  end

  def handle_call(:delete_all, _from, _emails) do
    {:reply, :ok, []}
  end
end
