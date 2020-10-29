defmodule Swoosh do
  @moduledoc File.read!("README.md") |> String.replace("# Swoosh\n\n", "", global: false)

  @version "1.0.8"

  @doc false
  def version, do: @version

  @doc false
  def json_library, do: Application.fetch_env!(:swoosh, :json_library)
end
