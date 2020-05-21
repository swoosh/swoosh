defmodule Swoosh do
  @moduledoc File.read!("README.md") |> String.replace("# Swoosh\n\n", "", global: false)

  @version "0.25.4"

  @doc false
  def version, do: @version

  @doc false
  def json_library, do: Application.fetch_env!(:swoosh, :json_library)
end
