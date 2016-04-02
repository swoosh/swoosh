defmodule Swoosh.EmailTest do
  use ExUnit.Case, async: true
  doctest Swoosh.Email, import: true

  alias Swoosh.Email
  import Swoosh.Email

  test "new without arguments create an empty email" do
    assert %Email{} = new
  end

  test "new with arguments create an email with fiels populated" do
    email = new(subject: "Hello, Avengers!")
    assert email.subject == "Hello, Avengers!"
  end

  test "new raises if arguments contain unknown field" do
    assert_raise ArgumentError, """
    invalid field `:sbject` (value="Unknown") for Swoosh.Email.new/1.
    """, fn -> new(sbject: "Unknown") end
  end

  test "from/2" do
    email = new |> from("tony@stark.com")
    assert email == %Email{from: {"", "tony@stark.com"}}

    email = email |> from({"Steve Rogers", "steve@rogers.com"})
    assert email == %Email{from: {"Steve Rogers", "steve@rogers.com"}}
  end

  test "from/2 should raise if from value is invalid" do
    assert_raise ArgumentError, fn -> new |> from(nil) end
    assert_raise ArgumentError, fn -> new |> from("") end
    assert_raise ArgumentError, fn -> new |> from({nil, "tony@stark.com"}) end
    assert_raise ArgumentError, fn -> new |> from({nil, ""}) end
  end

  test "subject/2" do
    email = new |> subject("Hello, Avengers!")
    assert email == %Email{subject: "Hello, Avengers!"}

    email = email |> subject("Welcome, I am Jarvis")
    assert email == %Email{subject: "Welcome, I am Jarvis"}
  end

  test "html_body/2" do
    email = new |> html_body("<h1>Hello, Avengers!</h1>")
    assert email == %Email{html_body: "<h1>Hello, Avengers!</h1>"}

    email = email |> html_body("<h1>Welcome, I am Jarvis</h1>")
    assert email == %Email{html_body: "<h1>Welcome, I am Jarvis</h1>"}
  end

  test "text_body/2" do
    email = new |> text_body("Hello, Avengers!")
    assert email == %Email{text_body: "Hello, Avengers!"}

    email = email |> text_body("Welcome, I am Jarvis")
    assert email == %Email{text_body: "Welcome, I am Jarvis"}
  end

  test "reply_to/2" do
    email = new |> reply_to("welcome@avengers.com")
    assert email == %Email{reply_to: {"", "welcome@avengers.com"}}

    email = email |> reply_to({"Jarvis Assist", "help@jarvis.com"})
    assert email == %Email{reply_to: {"Jarvis Assist", "help@jarvis.com"}}
  end

  test "to/2 add new recipient(s) to \"to\"" do
    email = new |> to("tony@stark.com")
    assert email == %Email{to: [{"", "tony@stark.com"}]}

    email = email |> to({"Steve Rogers", "steve@rogers.com"})
    assert email == %Email{to: [{"Steve Rogers", "steve@rogers.com"}, {"", "tony@stark.com"}]}

    email = email |> to(["bruce@banner.com", {"Thor Odinson", "thor@odinson.com"}])
    assert email == %Email{to: [{"", "bruce@banner.com"}, {"Thor Odinson", "thor@odinson.com"},
                                {"Steve Rogers", "steve@rogers.com"}, {"", "tony@stark.com"}]}
  end

  test "to/2 should raise if recipient(s) are invalid" do
    assert_raise ArgumentError, fn -> new |> to(nil) end
    assert_raise ArgumentError, fn -> new |> to("") end
    assert_raise ArgumentError, fn -> new |> to({nil, "tony@stark.com"}) end
    assert_raise ArgumentError, fn -> new |> to([nil, "thor@odinson.com"]) end
    assert_raise ArgumentError, fn ->
      new |> to([{"Bruce Banner", nil}, "thor@odinson.com"])
    end
  end

  test "put_to/2 replace new recipient(s) in \"to\"" do
    email = new |> to("foo@bar.com")

    email = email |> put_to("tony@stark.com")
    assert email == %Email{to: [{"", "tony@stark.com"}]}

    email = email |> put_to({"Steve Rogers","steve@rogers.com"})
    assert email == %Email{to: [{"Steve Rogers", "steve@rogers.com"}]}

    email = email |> put_to(["bruce@banner.com", {"Thor Odinson", "thor@odinson.com"}])
    assert email == %Email{to: [{"", "bruce@banner.com"}, {"Thor Odinson", "thor@odinson.com"}]}
  end

  test "put_to/2 should raise if recipient(s) are invalid" do
    assert_raise ArgumentError, fn -> new |> put_to(nil) end
    assert_raise ArgumentError, fn -> new |> put_to("") end
    assert_raise ArgumentError, fn -> new |> put_to({nil, "tony@stark.com"}) end
    assert_raise ArgumentError, fn -> new |> put_to([nil, "thor@odinson.com"]) end
    assert_raise ArgumentError, fn ->
      new |> put_to([{"Bruce Banner", nil}, "thor@odinson.com"])
    end
  end

  test "cc/2 add new recipient(s) to \"cc\"" do
    email = new |> cc("ccny@stark.com")
    assert email == %Email{cc: [{"", "ccny@stark.com"}]}

    email = email |> cc({"Steve Rogers", "steve@rogers.com"})
    assert email == %Email{cc: [{"Steve Rogers", "steve@rogers.com"}, {"", "ccny@stark.com"}]}

    email = email |> cc(["bruce@banner.com", {"Thor Odinson", "thor@odinson.com"}])
    assert email == %Email{cc: [{"", "bruce@banner.com"}, {"Thor Odinson", "thor@odinson.com"},
                               {"Steve Rogers", "steve@rogers.com"}, {"", "ccny@stark.com"}]}
  end

  test "cc/2 should raise if recipient(s) are invalid" do
    assert_raise ArgumentError, fn -> new |> cc(nil) end
    assert_raise ArgumentError, fn -> new |> cc("") end
    assert_raise ArgumentError, fn -> new |> cc({nil, "ccny@stark.com"}) end
    assert_raise ArgumentError, fn -> new |> cc([nil, "thor@odinson.com"]) end
    assert_raise ArgumentError, fn ->
      new |> cc([{"Bruce Banner", nil}, "thor@odinson.com"])
    end
  end

  test "put_cc/2 replace new recipient(s) in \"cc\"" do
    email = new |> cc("foo@bar.com")

    email = email |> put_cc("ccny@stark.com")
    assert email == %Email{cc: [{"", "ccny@stark.com"}]}

    email = email |> put_cc({"Steve Rogers","steve@rogers.com"})
    assert email == %Email{cc: [{"Steve Rogers", "steve@rogers.com"}]}

    email = email |> put_cc(["bruce@banner.com", {"Thor Odinson", "thor@odinson.com"}])
    assert email == %Email{cc: [{"", "bruce@banner.com"}, {"Thor Odinson", "thor@odinson.com"}]}
  end

  test "put_cc/2 should raise if recipient(s) are invalid" do
    assert_raise ArgumentError, fn -> new |> put_cc(nil) end
    assert_raise ArgumentError, fn -> new |> put_cc("") end
    assert_raise ArgumentError, fn -> new |> put_cc({nil, "ccny@stark.com"}) end
    assert_raise ArgumentError, fn -> new |> put_cc([nil, "thor@odinson.com"]) end
    assert_raise ArgumentError, fn ->
      new |> put_cc([{"Bruce Banner", nil}, "thor@odinson.com"])
    end
  end

  test "bcc/2 add new recipient(s) to \"bcc\"" do
    email = new |> bcc("bccny@stark.com")
    assert email == %Email{bcc: [{"", "bccny@stark.com"}]}

    email = email |> bcc({"Steve Rogers", "steve@rogers.com"})
    assert email == %Email{bcc: [{"Steve Rogers", "steve@rogers.com"}, {"", "bccny@stark.com"}]}

    email = email |> bcc(["bruce@banner.com", {"Thor Odinson", "thor@odinson.com"}])
    assert email == %Email{bcc: [{"", "bruce@banner.com"}, {"Thor Odinson", "thor@odinson.com"},
                               {"Steve Rogers", "steve@rogers.com"}, {"", "bccny@stark.com"}]}
  end

  test "bcc/2 should raise if recipient(s) are invalid" do
    assert_raise ArgumentError, fn -> new |> bcc(nil) end
    assert_raise ArgumentError, fn -> new |> bcc("") end
    assert_raise ArgumentError, fn -> new |> bcc({nil, "bccny@stark.com"}) end
    assert_raise ArgumentError, fn -> new |> bcc([nil, "thor@odinson.com"]) end
    assert_raise ArgumentError, fn ->
      new |> bcc([{"Bruce Banner", nil}, "thor@odinson.com"])
    end
  end

  test "put_bcc/2 replace new recipient(s) in \"bcc\"" do
    email = new |> bcc("foo@bar.com")

    email = email |> put_bcc("bccny@stark.com")
    assert email == %Email{bcc: [{"", "bccny@stark.com"}]}

    email = email |> put_bcc({"Steve Rogers","steve@rogers.com"})
    assert email == %Email{bcc: [{"Steve Rogers", "steve@rogers.com"}]}

    email = email |> put_bcc(["bruce@banner.com", {"Thor Odinson", "thor@odinson.com"}])
    assert email == %Email{bcc: [{"", "bruce@banner.com"}, {"Thor Odinson", "thor@odinson.com"}]}
  end

  test "put_bcc/2 should raise if recipient(s) are invalid" do
    assert_raise ArgumentError, fn -> new |> put_bcc(nil) end
    assert_raise ArgumentError, fn -> new |> put_bcc("") end
    assert_raise ArgumentError, fn -> new |> put_bcc({nil, "bccny@stark.com"}) end
    assert_raise ArgumentError, fn -> new |> put_bcc([nil, "thor@odinson.com"]) end
    assert_raise ArgumentError, fn ->
      new |> put_bcc([{"Bruce Banner", nil}, "thor@odinson.com"])
    end
  end

  test "header/3" do
    email = new |> header("X-Accept-Language", "en")
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
      new |> header("X-Accept-Language", nil)
    end

    assert_raise ArgumentError, """
    header/3 expects the header name and value to be strings.

    Instead it got:
      name: `nil`.
      value: `"swoosh"`.
    """, fn ->
      new |> header(nil, "swoosh")
    end
  end

  test "put_private/3" do
    email = new |> put_private(:phoenix_layout, false)
    assert email == %Email{private: %{phoenix_layout: false}}
  end

  test "format_recipient/1 error messages" do
    assert_raise ArgumentError,
      """
      The recipient `nil` is invalid.

      Recipients must be a string representing an email address like
      `foo@bar.com` or a two-element tuple `{name, address}`, where
      name and address are strings.
      """, fn ->
      new |> to(nil)
    end

    assert_raise ArgumentError,
      """
      The recipient `{nil, "tony@stark.com"}` is invalid.

      Recipients must be a string representing an email address like
      `foo@bar.com` or a two-element tuple `{name, address}`, where
      name and address are strings.
      """, fn ->
      new |> to({nil, "tony@stark.com"})
    end

    assert_raise ArgumentError,
      """
      The recipient `nil` is invalid.

      Recipients must be a string representing an email address like
      `foo@bar.com` or a two-element tuple `{name, address}`, where
      name and address are strings.
      """, fn ->
      new |> to([nil, "thor@odinson.com"])
    end

    assert_raise ArgumentError,
      """
      The recipient `{"Bruce Banner", nil}` is invalid.

      Recipients must be a string representing an email address like
      `foo@bar.com` or a two-element tuple `{name, address}`, where
      name and address are strings.
      """, fn ->
      new |> to([{"Bruce Banner", nil}, "thor@odinson.com"])
    end
  end
end
