defmodule Swoosh.Adapters.Sandbox do
  @moduledoc ~S"""
  A sandbox adapter for email delivery in tests, analogous to
  [`Ecto.Adapters.SQL.Sandbox`](https://hexdocs.pm/ecto_sql/Ecto.Adapters.SQL.Sandbox.html).

  Each test registers as an owner via `checkout/0`.  All emails delivered from
  that test process or its `$callers` chain are routed to the test's private
  inbox.  This makes email assertions safe with `async: true`.

  Compatible with `Swoosh.TestAssertions` — the owner process receives
  `{:email, email}` messages so `assert_email_sent/1` continues to work.

  ## Setup

  In `config/test.exs`:

      config :my_app, MyApp.Mailer, adapter: Swoosh.Adapters.Sandbox

      # Disable the HTTP API client — it is not needed for test adapters.
      config :swoosh, :api_client, false

  In `test/test_helper.exs`, start the storage process before `ExUnit.start()`:

      {:ok, _} = Swoosh.Adapters.Sandbox.Storage.start_link([])

  ## Unit and integration tests

  Call `checkout/0` in setup and `checkin/0` on exit.  Tests can be
  `async: true` — each test process has its own isolated inbox.

      setup do
        :ok = Swoosh.Adapters.Sandbox.checkout()
        on_exit(&Swoosh.Adapters.Sandbox.checkin/0)
      end

  ## Phoenix integration (async-safe browser tests)

  In browser/E2E tests the web server spawns request-handling processes
  independently, so they have no `$callers` ancestry back to the test process.
  A plug and a LiveView hook solve this: each process is explicitly allowed into
  the test's sandbox via a token embedded in the `user-agent` header.

  ### With PhoenixTest.Playwright

  [PhoenixTest.Playwright](https://hexdocs.pm/phoenix_test_playwright/) 0.13+
  unconditionally sets the browser user-agent to
  `BeamMetadata (...)` Ecto metadata.  Derive the Swoosh sandbox owner from
  that metadata rather than embedding a separate token.

  **1. Add a plug to your endpoint** (e.g. `lib/my_app_web/plug/swoosh_sandbox.ex`):

      defmodule MyAppWeb.Plug.SwooshSandbox do
        import Plug.Conn

        def init(opts), do: opts

        def call(conn, _opts) do
          conn
          |> get_req_header("user-agent")
          |> List.first()
          |> allow()

          conn
        end

        defp allow(nil), do: :ok

        defp allow(user_agent) do
          case Phoenix.Ecto.SQL.Sandbox.decode_metadata(user_agent) do
            %{owner: owner_pid} -> Swoosh.Adapters.Sandbox.allow(owner_pid, self())
            _ -> :ok
          end
        end
      end

  Register it in `endpoint.ex`, guarded by the test environment:

      if Application.compile_env(:my_app, :swoosh_sandbox, false) do
        plug MyAppWeb.Plug.SwooshSandbox
      end

  **2. Add a LiveView hook** (e.g. `lib/my_app_web/live/live_allow_swoosh_sandbox.ex`)
  and mount it on any live session that delivers email:

      defmodule MyAppWeb.LiveAllowSwooshSandbox do
        import Phoenix.LiveView

        def on_mount(:default, _params, _session, socket) do
          if connected?(socket) do
            case Phoenix.Ecto.SQL.Sandbox.decode_metadata(
                   get_connect_info(socket, :user_agent)
                 ) do
              %{owner: owner_pid} -> Swoosh.Adapters.Sandbox.allow(owner_pid, self())
              _ -> :ok
            end
          end

          {:cont, socket}
        end
      end

  Then mount it:

      live_session :default,
        on_mount: [MyAppWeb.LiveAllowSwooshSandbox] do
        ...
      end

  **3. Configure the endpoint** to pass the user-agent to LiveView connect_info:

      socket "/live", Phoenix.LiveView.Socket,
        websocket: [connect_info: [:user_agent, ...]]

  **4. Enable the plug** in `config/test.exs`:

      config :my_app, :swoosh_sandbox, true

  **5. In your test setup**, check out the sandbox.  No `encode_owner()` or
  custom `user_agent` key is needed — PTP supplies the Ecto metadata automatically:

      setup do
        :ok = Swoosh.Adapters.Sandbox.checkout()
        on_exit(&Swoosh.Adapters.Sandbox.checkin/0)
      end

  ### With Wallaby

  [Wallaby](https://hexdocs.pm/wallaby/) lets you set the user-agent freely.
  Use a plug that decodes the `SwooshSandbox (...)` token instead of Ecto metadata.

  **1. Add a plug to your endpoint** (e.g. `lib/my_app_web/plug/swoosh_sandbox.ex`):

      defmodule MyAppWeb.Plug.SwooshSandbox do
        import Plug.Conn

        def init(opts), do: opts

        def call(conn, _opts) do
          conn
          |> get_req_header("user-agent")
          |> List.first()
          |> allow()

          conn
        end

        defp allow(nil), do: :ok

        defp allow(user_agent) do
          with [_, encoded] <- Regex.run(~r/SwooshSandbox \((\S+)\)/, user_agent),
               {:ok, binary} <- Base.url_decode64(encoded),
               pid when is_pid(pid) <- :erlang.binary_to_term(binary, [:safe]) do
            Swoosh.Adapters.Sandbox.allow(pid, self())
          end

          :ok
        end
      end

  Register it in `endpoint.ex` with the same guard as above.

  **2. Add a LiveView hook** if any live sessions deliver email, following the
  same pattern as the PhoenixTest.Playwright section but decoding with the
  `SwooshSandbox` regex instead of `Phoenix.Ecto.SQL.Sandbox.decode_metadata/1`.

  **3-4.** Same `connect_info` and `config/test.exs` steps as above.

  **5. In your test setup**, pass `encode_owner()` as the `--user-agent` flag:

      setup do
        :ok = Swoosh.Adapters.Sandbox.checkout()
        token = Swoosh.Adapters.Sandbox.encode_owner()
        on_exit(&Swoosh.Adapters.Sandbox.checkin/0)

        {:ok, session} =
          Wallaby.start_session(
            capabilities: %{"goog:chromeOptions": %{args: ["--user-agent=#{token}"]}}
          )

        on_exit(fn -> Wallaby.end_session(session) end)
        {:ok, session: session}
      end

  ## Shared mode (simple alternative for non-async E2E tests)

  If adding the plug is not practical, shared mode routes all unregistered
  deliveries to a single owner.  Note that shared mode requires `async: false`
  since there is only one global shared owner at a time.

      setup do
        :ok = Swoosh.Adapters.Sandbox.set_shared(self())
        on_exit(fn -> Swoosh.Adapters.Sandbox.set_shared(nil) end)
      end

  ## Allowing other processes

  If email is sent from a process not in the `$callers` chain of the test
  (e.g. a background worker), allow it explicitly:

      Swoosh.Adapters.Sandbox.allow(self(), worker_pid)

  ## Configuration options

  - `:on_unregistered`
    what to do when email is delivered from a process with no registered owner.
    Defaults to `:raise`.  Set to `:ignore` to silently succeed.

        config :my_app, MyApp.Mailer,
          adapter: Swoosh.Adapters.Sandbox,
          on_unregistered: :ignore
  """

  use Swoosh.Adapter

  alias Swoosh.Adapters.Sandbox.Storage

  # Adapter callbacks

  @impl true
  def deliver(email, config) do
    callers = [self() | List.wrap(Process.get(:"$callers"))]

    case Storage.find_owner(callers) do
      {:ok, owner} ->
        Storage.push(owner, email)
        {:ok, %{}}

      :no_owner ->
        case Storage.get_shared() do
          nil ->
            handle_unregistered(config, email)

          shared ->
            Storage.push(shared, email)
            {:ok, %{}}
        end
    end
  end

  # Sandbox API

  defdelegate checkout(), to: Storage
  defdelegate checkin(), to: Storage
  defdelegate allow(owner_pid, allowed_pid), to: Storage
  defdelegate set_shared(pid), to: Storage

  # defdelegate does not support default arguments
  def all(owner_pid \\ self()), do: Storage.all(owner_pid)
  def flush(owner_pid \\ self()), do: Storage.flush(owner_pid)

  def encode_owner(pid \\ self()) do
    encoded = pid |> :erlang.term_to_binary() |> Base.url_encode64()
    "SwooshSandbox (#{encoded})"
  end

  # Private

  defp handle_unregistered(config, email) do
    case Keyword.get(config, :on_unregistered, :raise) do
      :raise ->
        raise """
        Swoosh.Adapters.Sandbox: email delivered from an unregistered process.

        Call Swoosh.Adapters.Sandbox.checkout() in your test setup, or
        Swoosh.Adapters.Sandbox.allow(owner, pid) to explicitly permit a process, or
        Swoosh.Adapters.Sandbox.set_shared(self()) for E2E tests.

        Email: #{inspect(email)}
        """

      :ignore ->
        {:ok, %{}}
    end
  end
end
