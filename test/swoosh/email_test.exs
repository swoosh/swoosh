defmodule Swoosh.EmailTest do
  use ExUnit.Case, async: true
  doctest Swoosh.Email, import: true

  alias Swoosh.{Email, Attachment}
  import Swoosh.Email

  test "new without arguments create an empty email" do
    assert %Email{} = new()
  end

  test "new with arguments create an email with fields populated" do
    email = new(subject: "Hello, Avengers!")
    assert email.subject == "Hello, Avengers!"
  end

  test "new with multiple attachments" do
    email = new(attachment: "/data/1", attachment: "/data/2")
    assert [%Attachment{}, %Attachment{}] = email.attachments
  end

  test "new raises if arguments contain unknown field" do
    assert_raise ArgumentError, """
    invalid field `:sbject` (value="Unknown") for Swoosh.Email.new/1.
    """, fn -> new(sbject: "Unknown") end
  end

  test "from/2" do
    email = new() |> from("tony.stark@example.com")
    assert email == %Email{from: {"", "tony.stark@example.com"}}

    email = email |> from({"Steve Rogers", "steve.rogers@example.com"})
    assert email == %Email{from: {"Steve Rogers", "steve.rogers@example.com"}}
  end

  test "subject/2" do
    email = new() |> subject("Hello, Avengers!")
    assert email == %Email{subject: "Hello, Avengers!"}

    email = email |> subject("Welcome, I am Jarvis")
    assert email == %Email{subject: "Welcome, I am Jarvis"}
  end

  test "html_body/2" do
    email = new() |> html_body("<h1>Hello, Avengers!</h1>")
    assert email == %Email{html_body: "<h1>Hello, Avengers!</h1>"}

    email = email |> html_body("<h1>Welcome, I am Jarvis</h1>")
    assert email == %Email{html_body: "<h1>Welcome, I am Jarvis</h1>"}
  end

  test "text_body/2" do
    email = new() |> text_body("Hello, Avengers!")
    assert email == %Email{text_body: "Hello, Avengers!"}

    email = email |> text_body("Welcome, I am Jarvis")
    assert email == %Email{text_body: "Welcome, I am Jarvis"}
  end

  test "reply_to/2" do
    email = new() |> reply_to("welcome.avengers@example.com")
    assert email == %Email{reply_to: {"", "welcome.avengers@example.com"}}

    email = email |> reply_to({"Jarvis Assist", "help.jarvis@example.com"})
    assert email == %Email{reply_to: {"Jarvis Assist", "help.jarvis@example.com"}}
  end

  test "to/2 add new recipient(s) to \"to\"" do
    email = new() |> to("tony.stark@example.com")
    assert email == %Email{to: [{"", "tony.stark@example.com"}]}

    email = email |> to({"Steve Rogers", "steve.rogers@example.com"})
    assert email == %Email{to: [{"Steve Rogers", "steve.rogers@example.com"}, {"", "tony.stark@example.com"}]}

    email = email |> to(["bruce.banner@example.com", {"Thor Odinson", "thor.odinson@example.com"}])
    assert email == %Email{to: [{"", "bruce.banner@example.com"}, {"Thor Odinson", "thor.odinson@example.com"},
                                {"Steve Rogers", "steve.rogers@example.com"}, {"", "tony.stark@example.com"}]}
  end

  test "put_to/2 replace new recipient(s) in \"to\"" do
    email = new() |> to("foo.bar@example.com")

    email = email |> put_to("tony.stark@example.com")
    assert email == %Email{to: [{"", "tony.stark@example.com"}]}

    email = email |> put_to({"Steve Rogers","steve.rogers@example.com"})
    assert email == %Email{to: [{"Steve Rogers", "steve.rogers@example.com"}]}

    email = email |> put_to(["bruce.banner@example.com", {"Thor Odinson", "thor.odinson@example.com"}])
    assert email == %Email{to: [{"", "bruce.banner@example.com"}, {"Thor Odinson", "thor.odinson@example.com"}]}
  end

  test "cc/2 add new recipient(s) to \"cc\"" do
    email = new() |> cc("ccny.stark@example.com")
    assert email == %Email{cc: [{"", "ccny.stark@example.com"}]}

    email = email |> cc({"Steve Rogers", "steve.rogers@example.com"})
    assert email == %Email{cc: [{"Steve Rogers", "steve.rogers@example.com"}, {"", "ccny.stark@example.com"}]}

    email = email |> cc(["bruce.banner@example.com", {"Thor Odinson", "thor.odinson@example.com"}])
    assert email == %Email{cc: [{"", "bruce.banner@example.com"}, {"Thor Odinson", "thor.odinson@example.com"},
                               {"Steve Rogers", "steve.rogers@example.com"}, {"", "ccny.stark@example.com"}]}
  end

  test "put_cc/2 replace new recipient(s) in \"cc\"" do
    email = new() |> cc("foo.bar@example.com")

    email = email |> put_cc("ccny.stark@example.com")
    assert email == %Email{cc: [{"", "ccny.stark@example.com"}]}

    email = email |> put_cc({"Steve Rogers","steve.rogers@example.com"})
    assert email == %Email{cc: [{"Steve Rogers", "steve.rogers@example.com"}]}

    email = email |> put_cc(["bruce.banner@example.com", {"Thor Odinson", "thor.odinson@example.com"}])
    assert email == %Email{cc: [{"", "bruce.banner@example.com"}, {"Thor Odinson", "thor.odinson@example.com"}]}
  end

  test "bcc/2 add new recipient(s) to \"bcc\"" do
    email = new() |> bcc("bccny.stark@example.com")
    assert email == %Email{bcc: [{"", "bccny.stark@example.com"}]}

    email = email |> bcc({"Steve Rogers", "steve.rogers@example.com"})
    assert email == %Email{bcc: [{"Steve Rogers", "steve.rogers@example.com"}, {"", "bccny.stark@example.com"}]}

    email = email |> bcc(["bruce.banner@example.com", {"Thor Odinson", "thor.odinson@example.com"}])
    assert email == %Email{bcc: [{"", "bruce.banner@example.com"}, {"Thor Odinson", "thor.odinson@example.com"},
                               {"Steve Rogers", "steve.rogers@example.com"}, {"", "bccny.stark@example.com"}]}
  end

  test "put_bcc/2 replace new recipient(s) in \"bcc\"" do
    email = new() |> bcc("foo.bar@example.com")

    email = email |> put_bcc("bccny.stark@example.com")
    assert email == %Email{bcc: [{"", "bccny.stark@example.com"}]}

    email = email |> put_bcc({"Steve Rogers","steve.rogers@example.com"})
    assert email == %Email{bcc: [{"Steve Rogers", "steve.rogers@example.com"}]}

    email = email |> put_bcc(["bruce.banner@example.com", {"Thor Odinson", "thor.odinson@example.com"}])
    assert email == %Email{bcc: [{"", "bruce.banner@example.com"}, {"Thor Odinson", "thor.odinson@example.com"}]}
  end

  test "header/3" do
    email = new() |> header("X-Accept-Language", "en")
    assert email == %Email{headers: %{"X-Accept-Language" => "en"}}

    email = email |> header("X-Mailer", "swoosh")
    assert email == %Email{headers: %{"X-Accept-Language" => "en",
                                      "X-Mailer" => "swoosh"}}
  end

  test "header/3 should raise if invalid name or value is passed" do
    assert_raise ArgumentError, """
    header/3 expects the header name and value to be strings.

    Instead it got:
      name: `"X-Accept-Language"`.
      value: `nil`.
    """, fn ->
      new() |> header("X-Accept-Language", nil)
    end

    assert_raise ArgumentError, """
    header/3 expects the header name and value to be strings.

    Instead it got:
      name: `nil`.
      value: `"swoosh"`.
    """, fn ->
      new() |> header(nil, "swoosh")
    end
  end

  test "put_private/3" do
    email = new() |> put_private(:phoenix_layout, false)
    assert email == %Email{private: %{phoenix_layout: false}}
  end
end
