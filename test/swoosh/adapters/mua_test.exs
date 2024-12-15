defmodule Swoosh.Adapters.MuaTest do
  use ExUnit.Case, async: true

  @moduletag :mailpit

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
      {:ok, _email} = mailpit_deliver(email)

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
  end

  defp mailpit_deliver(email) do
    config = [relay: "localhost", port: 1025]
    Swoosh.Adapters.Mua.deliver(email, config)
  end

  defp mailpit_summary(message_id) do
    mailpit_api_request("http://localhost:8025/api/v1/message/#{message_id}")
  end

  defp mailpit_headers(message_id) do
    mailpit_api_request("http://localhost:8025/api/v1/message/#{message_id}/headers")
  end

  defp mailpit_api_request(url) do
    Req.get!(url, retry: false).body
  end
end
