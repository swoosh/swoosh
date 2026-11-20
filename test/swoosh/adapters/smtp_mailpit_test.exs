defmodule Swoosh.Adapters.SMTPMailpitTest do
  # Not async: assertions read the shared Mailpit inbox via "latest".
  use ExUnit.Case, async: false

  @moduletag :mailpit

  import Swoosh.Email

  defp mailpit_deliver(email, config \\ []) do
    config = Keyword.merge([relay: "localhost", port: 1025, tls: :never, auth: :never], config)
    Swoosh.Adapters.SMTP.deliver(email, config)
  end

  setup do
    email =
      new(
        from: {"SMTP", "swoosh+smtp@github.com"},
        to: {"Recipient", "recipient@mailpit.local"},
        subject: "how are you? 😋",
        text_body: "I'm fine 😌",
        html_body: "I'm <i>fine</i> 😌"
      )

    {:ok, email: email}
  end

  test "base email", %{email: email} do
    assert {:ok, _receipt} = mailpit_deliver(email)

    assert %{
             "From" => %{"Address" => "swoosh+smtp@github.com", "Name" => "SMTP"},
             "To" => [%{"Address" => "recipient@mailpit.local", "Name" => "Recipient"}],
             "Subject" => "how are you? 😋",
             "Text" => text,
             "HTML" => html
           } = mailpit_get("message/latest")

    assert String.trim(text) == "I'm fine 😌"
    assert String.trim(html) == "I'm <i>fine</i> 😌"
  end

  test "with cc and bcc", %{email: email} do
    assert {:ok, _receipt} =
             email
             |> cc([{"CC1", "cc1@mailpit.local"}, "cc2@mailpit.local"])
             |> bcc("bcc1@mailpit.local")
             |> mailpit_deliver()

    assert %{
             "Cc" => [
               %{"Address" => "cc1@mailpit.local", "Name" => "CC1"},
               %{"Address" => "cc2@mailpit.local", "Name" => ""}
             ],
             "Bcc" => [%{"Address" => "bcc1@mailpit.local", "Name" => ""}]
           } = mailpit_get("message/latest")
  end

  @tag :tmp_dir
  test "with attachment", %{email: email, tmp_dir: tmp_dir} do
    path = Path.join(tmp_dir, "attachment.txt")
    File.write!(path, "hello :)\n")

    assert {:ok, _receipt} = email |> attachment(path) |> mailpit_deliver()

    # The adapter sends no Content-Type for attachments, so Mailpit does not
    # list them under "Attachments"; assert on the raw message instead.
    raw = mailpit_get("message/latest/raw")
    assert raw =~ "filename=attachment.txt"
    assert raw =~ Base.encode64("hello :)\n")
  end

  test "malformed address returns an error and sends nothing", %{email: email} do
    before_count = mailpit_get("messages")["total"]

    for bad <- ["[foo]@bar.com", ~s("foo@bar.com)] do
      assert {:error, _reason} = email |> to(bad) |> mailpit_deliver()
    end

    assert mailpit_get("messages")["total"] == before_count
  end

  defp mailpit_get(path) do
    Req.get!("http://localhost:8025/api/v1/#{path}", retry: false).body
  end
end
