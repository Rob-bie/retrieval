defmodule Retrieval do

  alias Retrieval.Trie
  alias Retrieval.PatternParser

  @moduledoc """
  Provides an interface for creating and collecting data from the trie data structure.
  """

  @doc """
  Returns a new trie. Providing no arguments creates an empty trie. Optionally a binary or
  list of binaries can be passed to `new/1`.

  ## Examples

        Retrieval.new
        %Retrieval.Trie{...}

        Retrieval.new("apple")
        %Retrieval.Trie{...}

        Retrieval.new(~w/apple apply ape ample/)
        %Retrieval.Trie{...}

  """

  def new, do: %Trie{}

  def new(binaries) when is_list(binaries) do
    insert(%Trie{}, binaries)
  end

  def new(binary) when is_binary(binary) do
    insert(%Trie{}, binary)
  end

  @doc """
  Inserts a binary or list of binaries into an existing trie.

  ## Examples

        Retrieval.new |> Retrieval.insert("apple")
        %Retrieval.Trie{...}

        Retrieval.new(~w/apple apply ape ample/) |> Retrieval.insert(~w/zebra corgi/)
        %Retrieval.Trie{...}

  """

  def insert(%Trie{trie: trie}, binaries) when is_list(binaries) do
    %Trie{trie: Enum.reduce(binaries, trie, &_insert(&2, &1))}
  end

  def insert(%Trie{trie: trie}, binary) when is_binary(binary) do
    %Trie{trie: _insert(trie, binary)}
  end

  defp _insert(trie, <<next, rest :: binary>>) do
    case Map.has_key?(trie, next) do
      true  -> Map.put(trie, next, _insert(trie[next], rest))
      false -> Map.put(trie, next, _insert(%{}, rest))
    end
  end

  defp _insert(trie, <<>>) do
    Map.put(trie, :mark, :mark)
  end

  @doc """
  Returns whether or not a trie contains a given binary key.

  ## Examples

        Retrieval.new(~w/apple apply ape ample/) |> Retrieval.contains?("apple")
        true

        Retrieval.new(~w/apple apply ape ample/) |> Retrieval.contains?("zebra")
        false

  """

  def contains?(%Trie{trie: trie}, binary) when is_binary(binary) do
    _contains?(trie, binary)
  end

  defp _contains?(trie, <<next, rest :: binary>>) do
    case Map.has_key?(trie, next) do
      true  -> _contains?(trie[next], rest)
      false -> false
    end
  end

  defp _contains?(%{mark: :mark}, <<>>) do
    true
  end

  @doc """
  Collects all binaries that begin with a given prefix.

  ## Examples

        Retrieval.new(~w/apple apply ape ample/) |> Retrieval.prefix("ap")
        ["apple", "apply", "ape"]

        Retrieval.new(~w/apple apply ape ample/) |> Retrieval.prefix("z")
        []

  """

  def prefix(%Trie{trie: trie}, binary) when is_binary(binary) do
    _prefix(trie, binary, binary)
  end

  defp _prefix(trie, <<next, rest :: binary>>, acc) do
    case Map.has_key?(trie, next) do
      true  -> _prefix(trie[next], rest, acc)
      false -> []
    end
  end

  # An interesting discovery I made here is that treating the accumulator as a binary is actually quicker
  # than converting the prefix to a char list, prepending to it, reversing when a word is found, and converting
  # to a binary.
  defp _prefix(trie, <<>>, acc) do
    Enum.flat_map(trie, fn
      {:mark, :mark} -> [acc]
      {ch, sub_trie} -> _prefix(sub_trie, <<>>, acc <> <<ch>>)
    end)
  end

  @doc """
  Collects all binaries match a given pattern. Returns either a list of matches
  or an error in the form `{:error, reason}`.

  ## Patterns

       `*`      - Wildcard, matches any character.

       `[...]`  - Inclusion group, matches any character between brackets.

       `[^...]` - Exclusion group, matches any character not between brackets.

       `{...}`  - Capture group, must be named and can be combined with an
                  inclusion or exclusion group, otherwise treated as a wildcard.
                  All future instances of same name captures are swapped with
                  the value of the initial capture.

  ## Examples

        Retrieval.new(~w/apple apply ape ample/) |> Retrieval.pattern("a{1}{1}**")
        ["apple", "apply"]

        Retrieval.new(~w/apple apply ape ample/) |> Retrieval.pattern("*{1[^p]}{1}**")
        []

        Retrieval.new(~w/apple apply zebra house/) |> Retrieval.pattern("[hz]****")
        ["house", "zebra"]

        Retrieval.new(~w/apple apply zebra house/) |> Retrieval.pattern("[hz]***[^ea]")
        []

        Retrieval.new(~w/apple apply zebra house/) |> Retrieval.pattern("[hz]***[^ea")
        {:error, "Dangling group (exclusion) starting at column 8, expecting ]"}

  """

  def pattern(%Trie{trie: trie}, pattern) when is_binary(pattern) do
    _pattern(trie, %{}, pattern, <<>>, :parse)
  end

  defp _pattern(trie, capture_map, pattern, acc, :parse) do
    case PatternParser.parse(pattern) do
      {:error, message} -> {:error, message}
      parsed_pattern    -> _pattern(trie, capture_map, parsed_pattern, acc)
    end
  end

  defp _pattern(trie, capture_map, [{:character, ch}|rest], acc) do
    case Map.has_key?(trie, ch) do
      true  -> _pattern(trie[ch], capture_map, rest, acc <> <<ch>>)
      false -> []
    end
  end

  defp _pattern(trie, capture_map, [:wildcard|rest], acc) do
    Enum.flat_map(trie, fn
      {:mark, :mark} -> []
      {ch, sub_trie} -> _pattern(sub_trie, capture_map, rest, acc <> <<ch>>)
    end)
  end

  defp _pattern(trie, capture_map, [{:exclusion, exclusions}|rest], acc) do
    pruned_trie = Enum.filter(trie, fn({k, _v}) -> !(Map.has_key?(exclusions, k)) end)
    Enum.flat_map(pruned_trie, fn
      {:mark, :mark} -> []
      {ch, sub_trie} -> _pattern(sub_trie, capture_map, rest, acc <> <<ch>>)
    end)
  end

  defp _pattern(trie, capture_map, [{:inclusion, inclusions}|rest], acc) do
    pruned_trie = Enum.filter(trie, fn({k, _v}) -> Map.has_key?(inclusions, k) end)
    Enum.flat_map(pruned_trie, fn
      {:mark, :mark} -> []
      {ch, sub_trie} -> _pattern(sub_trie, capture_map, rest, acc <> <<ch>>)
    end)
  end

  defp _pattern(trie, capture_map, [{:capture, name}|rest], acc) do
    case Map.has_key?(capture_map, name) do
      true  ->
        match = capture_map[name]
        case Map.has_key?(trie, match) do
          true  -> _pattern(trie[match], capture_map, rest, acc <> <<match>>)
          false -> []
        end
      false ->
        Enum.flat_map(trie, fn
          {:mark, :mark} -> []
          {ch, sub_trie} ->
            capture_map = Map.put(capture_map, name, ch)
            _pattern(sub_trie, capture_map, rest, acc <> <<ch>>)
        end)
    end
  end

  defp _pattern(trie, capture_map, [{:capture, name, :exclusion, exclusions}|rest], acc) do
    case Map.has_key?(capture_map, name) do
      true  ->
        match = capture_map[name]
        case Map.has_key?(trie, match) do
          true  -> _pattern(trie[match], capture_map, rest, acc <> <<match>>)
          false -> []
        end
      false ->
        pruned_trie = Enum.filter(trie, fn({k, _v}) -> !(Map.has_key?(exclusions, k)) end)
        Enum.flat_map(pruned_trie, fn
          {:mark, :mark} -> []
          {ch, sub_trie} ->
            capture_map = Map.put(capture_map, name, ch)
            _pattern(sub_trie, capture_map, rest, acc <> <<ch>>)
        end)
    end
  end

  defp _pattern(trie, capture_map, [{:capture, name, :inclusion, inclusions}|rest], acc) do
    case Map.has_key?(capture_map, name) do
      true  ->
        match = capture_map[name]
        case Map.has_key?(trie, match) do
          true  -> _pattern(trie[match], capture_map, rest, acc <> <<match>>)
          false -> []
        end
      false ->
        pruned_trie = Enum.filter(trie, fn({k, _v}) -> Map.has_key?(inclusions, k) end)
        Enum.flat_map(pruned_trie, fn
          {:mark, :mark} -> []
          {ch, sub_trie} ->
            capture_map = Map.put(capture_map, name, ch)
            _pattern(sub_trie, capture_map, rest, acc <> <<ch>>)
        end)
    end
  end

  defp _pattern(trie, _capture_map, [], acc) do
    case Map.has_key?(trie, :mark) do
      true  -> [acc]
      false -> []
    end
  end

end
