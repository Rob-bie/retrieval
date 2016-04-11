defmodule Retrieval do

  alias Retrieval.Trie

  def new, do: %Trie{}

  def new(binaries) when is_list(binaries) do
    insert(%Trie{}, binaries)
  end

  def new(binary) when is_binary(binary) do
    insert(%Trie{}, binary)
  end

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

end
