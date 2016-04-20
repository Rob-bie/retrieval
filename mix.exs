defmodule Retrieval.Mixfile do
  use Mix.Project

  def project do
    [app: :retrieval,
     version: "0.9.1",
     elixir: "~> 1.2",
     description: description,
     package: package,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [{:earmark, "~> 0.1", only: :dev},
     {:ex_doc, "~> 0.11", only: :dev}]
  end

  def description do
    "Trie implementation in pure Elixir that supports pattern based lookup and other functionality."
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["Robbie D."],
      links: %{github: "https://github.com/Rob-bie/retrieval"}
    ]
  end
end
