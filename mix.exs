defmodule MavisInference.MixProject do
  use Mix.Project

  def project do
    [
      app: :mavis_inference,
      version: "0.1.0",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:mavis, github: "ityonemo/mavis"}
    ]
  end
end
