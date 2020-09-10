defmodule Libvips.MixProject do
  use Mix.Project

  def project do
    [
      app: :libvips,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: []
    ]
  end

  def application do
    []
  end

end
