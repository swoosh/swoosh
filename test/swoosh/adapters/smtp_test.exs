defmodule Swoosh.Adapters.SMTPTest do
  use AdapterCase, async: true

  alias Swoosh.Adapters.SMTP

  setup_all do
    valid_config = [relay: "localhost"]

    {:ok, valid_config: valid_config}
  end

  test "validate_config/1 with valid config", %{valid_config: config} do
    assert SMTP.validate_config(config) == :ok
  end

  test "validate_config/1 with invalid config" do
    assert_raise ArgumentError, """
    expected [:relay] to be set, got: []
    """, fn ->
      SMTP.validate_config([])
    end
  end
end
