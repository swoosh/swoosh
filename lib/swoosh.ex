defmodule Swoosh do
  @moduledoc File.read!("README.md") |> String.replace("# Swoosh\n\n", "", global: false)

  @version "0.16.0"

  @doc false
  def version, do: @version

  @json_library Application.get_env(:swoosh, :json_library, Jason)

  @doc false
  def json_library, do: @json_library
end
