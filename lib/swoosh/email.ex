defmodule Swoosh.Email do
  @moduledoc """
  Defines an Email.

  This module defines a `Swoosh.Email` struct and the main functions for composing an email.  As it is the contract for
  the public APIs of Swoosh it is a good idea to make use of these functions rather than build the struct yourself.

  ## Email fields

  * `from` - the email address of the sender, example: `{"Tony Stark", "tony.stark@example.com"}`
  * `to` - the email address for the recipient(s), example: `[{"Steve Rogers", "steve.rogers@example.com"}]`
  * `subject` - the subject of the email, example: `"Hello, Avengers!"`
  * `cc` - the intended carbon copy recipient(s) of the email, example: `[{"Bruce Banner", "hulk.smash@example.com"}]`
  * `bcc` - the intended blind carbon copy recipient(s) of the email, example: `[{"Janet Pym", "wasp.avengers@example.com"}]`
  * `text_body` - the content of the email in plaintext, example: `"Hello"`
  * `html_body` - the content of the email in HTML, example: `"<h1>Hello</h1>"`
  * `reply_to` - the email address that should receive replies, example: `{"Clint Barton", "hawk.eye@example.com"}`
  * `headers` - a map of headers that should be included in the email, example: `%{"X-Accept-Language" => "en-us, en"}`
  * `attachments` - a list of attachments that should be included in the email, example: `[%{path: "/data/uuid-random", filename: "att.zip", content_type: "application/zip"}]`
  * `assigns` - a map of values that correspond with any template variables, example: `%{"first_name" => "Bruce"}`

  ## Private

  This key is reserved for use with adapters, libraries and frameworks.

  * `private` - a map of values that are for use by libraries/frameworks, example: `%{phoenix_template: "welcome.html.eex"}`
    - `client_options` will be passed to underlining http client post call

  ## Provider options

  This key allow users to make use of provider-specific functionality by passing along addition parameters.

  * `provider_options` - a map of values that are specific to adapter provider, example: `%{async: true}`

  ## Examples

      email =
        new()
        |> to("tony.stark@example.com")
        |> from("bruce.banner@example.com")
        |> text_body("Welcome to the Avengers")

  The composable nature makes it very easy to continue expanding upon a given Email.

      email =
        email
        |> cc({"Steve Rogers", "steve.rogers@example.com"})
        |> cc("wasp.avengers@example.com")
        |> bcc(["thor.odinson@example.com", {"Henry McCoy", "beast.avengers@example.com"}])
        |> html_body("<h1>Special Welcome</h1>")

  You can also directly pass arguments to the `new/1` function.

      email = new(from: "tony.stark@example.com", to: "steve.rogers@example.com", subject: "Hello, Avengers!")
  """

  alias Swoosh.Email.Recipient

  defstruct subject: "",
            from: nil,
            to: [],
            cc: [],
            bcc: [],
            text_body: nil,
            html_body: nil,
            attachments: [],
            reply_to: nil,
            headers: %{},
            private: %{},
            assigns: %{},
            provider_options: %{}

  @type name :: String.t()
  @type address :: String.t()
  @type mailbox :: {name, address}
  @type subject :: String.t()
  @type text_body :: String.t()
  @type html_body :: String.t()

  @type t :: %__MODULE__{
          subject: String.t(),
          from: mailbox | nil,
          to: [mailbox],
          cc: [mailbox] | [],
          bcc: [mailbox] | [],
          text_body: text_body | nil,
          html_body: html_body | nil,
          reply_to: mailbox | nil,
          headers: map,
          private: map,
          assigns: map,
          attachments: [Swoosh.Attachment.t()],
          provider_options: map
        }

  @doc ~S"""
  Returns a `Swoosh.Email` struct.

  You can pass a keyword list or a map argument to the function that will be used
  to populate the fields of that struct. Note that it will silently ignore any
  fields that it doesn't know about.

  ## Examples
      iex> new()
      %Swoosh.Email{}

      iex> new(subject: "Hello, Avengers!")
      %Swoosh.Email{subject: "Hello, Avengers!"}

      iex> new(from: "tony.stark@example.com")
      %Swoosh.Email{from: {"", "tony.stark@example.com"}}
      iex> new(from: {"Tony Stark", "tony.stark@example.com"})
      %Swoosh.Email{from: {"Tony Stark", "tony.stark@example.com"}}

      iex> new(to: "steve.rogers@example.com")
      %Swoosh.Email{to: [{"", "steve.rogers@example.com"}]}
      iex> new(to: {"Steve Rogers", "steve.rogers@example.com"})
      %Swoosh.Email{to: [{"Steve Rogers", "steve.rogers@example.com"}]}
      iex> new(to: [{"Bruce Banner", "bruce.banner@example.com"}, "thor.odinson@example.com"])
      %Swoosh.Email{to: [{"Bruce Banner", "bruce.banner@example.com"}, {"", "thor.odinson@example.com"}]}

      iex> new(cc: "steve.rogers@example.com")
      %Swoosh.Email{cc: [{"", "steve.rogers@example.com"}]}
      iex> new(cc: {"Steve Rogers", "steve.rogers@example.com"})
      %Swoosh.Email{cc: [{"Steve Rogers", "steve.rogers@example.com"}]}
      iex> new(cc: [{"Bruce Banner", "bruce.banner@example.com"}, "thor.odinson@example.com"])
      %Swoosh.Email{cc: [{"Bruce Banner", "bruce.banner@example.com"}, {"", "thor.odinson@example.com"}]}

      iex> new(bcc: "steve.rogers@example.com")
      %Swoosh.Email{bcc: [{"", "steve.rogers@example.com"}]}
      iex> new(bcc: {"Steve Rogers", "steve.rogers@example.com"})
      %Swoosh.Email{bcc: [{"Steve Rogers", "steve.rogers@example.com"}]}
      iex> new(bcc: [{"Bruce Banner", "bruce.banner@example.com"}, "thor.odinson@example.com"])
      %Swoosh.Email{bcc: [{"Bruce Banner", "bruce.banner@example.com"}, {"", "thor.odinson@example.com"}]}

      iex> new(html_body: "<h1>Welcome, Avengers</h1>")
      %Swoosh.Email{html_body: "<h1>Welcome, Avengers</h1>"}

      iex> new(text_body: "Welcome, Avengers")
      %Swoosh.Email{text_body: "Welcome, Avengers"}

      iex> new(reply_to: "edwin.jarvis@example.com")
      %Swoosh.Email{reply_to: {"", "edwin.jarvis@example.com"}}
      iex> new(reply_to: {"Edwin Jarvis", "edwin.jarvis@example.com"})
      %Swoosh.Email{reply_to: {"Edwin Jarvis", "edwin.jarvis@example.com"}}

      iex> new(headers: %{"X-Accept-Language" => "en"})
      %Swoosh.Email{headers: %{"X-Accept-Language" => "en"}}

      iex> new(assigns: %{user_id: 10})
      %Swoosh.Email{assigns: %{user_id: 10}}

      iex> new(provider_options: %{async: true})
      %Swoosh.Email{provider_options: %{async: true}}

  You can obviously combine these arguments together:

      iex> new(to: "steve.rogers@example.com", subject: "Hello, Avengers!")
      %Swoosh.Email{to: [{"", "steve.rogers@example.com"}], subject: "Hello, Avengers!"}
  """
  @spec new(none | Enum.t()) :: t
  def new(opts \\ []) do
    Enum.reduce(opts, %__MODULE__{}, &do_new/2)
  end

  defp do_new({key, value}, email)
       when key in [
              :subject,
              :from,
              :to,
              :cc,
              :bcc,
              :reply_to,
              :text_body,
              :html_body,
              :attachment
            ] do
    apply(__MODULE__, key, [email, value])
  end

  defp do_new({key, value}, email)
       when key in [:headers, :assigns, :provider_options] do
    Map.put(email, key, value)
  end

  defp do_new({key, value}, _email) do
    raise ArgumentError,
      message: """
      invalid field `#{inspect(key)}` (value=#{inspect(value)}) for Swoosh.Email.new/1.
      """
  end

  @doc """
  Sets a recipient in the `from` field.

  ## Examples

      iex> new() |> from({"Steve Rogers", "steve.rogers@example.com"})
      %Swoosh.Email{assigns: %{}, attachments: [], bcc: [], cc: [], from: {"Steve Rogers", "steve.rogers@example.com"},
       headers: %{}, html_body: nil, private: %{}, provider_options: %{},
       reply_to: nil, subject: "", text_body: nil, to: []}

      iex> new() |> from("steve.rogers@example.com")
      %Swoosh.Email{assigns: %{}, attachments: [], bcc: [], cc: [], from: {"", "steve.rogers@example.com"},
       headers: %{}, html_body: nil, private: %{}, provider_options: %{},
       reply_to: nil, subject: "", text_body: nil, to: []}
  """
  @spec from(t, Recipient.t()) :: t
  def from(%__MODULE__{} = email, from) do
    %{email | from: Recipient.format(from)}
  end

  @doc """
  Sets a recipient in the `reply_to` field.

  ## Examples

      iex> new() |> reply_to({"Steve Rogers", "steve.rogers@example.com"})
      %Swoosh.Email{assigns: %{}, attachments: [], bcc: [], cc: [], from: nil,
       headers: %{}, html_body: nil, private: %{}, provider_options: %{},
       reply_to: {"Steve Rogers", "steve.rogers@example.com"}, subject: "", text_body: nil, to: []}

      iex> new() |> reply_to("steve.rogers@example.com")
      %Swoosh.Email{assigns: %{}, attachments: [], bcc: [], cc: [], from: nil,
       headers: %{}, html_body: nil, private: %{}, provider_options: %{},
       reply_to: {"", "steve.rogers@example.com"}, subject: "", text_body: nil, to: []}
  """
  @spec reply_to(t, Recipient.t()) :: t
  def reply_to(%__MODULE__{} = email, reply_to) do
    %{email | reply_to: Recipient.format(reply_to)}
  end

  @doc """
  Sets the `subject` field.

  The subject must be a string that contains the subject.

  ## Examples

      iex> new() |> subject("Hello, Avengers!")
      %Swoosh.Email{assigns: %{}, attachments: [], bcc: [],
       cc: [], from: nil, headers: %{}, html_body: nil,
       private: %{}, provider_options: %{}, reply_to: nil, subject: "Hello, Avengers!",
       text_body: nil, to: []}
  """
  @spec subject(t, subject) :: t
  def subject(email, subject), do: %{email | subject: subject}

  @doc """
  Sets the `text_body` field.

  The text body must be a string that containing the plaintext content.

  ## Examples

      iex> new() |> text_body("Hello")
      %Swoosh.Email{assigns: %{}, attachments: [], bcc: [],
       cc: [], from: nil, headers: %{}, html_body: nil,
       private: %{}, provider_options: %{}, reply_to: nil, subject: "",
       text_body: "Hello", to: []}
  """
  @spec text_body(t, text_body | nil) :: t
  def text_body(email, text_body), do: %{email | text_body: text_body}

  @doc """
  Sets the `html_body` field.

  The HTML body must be a string that containing the HTML content.

  ## Examples

      iex> new() |> html_body("<h1>Hello</h1>")
      %Swoosh.Email{assigns: %{}, attachments: [], bcc: [],
       cc: [], from: nil, headers: %{}, html_body: "<h1>Hello</h1>",
       private: %{}, provider_options: %{}, reply_to: nil, subject: "",
       text_body: nil, to: []}
  """
  @spec html_body(t, html_body | nil) :: t
  def html_body(email, html_body), do: %{email | html_body: html_body}

  @doc """
  Adds new recipients in the `bcc` field.

      iex> new() |> bcc("steve.rogers@example.com")
      %Swoosh.Email{assigns: %{}, attachments: [], bcc: [{"", "steve.rogers@example.com"}],
       cc: [], from: nil, headers: %{}, html_body: nil,
       private: %{}, provider_options: %{}, reply_to: nil, subject: "",
       text_body: nil, to: []}
  """
  @spec bcc(t, Recipient.t() | [Recipient.t()]) :: t
  def bcc(%__MODULE__{bcc: bcc} = email, recipients) do
    recipients =
      recipients
      |> List.wrap()
      |> Enum.map(&Recipient.format(&1))
      |> Enum.concat(bcc)

    %{email | bcc: recipients}
  end

  @doc """
  Puts new recipients in the `bcc` field.

  It will replace any previously added `bcc` recipients.
  """
  @spec put_bcc(t, Recipient.t() | [Recipient.t()]) :: t
  def put_bcc(%__MODULE__{} = email, recipients) do
    %{email | bcc: recipients |> List.wrap() |> Enum.map(&Recipient.format(&1))}
  end

  @doc """
  Adds new recipients in the `cc` field.

  ## Examples

      iex> new() |> cc("steve.rogers@example.com")
      %Swoosh.Email{assigns: %{}, attachments: [], bcc: [],
       cc: [{"", "steve.rogers@example.com"}], from: nil, headers: %{}, html_body: nil,
       private: %{}, provider_options: %{}, reply_to: nil, subject: "",
       text_body: nil, to: []}
  """
  @spec cc(t, Recipient.t() | [Recipient.t()]) :: t
  def cc(%__MODULE__{cc: cc} = email, recipients) do
    recipients =
      recipients
      |> List.wrap()
      |> Enum.map(&Recipient.format(&1))
      |> Enum.concat(cc)

    %{email | cc: recipients}
  end

  @doc """
  Puts new recipients in the `cc` field.

  It will replace any previously added `cc` recipients.
  """
  @spec put_cc(t, Recipient.t() | [Recipient.t()]) :: t
  def put_cc(%__MODULE__{} = email, recipients) do
    %{email | cc: recipients |> List.wrap() |> Enum.map(&Recipient.format(&1))}
  end

  @doc """
  Adds new recipients in the `to` field.

  ## Examples

      iex> new() |> to("steve.rogers@example.com")
      %Swoosh.Email{assigns: %{}, attachments: [], bcc: [],
       cc: [], from: nil, headers: %{}, html_body: nil,
       private: %{}, provider_options: %{}, reply_to: nil, subject: "",
       text_body: nil, to: [{"", "steve.rogers@example.com"}]}
  """
  @spec to(t, Recipient.t() | [Recipient.t()]) :: t
  def to(%__MODULE__{to: to} = email, recipients) do
    recipients =
      recipients
      |> List.wrap()
      |> Enum.map(&Recipient.format(&1))
      |> Enum.concat(to)

    %{email | to: recipients}
  end

  @doc """
  Puts new recipients in the `to` field.

  It will replace any previously added `to` recipients.
  """
  @spec put_to(t, Recipient.t() | [Recipient.t()]) :: t
  def put_to(%__MODULE__{} = email, recipients) do
    %{email | to: recipients |> List.wrap() |> Enum.map(&Recipient.format(&1))}
  end

  @doc """
  Adds a new `header` in the email.

  The name and value must be specified as strings.

  ## Examples

      iex> new() |> header("X-Magic-Number", "7")
      %Swoosh.Email{assigns: %{}, attachments: [], bcc: [], cc: [], from: nil,
       headers: %{"X-Magic-Number" => "7"}, html_body: nil, private: %{},
       provider_options: %{}, reply_to: nil, subject: "", text_body: nil, to: []}
  """
  @spec header(t, String.t(), String.t()) :: t
  def header(%__MODULE__{} = email, name, value) when is_binary(name) and is_binary(value) do
    put_in(email.headers[name], value)
  end

  def header(%__MODULE__{}, name, value) do
    raise ArgumentError,
      message: """
      header/3 expects the header name and value to be strings.

      Instead it got:
        name: `#{inspect(name)}`.
        value: `#{inspect(value)}`.
      """
  end

  @doc ~S"""
  Stores a new **private** key and value in the email.

  This store is meant to be for libraries/framework usage. The name should be
  specified as an atom, the value can be any term.

  ## Examples

      iex> new() |> put_private(:phoenix_template, "welcome.html")
      %Swoosh.Email{assigns: %{}, attachments: [], bcc: [], cc: [], from: nil,
       headers: %{}, html_body: nil, private: %{phoenix_template: "welcome.html"},
       provider_options: %{}, reply_to: nil, subject: "", text_body: nil, to: []}
  """
  @spec put_private(t, atom, any) :: t
  def put_private(%__MODULE__{private: private} = email, key, value) when is_atom(key) do
    %{email | private: Map.put(private, key, value)}
  end

  @doc ~S"""
  Stores a new **provider_option** key and value in the email.

  This store is meant for adapter usage, to aid provider-specific functionality.
  The name should be specified as an atom, the value can be any term.

  ## Examples

      iex> new() |> put_provider_option(:async, true)
      %Swoosh.Email{assigns: %{}, attachments: [], bcc: [], cc: [], from: nil,
       headers: %{}, html_body: nil, private: %{}, provider_options: %{async: true},
       reply_to: nil, subject: "", text_body: nil, to: []}
  """
  @spec put_provider_option(t, atom, any) :: t
  def put_provider_option(%__MODULE__{provider_options: provider_options} = email, key, value)
      when is_atom(key) do
    %{email | provider_options: Map.put(provider_options, key, value)}
  end

  @doc ~S"""
  Stores a new variable key and value in the email.

  This store is meant for variables used in templating. The name should be specified as an atom, the value can be any
  term.

  ## Examples

      iex> new() |> assign(:username, "ironman")
      %Swoosh.Email{assigns: %{username: "ironman"}, attachments: [], bcc: [],
       cc: [], from: nil, headers: %{}, html_body: nil, private: %{},
       provider_options: %{}, reply_to: nil, subject: "", text_body: nil, to: []}
  """
  @spec assign(t, atom, any) :: t
  def assign(%__MODULE__{assigns: assigns} = email, key, value) when is_atom(key) do
    %{email | assigns: Map.put(assigns, key, value)}
  end

  @doc ~S"""
  Add a new attachment in the email.

  You can pass the path to a file, a `Swoosh.Attachment` or a `%Plug.Upload{}` struct
  as an argument. If you give a path we will detect the MIME type and determine the filename
  automatically.

  You can also send an inline-attachment used for embedding images in the body of emails by specifying `type: :inline`

  ## Examples

      iex> new() |> attachment("/data/att.zip")
      %Swoosh.Email{assigns: %{}, bcc: [], cc: [], from: nil,
       headers: %{}, html_body: nil, private: %{}, provider_options: %{},
       reply_to: nil, subject: "", text_body: nil, to: [],
       attachments: [%Swoosh.Attachment{path: "/data/att.zip",
        content_type: "application/zip", filename: "att.zip",
        type: :attachment, data: nil, headers: [], cid: nil}]}
      iex> new() |> attachment(Swoosh.Attachment.new("/data/att.zip"))
      %Swoosh.Email{assigns: %{}, bcc: [], cc: [], from: nil,
       headers: %{}, html_body: nil, private: %{}, provider_options: %{},
       reply_to: nil, subject: "", text_body: nil, to: [],
       attachments: [%Swoosh.Attachment{path: "/data/att.zip",
        content_type: "application/zip", filename: "att.zip",
        type: :attachment, data: nil, headers: [], cid: nil}]}
      iex> new() |> attachment(%Plug.Upload{path: "/data/abcdefg", content_type: "test/type", filename: "att.zip"})
      %Swoosh.Email{assigns: %{}, bcc: [], cc: [], from: nil,
       headers: %{}, html_body: nil, private: %{}, provider_options: %{},
       reply_to: nil, subject: "", text_body: nil, to: [],
       attachments: [%Swoosh.Attachment{path: "/data/abcdefg",
        content_type: "test/type", filename: "att.zip",
        type: :attachment, data: nil, headers: [], cid: nil}]}
      iex> new() |> attachment(Swoosh.Attachment.new("/data/att.png", type: :inline))
      %Swoosh.Email{assigns: %{}, bcc: [], cc: [], from: nil,
       headers: %{}, html_body: nil, private: %{}, provider_options: %{},
       reply_to: nil, subject: "", text_body: nil, to: [],
       attachments: [%Swoosh.Attachment{path: "/data/att.png",
        content_type: "image/png", filename: "att.png",
        type: :inline, data: nil, headers: [], cid: "att.png"}]}
  """
  @spec attachment(t, binary | Swoosh.Attachment.t()) :: t
  def attachment(%__MODULE__{attachments: attachments} = email, path) when is_binary(path) do
    %{email | attachments: [Swoosh.Attachment.new(path) | attachments]}
  end

  def attachment(%__MODULE__{attachments: attachments} = email, %Swoosh.Attachment{} = attachment) do
    %{email | attachments: [attachment | attachments]}
  end

  if Code.ensure_loaded?(Plug) do
    def attachment(%__MODULE__{attachments: attachments} = email, %Plug.Upload{} = upload) do
      %{email | attachments: [Swoosh.Attachment.new(upload) | attachments]}
    end
  end
end
