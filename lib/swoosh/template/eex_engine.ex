defmodule Swoosh.Template.EExEngine do
  @moduledoc """
  Template engine implementation for EEx.
  """

  @behaviour Swoosh.Template.Engine

  def compile(template_path) do
    EEx.compile_file(template_path, trim: true)
  end
end
