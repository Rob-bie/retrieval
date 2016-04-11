defmodule Retrieval do
  alias Retrieval.Trie

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

end
