defmodule Swoosh.Adapters.SendmailTest do
  use Swoosh.AdapterCase, async: true

  import ExUnit.CaptureLog
  import Swoosh.Email
  alias Swoosh.Adapters.Sendmail

  setup_all do
    valid_email =
      new()
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")

    valid_config = [
      adapter: Swoosh.Adapters.Sendmail,
      cmd_path: "/usr/bin/sendmail",
      cmd_args: ["-N", "delay,failure,success"]
    ]

    {:ok, valid_email: valid_email, valid_config: valid_config}
  end

  test "cmd_path", %{valid_config: config} do
    assert Sendmail.cmd_path(config) == config[:cmd_path]
    config = Keyword.delete(config, :cmd_path)
    assert Sendmail.cmd_path(config) == "/usr/sbin/sendmail"
    config = config ++ [qmail: true]
    assert Sendmail.cmd_path(config) == "/var/qmail/bin/qmail-inject"
  end

  test "cmd_args", %{valid_email: email, valid_config: config} do
    assert Sendmail.cmd_args(email, config) ==
             ["-f", "tony.stark@example.com", "-oi", "-t"] ++ config[:cmd_args]

    config = config ++ [qmail: true]

    assert Sendmail.cmd_args(email, config) ==
             ["-f", "tony.stark@example.com"] ++ config[:cmd_args]

    config = Keyword.delete(config, :cmd_args)
    assert Sendmail.cmd_args(email, config) == ["-f", "tony.stark@example.com"]
    config = Keyword.delete(config, :qmail)
    assert Sendmail.cmd_args(email, config) == ["-f", "tony.stark@example.com", "-oi", "-t"]
  end

  @tag :tmp_dir
  test "deliver/2 executes the binary directly with the args and body on stdin", %{
    valid_email: email,
    tmp_dir: dir
  } do
    out = Path.join(dir, "out")
    script = Path.join(dir, "fake-sendmail")

    File.write!(script, """
    #!/bin/sh
    for a in "$@"; do printf 'ARG:%s\\n' "$a"; done > '#{out}.tmp'
    cat >> '#{out}.tmp'
    mv '#{out}.tmp' '#{out}'
    """)

    File.chmod!(script, 0o755)

    config = [cmd_path: script, cmd_args: ["-N", "a b; touch #{dir}/pwned"]]
    assert {:ok, %{}} = Sendmail.deliver(email, config)

    assert wait_for_file(out) =~
             "ARG:-f\nARG:tony.stark@example.com\nARG:-oi\nARG:-t\nARG:-N\nARG:a b; touch #{dir}/pwned\n"

    assert File.read!(out) =~ "Subject: Hello, Avengers!"
    refute File.exists?(Path.join(dir, "pwned"))
  end

  test "deliver/2 raises when cmd_path is not an executable", %{valid_email: email} do
    assert_raise ErlangError, fn ->
      Sendmail.deliver(email, cmd_path: "/nonexistent/sendmail")
    end
  end

  test "executable resolves a relative cmd_path through PATH with a deprecation warning" do
    {result, log} = with_log(fn -> Sendmail.executable(cmd_path: "true") end)

    assert result == System.find_executable("true")
    assert log =~ "Deprecated relative sendmail cmd_path"
  end

  test "executable leaves an absolute cmd_path alone without warning" do
    {result, log} = with_log(fn -> Sendmail.executable(cmd_path: "/usr/bin/sendmail") end)

    assert result == "/usr/bin/sendmail"
    assert log == ""
  end

  test "deliver/2 raises for a relative cmd_path that is not in PATH", %{valid_email: email} do
    assert_raise ErlangError, fn ->
      Sendmail.deliver(email, cmd_path: "no-such-sendmail-binary")
    end
  end

  defp wait_for_file(path, tries \\ 100) do
    case File.read(path) do
      {:ok, content} ->
        content

      {:error, _} when tries > 0 ->
        Process.sleep(20)
        wait_for_file(path, tries - 1)

      {:error, reason} ->
        flunk("#{path} never appeared: #{inspect(reason)}")
    end
  end

  test "string cmd_args", %{valid_email: email} do
    {result, log} =
      with_log(fn ->
        Sendmail.cmd_args(email, %{cmd_args: ~s(abc "d e" 'f g')})
      end)

    assert result == ["-f", "tony.stark@example.com", "-oi", "-t", "abc", "d e", "f g"]
    assert log =~ "Deprecated"
  end
end
