defprotocol Swoosh.Email.Recipient do
  @moduledoc """
  Recipient Protocol controls how data is formatted into an email recipient

  ## Deriving

  The protocol allows leveraging the Elixir's `@derive` feature to simplify protocol implementation
  in trivial cases. Accepted options are:

    * `:name` (optional)
    * `:address` (required)

  ## Example

      defmodule MyUser do
        @derive {Swoosh.Email.Recipient, name: :name, address: :email}
        defstruct [:name, :email, :other_props]
      end

  or with optional name...

      defmodule MySubscriber do
        @derive {Swoosh.Email.Recipient, address: :email}
        defstruct [:email, :preferences]
      end

  full implementation without deriving...

      defmodule MyUser do
        defstruct [:name, :email, :other_props]
      end

      defimpl Swoosh.Email.Recipient, for: MyUser do
        def format(%MyUser{name: name, email: address} = value) do
          {name, address}
        end
      end
  """

  @type t :: term
  @fallback_to_any true

  @doc """
  Formats `value` into a Swoosh recipient, a 2-tuple with recipient name and recipient address
  """
  @spec format(t) :: Swoosh.Email.mailbox()
  def format(value)
end

defimpl Swoosh.Email.Recipient, for: Any do
  defmacro __deriving__(module, struct, opts) do
    name_field = Keyword.get(opts, :name)
    address_field = Keyword.fetch!(opts, :address)
    keys = Map.keys(struct)

    fields =
      [{:name, name_field}, {:address, address_field}]
      |> Enum.reject(fn {_, field} -> is_nil(field) end)
      |> Enum.map(fn {var, field} ->
        unless field in keys do
          raise ArgumentError, "#{inspect(field)} does not exist in #{inspect(struct)}"
        end

        {field, {var, [generated: true], __MODULE__}}
      end)

    quote do
      defimpl Swoosh.Email.Recipient, for: unquote(module) do
        def format(%{unquote_splicing(fields)}) do
          {unquote(if(name_field, do: Macro.var(:name, __MODULE__), else: "")), address}
        end
      end
    end
  end

  def format(data) do
    raise Protocol.UndefinedError,
      protocol: @protocol,
      value: data,
      description: """
      Swoosh.Email.Recipient needs to be implemented for #{inspect(data)}

      Default implementations of Recipient include
      * a string representing an email address like `foo.bar@example.com`
      * or a two-element tuple `{name, address}`, where name and address are strings.
        - name is allowed to be nil in this case
      """
  end
end

defimpl Swoosh.Email.Recipient, for: Tuple do
  def format({name, address}) when name in [nil, ""] and is_binary(address) and address != "" do
    {"", address}
  end

  def format({name, address}) when is_binary(name) and is_binary(address) and address != "" do
    {name, address}
  end

  def format(tuple) do
    raise ArgumentError, """
    Unexpected tuple format, #{inspect(tuple)} cannot be formatted into a Recipient.

    The expected format is {name :: String.t() | nil, address :: String.t()}, where address cannot be empty.
    """
  end
end

defimpl Swoosh.Email.Recipient, for: BitString do
  def format("") do
    raise ArgumentError, """
    Cannot format empty string into a Recipient.
    """
  end

  def format(address) when is_binary(address) do
    {"", address}
  end
end
