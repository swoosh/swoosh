defmodule Swoosh.Attachment do
  @moduledoc """
  Struct representing an attachment in an email.
  """

  defstruct filename: nil, content_type: nil, path: nil, type: nil

  @type t :: %__MODULE__{}

  @doc ~S"""
  Creates a new Attachment

  Examples:

      Attachment.new("/path/to/attachment.png")
      Attachment.new("/path/to/attachment.png", filename: "image.png")
      Attachment.new("/path/to/attachment.png", filename: "image.png", content_type: "image/png")
      Attachment.new(params["file"]) # Where params["file"] is a %Plug.Upload

  Examples with inline-attachments:

      Attachment.new("/path/to/attachment.png", type: :inline)
      Attachment.new("/path/to/attachment.png", filename: "image.png", type: :inline)
      Attachment.new("/path/to/attachment.png", filename: "image.png", content_type: "image/png", type: :inline)
      Attachment.new(params["file"], type: "inline") # Where params["file"] is a %Plug.Upload

  """
  @spec new(binary, Keyword.t) :: %__MODULE__{}
  def new(path, opts \\ [])

  if Code.ensure_loaded?(Plug) do
    def new(
      %Plug.Upload{
        filename: filename,
        content_type: content_type,
        path: path
      },
      opts
    ) do
      new(
        path,
        Keyword.merge(
          [filename: filename, content_type: content_type],
          opts
        )
      )
    end
  end

  def new(path, opts) do
    filename = opts[:filename] || Path.basename(path)
    content_type = opts[:content_type] || MIME.from_path(path)
    type = opts[:type] || :attachment
    %__MODULE__{path: path, filename: filename, content_type: content_type, type: type}
  end
end
