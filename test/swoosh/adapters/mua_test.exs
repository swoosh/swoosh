defmodule Swoosh.Adapters.MuaTest do
  use ExUnit.Case, async: true

  @moduletag :mailpit

  defp mailpit_deliver(email, config \\ []) do
    config = Keyword.merge([relay: "localhost", port: 1025], config)
    Swoosh.Adapters.Mua.deliver(email, config)
  end

  describe "deliver/2" do
    setup do
      base_email =
        Swoosh.Email.new(
          from: {"Mua", "swoosh+mua@github.com"},
          to: {"Recipient", "recipient@mailpit.local"},
          subject: "how are you? 😋",
          text_body: "I'm fine 😌",
          html_body: "I'm <i>fine</i> 😌"
        )

      {:ok, email: base_email}
    end

    test "base email", %{email: email} do
      assert {:ok, _email} = mailpit_deliver(email)

      assert %{
               "From" => %{"Address" => "swoosh+mua@github.com", "Name" => "Mua"},
               "To" => [%{"Address" => "recipient@mailpit.local", "Name" => "Recipient"}],
               "Subject" => "how are you? 😋",
               "Text" => "I'm fine 😌\r\n",
               "HTML" => "I'm <i>fine</i> 😌"
             } = mailpit_summary("latest")

      assert %{
               "Date" => [_has_date],
               "Message-Id" => [_has_message_id]
             } = mailpit_headers("latest")
    end

    test "with address sender/recipient", %{email: email} do
      assert {:ok, _email} =
               email
               |> Swoosh.Email.from("mua@github.com")
               |> Swoosh.Email.to("to@mailpit.local")
               |> Swoosh.Email.cc(["cc1@mailpit.local", "cc2@mailpit.local"])
               |> Swoosh.Email.bcc(["bcc1@mailpit.local", "bcc2@mailpit.local"])
               |> mailpit_deliver()

      assert %{
               "From" => %{"Address" => "mua@github.com", "Name" => ""},
               "To" => [
                 %{"Address" => "to@mailpit.local", "Name" => ""},
                 %{"Address" => "recipient@mailpit.local", "Name" => "Recipient"}
               ],
               "Bcc" => [
                 %{"Address" => "bcc1@mailpit.local", "Name" => ""},
                 %{"Address" => "bcc2@mailpit.local", "Name" => ""}
               ],
               "Cc" => [
                 %{"Address" => "cc1@mailpit.local", "Name" => ""},
                 %{"Address" => "cc2@mailpit.local", "Name" => ""}
               ]
             } = mailpit_summary("latest")
    end

    test "with tuple recipient (empty name)", %{email: email} do
      assert {:ok, _email} =
               email
               |> Swoosh.Email.from({nil, "mua@github.com"})
               |> Swoosh.Email.to({nil, "to@mailpit.local"})
               |> Swoosh.Email.cc([{nil, "cc1@mailpit.local"}, {nil, "cc2@mailpit.local"}])
               |> Swoosh.Email.bcc([{nil, "bcc1@mailpit.local"}, {nil, "bcc2@mailpit.local"}])
               |> mailpit_deliver()

      assert %{
               "From" => %{"Address" => "mua@github.com", "Name" => ""},
               "To" => [
                 %{"Address" => "to@mailpit.local", "Name" => ""},
                 %{"Address" => "recipient@mailpit.local", "Name" => "Recipient"}
               ],
               "Bcc" => [
                 %{"Address" => "bcc1@mailpit.local", "Name" => ""},
                 %{"Address" => "bcc2@mailpit.local", "Name" => ""}
               ],
               "Cc" => [
                 %{"Address" => "cc1@mailpit.local", "Name" => ""},
                 %{"Address" => "cc2@mailpit.local", "Name" => ""}
               ]
             } = mailpit_summary("latest")
    end

    test "with cc and bcc", %{email: email} do
      assert {:ok, _email} =
               email
               |> Swoosh.Email.cc([
                 {"CC1", "cc1@mailpit.local"},
                 {"CC2", "cc2@mailpit.local"}
               ])
               |> Swoosh.Email.bcc([
                 {"BCC1", "bcc1@mailpit.local"},
                 {"BCC2", "bcc2@mailpit.local"}
               ])
               |> mailpit_deliver()

      assert %{
               "Cc" => [
                 %{"Address" => "cc1@mailpit.local", "Name" => "CC1"},
                 %{"Address" => "cc2@mailpit.local", "Name" => "CC2"}
               ],
               "Bcc" => [
                 %{"Address" => "bcc1@mailpit.local", "Name" => ""},
                 %{"Address" => "bcc2@mailpit.local", "Name" => ""}
               ]
             } = mailpit_summary("latest")
    end

    @tag :tmp_dir
    test "with attachments", %{email: email, tmp_dir: tmp_dir} do
      attachment = Path.join(tmp_dir, "attachment.txt")
      File.write!(attachment, "hello :)\n")

      assert {:ok, _email} =
               email
               |> Swoosh.Email.attachment(attachment)
               |> mailpit_deliver()

      assert %{
               "ID" => message_id,
               "Attachments" => [
                 %{
                   "ContentType" => "text/plain",
                   "FileName" => "attachment.txt",
                   "PartID" => part_id,
                   "Size" => 9
                 }
               ]
             } = mailpit_summary("latest")

      assert mailpit_attachment(message_id, part_id) == "hello :)\n"
    end
  end

  defp mailpit_summary(message_id) do
    mailpit_get("http://localhost:8025/api/v1/message/#{message_id}")
  end

  defp mailpit_headers(message_id) do
    mailpit_get("http://localhost:8025/api/v1/message/#{message_id}/headers")
  end

  defp mailpit_attachment(message_id, part_id) do
    mailpit_get("http://localhost:8025/api/v1/message/#{message_id}/part/#{part_id}")
  end

  defp mailpit_get(url) do
    Req.get!(url, retry: false).body
  end
end
