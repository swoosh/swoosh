defmodule Swoosh.HTTPAdapter do
  @moduledoc ~S"""
  Specification of the HTTP-based email delivery adatper.
  """

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
    end
  end
end
