defmodule SknLib.MixProject do
  use Mix.Project

  def project do
    [
      app: :skn_lib,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :mnesia]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
#      {:epipe, "~> 1.0"}
    ]
  end
end
