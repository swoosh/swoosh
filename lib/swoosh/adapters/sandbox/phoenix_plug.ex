if Code.ensure_loaded?(Plug) do
  defmodule Swoosh.Adapters.Sandbox.PhoenixPlug do
    @moduledoc """
    A Plug that allows Phoenix request processes into a
    `Swoosh.Adapters.Sandbox` owner's sandbox, enabling `async: true`
    browser/E2E tests.

    The plug looks for a `SwooshSandbox (...)` token in the `user-agent`
    header.  If found, it decodes the owning test PID and calls
    `Swoosh.Adapters.Sandbox.allow/2` so that emails delivered during the
    request are routed to the test's private inbox.

    ## Usage

    Add the plug to your endpoint, guarded by a compile-time config flag
    so it is only loaded in the test environment:

        # lib/my_app_web/endpoint.ex
        if Application.compile_env(:my_app, :swoosh_sandbox, false) do
          plug Swoosh.Adapters.Sandbox.PhoenixPlug
        end

    Then enable it in `config/test.exs`:

        config :my_app, :swoosh_sandbox, true

    In your test setup, pass the encoded owner as the browser user-agent:

        setup do
          :ok = Swoosh.Adapters.Sandbox.checkout()
          token = Swoosh.Adapters.Sandbox.encode_owner()
          on_exit(&Swoosh.Adapters.Sandbox.checkin/0)
          {:ok, swoosh_token: token}
        end
    """

    @behaviour Plug

    @impl true
    def init(opts), do: opts

    @impl true
    def call(conn, _opts) do
      conn
      |> Plug.Conn.get_req_header("user-agent")
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
end
