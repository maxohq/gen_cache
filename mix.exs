defmodule GenCache.MixProject do
  use Mix.Project

  @github_url "https://github.com/maxohq/gen_cache"
  @version "0.1.0"
  @description "gen_statem based generic cache with MFA-based keys"

  def project do
    [
      app: :gen_cache,
      source_url: @github_url,
      version: @version,
      description: @description,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      test_paths: ["lib"],
      test_pattern: "*_test.exs",
      docs: [extras: ["README.md"]]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {GenCache.Application, []}
    ]
  end

  defp package do
    [
      files: ~w(lib mix.exs README* CHANGELOG* LICENCE*),
      licenses: ["MIT"],
      links: %{
        "Github" => @github_url,
        "Changelog" => "#{@github_url}/blob/main/CHANGELOG.md"
      }
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.29", only: :dev, runtime: false}
    ]
  end
end
