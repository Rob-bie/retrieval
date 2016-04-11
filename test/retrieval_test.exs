defmodule RetrievalTest do
  use ExUnit.Case
  doctest Retrieval

  @test_data ~w/apple apply ape bed between betray cat cold hot
                warm winter maze smash crush under above people
                negative poison place out divide zebra extended/

  @test_trie Retrieval.new(@test_data)

  test "empty trie" do
    assert Retrieval.new == %Retrieval.Trie{}
  end

  test "contains?" do
    assert Retrieval.contains?(@test_trie, "apple") == true
    assert Retrieval.contains?(@test_trie, "smash") == true
    assert Retrieval.contains?(@test_trie, "abcde") == false
  end

  test "prefix" do
    app_prefix = ["apple", "apply"]
    n_prefix = ["negative"]
    abc_prefix = []

    assert Retrieval.prefix(@test_trie, "app") == app_prefix
    assert Retrieval.prefix(@test_trie, "n")   == n_prefix
    assert Retrieval.prefix(@test_trie, "abc") == abc_prefix
  end

end
