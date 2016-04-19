defmodule Retrieval.PatternParser do

  @moduledoc """
  Parses and verifies patterns that can be matched against the trie data structure.
  """

  # Enter initial state
  def parse(pattern), do: parse(pattern, 1, [])

  # Accept wildcard
  def parse(<<"*", rest :: binary>>, col, acc) do
    parse(rest, col + 1, [:wildcard|acc])
  end

  # Jump to group state (exclusion)
  def parse(<<"[^", rest :: binary>>, col, acc) do
    parse_gr(rest, col + 1, %{}, acc, :exclusion, col)
  end

  # Jump to group state (inclusion)
  def parse(<<"[", rest :: binary>>, col, acc) do
    parse_gr(rest, col + 1, %{}, acc, :inclusion, col)
  end

  # Jump to capture state
  def parse(<<"{", rest :: binary>>, col, acc) do
    parse_cap(rest, col + 1, acc, <<>>, col)
  end

  # Pattern consumed, return parsed pattern
  def parse(<<>>, _col, acc), do: Enum.reverse(acc)

  # Accept character
  def parse(binary, col, acc) do
    case parse_escape(binary, col) do
      {:escape, ch, rest}    ->
        parse(rest, col + 3, [{:character, ch}|acc])
      {:character, ch, rest} ->
        parse(rest, col + 1, [{:character, ch}|acc])
    end
  end

  # Accept group
  defp parse_gr(<<"]", rest :: binary>>, col, group, acc, type, _start) do
    parse(rest, col + 1, [{type, group}|acc])
  end

  # Detect dangling group
  defp parse_gr(<<>>, _col, _group, _acc, type, start) do
    dangling_error("#{type}", start, "]")
  end

  # Detect group character
  defp parse_gr(binary, col, group, acc, type, start) do
    case parse_escape(binary, col) do
      {:escape, ch, rest}    ->
        group = Map.put(group, ch, ch)
        parse_gr(rest, col + 3, group, acc, type, start)
      {:character, ch, rest} ->
        group = Map.put(group, ch, ch)
        parse_gr(rest, col + 1, group, acc, type, start)
      unescaped_symbol_error ->
        unescaped_symbol_error
    end
  end

  # Accept capture or return unnamed capture error
  defp parse_cap(<<"}", rest :: binary>>, col, acc, name, start) do
    case name do
      <<>>  -> unnamed_capture_error(start, "capture cannot be empty")
      _     -> parse(rest, col + 1, [{:capture, name}|acc])
    end
  end

  # Jump to capture group (exclusion)
  defp parse_cap(<<"[^", rest :: binary>>, col, acc, name, start) do
    case name do
      <<>>  -> unnamed_capture_error(start, "capture must be named before group")
      _     -> parse_cap_gr(rest, col + 1, acc, name, %{}, :exclusion, {col, start})
    end
  end

  # Jump to capture group (inclusion)
  defp parse_cap(<<"[", rest :: binary>>, col, acc, name, start) do
    case name do
      <<>>  -> unnamed_capture_error(start, "capture must be named before group")
      _     -> parse_cap_gr(rest, col + 1, acc, name, %{}, :inclusion, {col, start})
    end
  end

  # Detect dangling capture
  defp parse_cap(<<>>, _col,  _acc, _name, start) do
    dangling_error("capture", start, "}")
  end

  # Detect capture name character
  defp parse_cap(binary, col, acc, name, start) do
    case parse_escape(binary, col) do
      {:escape, ch, rest}    ->
        parse_cap(rest, col + 3, acc, name <> <<ch>>, start)
      {:character, ch, rest} ->
        parse_cap(rest, col + 1, acc, name <> <<ch>>, start)
      unescaped_symbol_error ->
        unescaped_symbol_error
    end
  end

  # Accept capture group
  defp parse_cap_gr(<<"]}", rest :: binary>>, col, acc, name, group, type, _start) do
    parse(rest, col + 2, [{:capture, name, type, group}|acc])
  end

  # Detect nontrailing group or dangling capture
  defp parse_cap_gr(<<"]", rest :: binary>>, _col, _acc, _name, _group, type, {start, cap}) do
    case rest do
      <<>>  -> dangling_error("capture", cap, "}")
      _     -> nontrailing_group_error(start, type)
    end
  end

  defp parse_cap_gr(<<>>, _col, _acc, _name, _group, type, {start, _}) do
    dangling_error("#{type}", start, "]")
  end

  # Detect capture group character
  defp parse_cap_gr(binary, col, acc, name, group, type, start) do
    case parse_escape(binary, col) do
      {:escape, ch, rest}    ->
        group = Map.put(group, ch, ch)
        parse_cap_gr(rest, col + 3, acc, name, group, type, start)
      {:character, ch, rest} ->
        group = Map.put(group, ch, ch)
        parse_cap_gr(rest, col + 1, acc, name, group, type, start)
      unescaped_symbol_error ->
        unescaped_symbol_error
    end
  end

  # Detect escaped and unescaped symbols
  # 94  = ^
  # 42  = *
  # 91  = [
  # 93  = [
  # 123 = {
  # 125 = }
  # ... Emacs won't shut up if I use the ?c syntax with brackets and
  # I have no desire to fight with it. This will do.
  defp parse_escape(<<"\\^", rest :: binary>>, _col), do: {:escape, 94, rest}
  defp parse_escape(<<"\\*", rest :: binary>>, _col), do: {:escape, 42, rest}
  defp parse_escape(<<"\\[", rest :: binary>>, _col), do: {:escape, 91, rest}
  defp parse_escape(<<"\\]", rest :: binary>>, _col), do: {:escape, 93, rest}
  defp parse_escape(<<"\\{", rest :: binary>>, _col), do: {:escape, 123, rest}
  defp parse_escape(<<"\\}", rest :: binary>>, _col), do: {:escape, 125, rest}
  defp parse_escape(<<"^", _rest :: binary>>, col),   do: unescaped_symbol_error("^", col)
  defp parse_escape(<<"*", _rest :: binary>>, col),   do: unescaped_symbol_error("*", col)
  defp parse_escape(<<"[", _rest :: binary>>, col),   do: unescaped_symbol_error("[", col)
  defp parse_escape(<<"]", _rest :: binary>>, col),   do: unescaped_symbol_error("]", col)
  defp parse_escape(<<"{", _rest :: binary>>, col),   do: unescaped_symbol_error("{", col)
  defp parse_escape(<<"}", _rest :: binary>>, col),   do: unescaped_symbol_error("}", col)
  defp parse_escape(<<ch, rest :: binary>>, _col),    do: {:character, ch, rest}

  # Return dangling symbol error
  defp dangling_error(type, start_col, expected) do
    {:error, "Dangling group (#{type}) starting at column #{start_col}, expecting #{expected}"}
  end

  # Return unescaped symbol error
  defp unescaped_symbol_error(symbol, col) do
    {:error, "Unescaped symbol #{symbol} at column #{col}"}
  end

  # Return unnamed capture error
  defp unnamed_capture_error(start_col, context) do
    {:error, "Unnamed capture starting at column #{start_col}, #{context}"}
  end

  # Return trailing group error
  defp nontrailing_group_error(start_col, type) do
    {:error, "Group (#{type}) must in the tail position of capture starting at column #{start_col}"}
  end

end
