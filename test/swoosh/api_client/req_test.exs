defmodule Swoosh.ApiClient.ReqTest do
  # async: false because we change application env
  use ExUnit.Case, async: false

  import Swoosh.Email
  alias Swoosh.Adapters.Sendgrid

  setup do
    old_api_client = Application.fetch_env!(:swoosh, :api_client)
    Application.put_env(:swoosh, :api_client, Swoosh.ApiClient.Req)

    on_exit(fn ->
      Application.put_env(:swoosh, :api_client, old_api_client)
    end)

    :ok
  end

  test "it works" do
    config = [
      base_url: "http://mailgun",
      api_key: "fake",
      domain: "avengers.com"
    ]

    plug = fn conn ->
      conn
      |> Plug.Conn.put_resp_header("x-message-id", "123-xyz")
      |> Req.Test.json(%{message: "success"})
    end

    email =
      new()
      |> put_private(:client_options, plug: plug)
      |> from("tony.stark@example.com")
      |> to("steve.rogers@example.com")
      |> subject("Hello, Avengers!")
      |> html_body("<h1>Hello</h1>")
      |> text_body("Hello")

    assert Sendgrid.deliver(email, config) ==
             {:ok, %{id: "123-xyz"}}
  end
end
