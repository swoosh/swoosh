defmodule Swoosh.Template.Engine do
  @moduledoc """
  Specifies the API for adding custom template engines to Swoosh.
  """

  @callback compile(template_path :: binary) :: Macro.t
end
