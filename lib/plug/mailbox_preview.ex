if Code.ensure_loaded?(Plug) do
  defmodule Plug.Swoosh.MailboxPreview do
    @moduledoc """
    Plug that serves pages useful for previewing emails in development.

    It takes one option at initialization:

      * `base_path` - sets the base URL path where this module is plugged. Defaults
        to `/`.

    ## Examples

        # in a Phoenix router
        defmodule Sample.Router do
          scope "/dev" do
            pipe_through [:browser]
            forward "/mailbox", Plug.Swoosh.MailboxPreview, [base_path: "/dev/mailbox"]
          end
        end
    """

    use Plug.Router
    use Plug.ErrorHandler

    alias Swoosh.Email.Render
    alias Swoosh.Adapters.Local.Storage.Memory

    require EEx
    EEx.function_from_file :defp, :template, "lib/plug/templates/mailbox_viewer/index.html.eex", [:assigns]

    def call(conn, opts) do
      conn =
        conn
        |> assign(:base_path, opts[:base_path] || "")
        |> assign(:storage_driver, opts[:storage_driver] || Memory)
      super(conn, opts)
    end

    plug :match
    plug :dispatch

    post "/clear" do
      conn.assigns.storage_driver.delete_all()

      conn
      |> put_resp_header("location", "/")
      |> send_resp(302, '')
    end

    get "/" do
      emails = conn.assigns.storage_driver.all()
      conn
      |> put_resp_content_type("text/html")
      |> send_resp(200, template(emails: emails, email: nil, conn: conn))
    end

    get "/:id/html" do
      email = conn.assigns.storage_driver.get(id)
      conn
      |> put_resp_content_type("text/html")
      |> send_resp(200, email.html_body)
    end

    get "/:id/attachments/:index" do
      index = String.to_integer(index)
      id
      |> conn.assigns.storage_driver.get()
      |> case do
        %{attachments: attachments} when length(attachments) > index ->
          attachments
          |> Enum.at(index)
          |> case do
            %{data: data, content_type: content_type} when not is_nil(data) ->
              conn
              |> put_resp_content_type(content_type)
              |> send_resp(200, data)
            %{path: path, content_type: content_type} when not is_nil(path) ->
              conn
              |> put_resp_content_type(content_type)
              |> send_resp(200, File.read!(path))
            _ ->
              conn
              |> put_resp_content_type("text/html")
              |> send_resp(500, "Attachment cannot be displayed")
          end
        _ ->
          conn
          |> put_resp_content_type("text/html")
          |> send_resp(404, "Attachment Not Found")
      end
    end

    get "/:id" do
      emails = conn.assigns.storage_driver.all()
      email = conn.assigns.storage_driver.get(id)
      conn
      |> put_resp_content_type("text/html")
      |> send_resp(200, template(emails: emails, email: email, conn: conn))
    end

    defp handle_errors(conn, %{kind: _kind, reason: _reason, stack: _stack}) do
      send_resp(conn, conn.status, "Something went wrong")
    end

    defp to_absolute_url(conn, path) do
      URI.parse("#{conn.assigns.base_path}/#{path}").path
    end

    defp render_recipient(recipient) do
      case Render.render_recipient(recipient) do
        "" -> "n/a"
        recipient -> Plug.HTML.html_escape(recipient)
      end
    end
  end
end
