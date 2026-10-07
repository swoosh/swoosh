defmodule Swoosh.Adapters.MailChannels.Message do
  @moduledoc false
  alias Swoosh.{Attachment, Email}

  @structural ~w(to cc bcc from sender reply-to return-path subject content-type content-transfer-encoding mime-version message-id authentication-results dkim-signature received)

  def prepare(%Email{} = email) do
    with :ok <- supported(email),
         {:ok, from} <- address(email.from),
         {:ok, to} <- addresses(email.to, true),
         {:ok, cc} <- addresses(email.cc, false),
         {:ok, bcc} <- addresses(email.bcc, false),
         {:ok, reply} <- reply_to(email.reply_to),
         {:ok, content} <- content(email),
         {:ok, headers} <- headers(email.headers),
         {:ok, attachments} <- attachments(email.attachments),
         true <- line?(email.subject) do
      group = %{to: to} |> optional(:cc, cc) |> optional(:bcc, bcc)

      {:ok,
       %{from: from, subject: email.subject, personalizations: [group], content: content}
       |> optional(:reply_to, reply)
       |> optional(:headers, headers)
       |> optional(:attachments, attachments)}
    else
      {:error, _} = error -> error
      _ -> {:error, :invalid_email}
    end
  end

  def prepare(_), do: {:error, :invalid_email}

  defp supported(%{provider_options: options}) when options == %{}, do: :ok
  defp supported(_), do: {:error, :unsupported_provider_options}
  defp optional(map, _, value) when value in [nil, [], %{}], do: map
  defp optional(map, key, value), do: Map.put(map, key, value)

  defp line?(value),
    do:
      is_binary(value) and String.valid?(value) and
        not String.contains?(value, ["\r", "\n", <<0>>])

  defp address({name, email}) do
    if line?(name) and line?(email) and email != "" do
      {:ok, if(name == "", do: %{email: email}, else: %{email: email, name: name})}
    else
      {:error, :invalid_email}
    end
  end

  defp address(_), do: {:error, :invalid_email}

  defp addresses(values, required) when is_list(values) do
    if length(values) <= 1000 and (not required or values != []) do
      collect(values, &address/1)
    else
      {:error, :invalid_recipients}
    end
  end

  defp addresses(_, _), do: {:error, :invalid_recipients}
  defp reply_to(value) when value in [nil, []], do: {:ok, nil}
  defp reply_to([value]), do: address(value)
  defp reply_to(values) when is_list(values), do: {:error, :unsupported_reply_to}
  defp reply_to(value), do: address(value)

  defp content(email) do
    parts = [{"text/plain", email.text_body}, {"text/html", email.html_body}]

    if Enum.all?(parts, fn {_, body} ->
         is_nil(body) or (is_binary(body) and String.valid?(body))
       end) do
      values =
        for {type, body} <- parts, is_binary(body) and body != "", do: %{type: type, value: body}

      if values == [], do: {:error, :missing_content}, else: {:ok, values}
    else
      {:error, :invalid_content}
    end
  end

  defp headers(values) when is_map(values) do
    names = Map.keys(values)

    valid =
      Enum.all?(values, fn {name, value} ->
        is_binary(name) and Regex.match?(~r/^[!#$%&'*+.^_`|~0-9A-Za-z-]+$/, name) and
          line?(value) and String.downcase(name) not in @structural
      end)

    if valid and length(Enum.uniq_by(names, &String.downcase/1)) == length(names),
      do: {:ok, values},
      else: {:error, :invalid_headers}
  end

  defp headers(_), do: {:error, :invalid_headers}

  defp attachments(values) when is_list(values) and length(values) <= 1000 do
    with {:ok, mapped} <- collect(values, &attachment/1) do
      ids = for %{content_id: id} <- mapped, do: id

      if length(ids) == length(Enum.uniq(ids)),
        do: {:ok, mapped},
        else: {:error, :duplicate_content_id}
    end
  end

  defp attachments(_), do: {:error, :invalid_attachments}

  defp attachment(%Attachment{} = value) do
    cond do
      value.headers != [] -> {:error, :unsupported_attachment_headers}
      value.type not in [:attachment, :inline] -> {:error, :invalid_attachment}
      not line?(value.filename) or value.filename == "" -> {:error, :invalid_attachment}
      not line?(value.content_type) or value.content_type == "" -> {:error, :invalid_attachment}
      value.type == :attachment and value.cid != nil -> {:error, :unsupported_attachment_cid}
      true -> attachment_body(value)
    end
  end

  defp attachment(_), do: {:error, :invalid_attachment}

  defp attachment_body(value) do
    cid = if value.type == :inline, do: value.cid || value.filename

    if cid == nil or (is_binary(cid) and Regex.match?(~r/^[\x21-\x3B\x3D\x3F-\x7E]{1,255}$/, cid)) do
      try do
        body = Attachment.get_content(value)

        if is_binary(body) do
          {:ok,
           %{filename: value.filename, type: value.content_type, content: Base.encode64(body)}
           |> optional(:content_id, cid)}
        else
          {:error, :invalid_attachment}
        end
      rescue
        _ -> {:error, :attachment_unavailable}
      end
    else
      {:error, :invalid_content_id}
    end
  end

  defp collect(values, mapper) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      case mapper.(value) do
        {:ok, mapped} -> {:cont, {:ok, [mapped | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, values} -> {:ok, Enum.reverse(values)}
      error -> error
    end
  end
end
