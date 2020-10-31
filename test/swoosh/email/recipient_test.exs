defmodule Swoosh.Email.RecipientTest do
  use ExUnit.Case, async: true

  alias Swoosh.Email.Recipient

  defmodule Avenger do
    @derive {Recipient, name: :name, address: :email}
    defstruct [:name, :email]
  end

  defmodule Villian do
    @derive {Recipient, address: :email}
    defstruct [:we_dont_care_about_their_names, :email]
  end

  defmodule Minion do
    defstruct [:banana, :wulala]
  end

  defimpl Recipient, for: Minion do
    def format(%Minion{banana: email, wulala: w}) do
      {"Minion #{w}", email}
    end
  end

  test "derive both name and address" do
    assert Recipient.format(%Avenger{name: "Thor", email: "thor@avengers.org"}) ==
             {"Thor", "thor@avengers.org"}
  end

  test "derive address only" do
    assert Recipient.format(%Villian{
             we_dont_care_about_their_names: "Random Villian",
             email: "random@villain.me"
           }) == {"", "random@villain.me"}
  end

  test "full impl" do
    assert Recipient.format(%Minion{banana: "baabababa@minions.org", wulala: "www"}) ==
             {"Minion www", "baabababa@minions.org"}
  end

  test "raise when field not exist in struct" do
    assert_raise ArgumentError, fn ->
      defmodule Failed do
        @derive {Recipient, address: :not_there}
        defstruct [:there]
      end
    end
  end

  test "format tuple" do
    assert Recipient.format({"Hulk", "hulk@avengers.org"}) == {"Hulk", "hulk@avengers.org"}
    assert Recipient.format({nil, "hulk@avengers.org"}) == {"", "hulk@avengers.org"}
  end

  test "raise when format malformed tuple" do
    assert_raise ArgumentError, fn -> Recipient.format({nil, ""}) end
    assert_raise ArgumentError, fn -> Recipient.format({"Thanos", ""}) end
    assert_raise ArgumentError, fn -> Recipient.format({"Thanos", nil}) end
  end

  test "format string" do
    assert Recipient.format("vision@avengers.org") == {"", "vision@avengers.org"}
  end

  test "raise when format empty string" do
    assert_raise ArgumentError, fn -> Recipient.format("") end
  end

  test "raise when format nil / unimplemented type" do
    assert_raise Protocol.UndefinedError,
                 ~r/Swoosh\.Email\.Recipient needs to be implemented/,
                 fn -> Recipient.format(nil) end
  end

  test "test with email" do
    import Swoosh.Email

    assert %Swoosh.Email{
             from: {"Admin", "admin@avengers.org"},
             to: [{"", "random@villain.me"}],
             cc: [{"Thor", "thor@avengers.org"}, {"", "ironman@avengers.org"}],
             bcc: [{"Minion Bob", "hahaha@minions.org"}, {"", "thanos@villain.me"}],
             subject: "Peace, love, not war"
           } =
             new()
             |> subject("Peace, love, not war")
             |> from(%Avenger{name: "Admin", email: "admin@avengers.org"})
             |> to(%Villian{email: "random@villain.me", we_dont_care_about_their_names: "Random"})
             |> cc("ironman@avengers.org")
             |> cc({"Thor", "thor@avengers.org"})
             |> bcc({nil, "thanos@villain.me"})
             |> bcc(%Minion{banana: "hahaha@minions.org", wulala: "Bob"})
  end
end
