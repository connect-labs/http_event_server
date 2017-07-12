defmodule HTTPEventServer.Mixfile do
  use Mix.Project

  def project do
    [app: :http_event_server,
     name: "HTTP Event Server",
     description: description(),
     package: package(),
     source_url: "https://github.com/humphreyja/http_event_server",
     version: "0.2.0",
     elixir: "~> 1.4",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [
      extra_applications: [:logger, :cowboy, :plug, :httpoison]
   ]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # To depend on another app inside the umbrella:
  #
  #   {:my_app, in_umbrella: true}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:cowboy, ">= 1.0.0"},
      {:plug, "~> 1.3"},
      {:httpoison, "0.11.1"},
      {:poison, "~> 3.1"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end

  defp description do
    """
    Simple HTTP/HTTPS message handler for running tasks from other apps.
    This allows for both async and sync message sending between the apps for use on Heroku.
    """
  end

  defp package do
    # These are the default files included in the package
    [
      name: :http_event_server,
      files: ["lib", "mix.exs", "README*", "LICENSE*"],
      maintainers: ["Jake Humphrey"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/codelation/elixir-messenger"}
    ]
  end
end
