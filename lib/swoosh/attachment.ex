defmodule Swoosh.Attachment do
  @moduledoc ~S"""
  Struct representing an attachment in an email.

  ## Usage

  For all usecases of `new/2` see the function documentation.

  ## Inline Example

      new()
      |> to({avenger.name, avenger.email})
      |> from({"Red Skull", "red_skull@villains.org"})
      |> subject("End Game invitation QR Code")
      |> html_body(~s|<h1>Hello #{avenger.name}</h1> Here is your QR Code <img src="cid:qrcode.png">|)
      |> text_body("Hello #{avenger.name}. Please find your QR Code attached.\n")
      |> attachment(
        Swoosh.Attachment.new(
          {:data, invitation_qr_code_binary},
          filename: "qrcode.png",
          content_type: "image/png",
          type: :inline)
      )
      |> VillainMailer.deliver()
  """

  defstruct filename: nil, content_type: nil, path: nil, data: nil, type: :attachment, headers: []

  @type t :: %__MODULE__{
          filename: String.t(),
          content_type: String.t(),
          path: String.t() | nil,
          data: binary | nil,
          type: :inline | :attachment,
          headers: [{String.t(), String.t()}]
        }

  @doc ~S"""
  Creates a new Attachment

  Examples:

      Attachment.new("/path/to/attachment.png")
      Attachment.new("/path/to/attachment.png", filename: "image.png")
      Attachment.new("/path/to/attachment.png", filename: "image.png", content_type: "image/png")
      Attachment.new(params["file"]) # Where params["file"] is a %Plug.Upload
      Attachment.new({:data, File.read!("/path/to/attachment.png")}, filename: "image.png", content_type: "image/png")

  Examples with inline-attachments:

      Attachment.new("/path/to/attachment.png", type: :inline)
      Attachment.new("/path/to/attachment.png", filename: "image.png", type: :inline)
      Attachment.new("/path/to/attachment.png", filename: "image.png", content_type: "image/png", type: :inline)
      Attachment.new(params["file"], type: :inline) # Where params["file"] is a %Plug.Upload
      Attachment.new({:data, File.read!("/path/to/attachment.png")}, filename: "image.png", content_type: "image/png", type: :inline)

  Inline attachments by default use their filename
  (or basename of the path if filename is not specified) as cid,
  in relevant adapters.

      Attachment.new("/data/file.png", type: :inline)

  Gives you something like this:

      <img src="cid:file.png">
  """
  @spec new(binary | struct | {:data, binary}, Keyword.t() | map) :: %__MODULE__{}
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

  def new({:data, data}, opts) do
    %{struct!(__MODULE__, opts) | data: data}
  end

  def new(path, opts) do
    attachment = struct!(__MODULE__, opts)

    %{
      attachment
      | path: path,
        filename: attachment.filename || Path.basename(path),
        content_type: attachment.content_type || MIME.from_path(path)
    }
  end

  @type content_encoding :: :raw | :base64
  @spec get_content(%__MODULE__{}, content_encoding) :: binary | no_return
  def get_content(%__MODULE__{data: nil, path: nil}) do
    raise Swoosh.AttachmentContentError, message: "No path or data is provided"
  end

  def get_content(%__MODULE__{data: data, path: path}, encoding \\ :raw) do
    encode(data || File.read!(path), encoding)
  end

  defp encode(content, :raw), do: content
  defp encode(content, :base64), do: Base.encode64(content)
end
