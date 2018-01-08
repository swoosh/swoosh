defmodule Swoosh do
  @moduledoc File.read!("README.md") |> String.replace("# Swoosh\n\n", "", global: false)

  @version "0.12.1"

  @doc false
  def version, do: @version
end
