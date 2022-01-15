defmodule Swoosh.AttachmentTest do
  use ExUnit.Case

  alias Swoosh.Attachment

  test "create an attachment" do
    attachment = Attachment.new("/data/file")
    assert attachment.content_type == "application/octet-stream"
    assert attachment.filename == "file"
    assert attachment.path == "/data/file"
  end

  test "create an attachment with data" do
    attachment = Attachment.new({:data, "data"})
    assert attachment.data == "data"
  end

  test "create an attachment with an unknown content type" do
    attachment = Attachment.new("/data/unknown-file")
    assert attachment.content_type == "application/octet-stream"
  end

  test "create an attachment with a specified file name" do
    attachment = Attachment.new("/data/file", filename: "my-test-name.doc")
    assert attachment.filename == "my-test-name.doc"
  end

  test "create an attachment with a specified content type" do
    attachment = Attachment.new("/data/file", content_type: "application/msword")
    assert attachment.content_type == "application/msword"
  end

  test "create an attachment from a Plug Upload struct" do
    path = "/data/uuid-random"
    upload = %Plug.Upload{filename: "imaginary.zip", content_type: "application/zip", path: path}
    attachment = Attachment.new(upload)
    assert attachment.content_type == "application/zip"
    assert attachment.filename == "imaginary.zip"
    assert attachment.path == path
  end

  test "create an attachment from a Plug Upload struct with overrides" do
    path = "/data/uuid-random"
    upload = %Plug.Upload{filename: "imaginary.zip", content_type: "application/zip", path: path}
    attachment = Attachment.new(upload, filename: "real.zip", content_type: "application/other")
    assert attachment.content_type == "application/other"
    assert attachment.filename == "real.zip"
    assert attachment.path == path
  end

  test "create an attachment that should be sent as an inline-attachment" do
    attachment = Attachment.new("/data/file.png", type: :inline)
    assert attachment.type == :inline
    assert attachment.cid == "file.png"
  end

  test "create an inline attachment with a custom CID" do
    attachment = Attachment.new("/data/file.png", type: :inline, cid: "my-cid")
    assert attachment.type == :inline
    assert attachment.cid == "my-cid"
  end

  test "does not set cid for regular (non-inline) attachments" do
    attachment = Attachment.new("/data/file.png")
    assert is_nil(attachment.cid)
  end

  test "create an attachment with custom headers" do
    attachment =
      Attachment.new("/data/file.png",
        headers: [{"Content-Type", "text/calendar; method=\"REQUEST\""}]
      )

    assert length(attachment.headers) == 1
    {a, b} = Enum.at(attachment.headers, 0)
    assert a == "Content-Type"
    assert b == "text/calendar; method=\"REQUEST\""
  end

  test "get_content returns data when exist" do
    assert "assemble" ==
             Attachment.get_content(%Attachment{
               data: "assemble",
               path: "test/support/attachment.txt"
             })
  end

  test "get_content returns data from path if necessary" do
    assert "assemble" == Attachment.get_content(%Attachment{path: "test/support/attachment.txt"})
  end

  test "get_content returns base64 when given the option" do
    assert Base.encode64("assemble") ==
             Attachment.get_content(%Attachment{data: "assemble"}, :base64)
  end

  test "get_content raises when no data or path is found" do
    assert_raise Swoosh.AttachmentContentError, fn ->
      Attachment.get_content(%Attachment{})
    end
  end
end
