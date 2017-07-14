use Mix.Config

config :logger, :console,
  format: "[$level  -  HTTP EVENT SERVER] $levelpad$message\n\t\tData: $levelpad$metadata\n",
  metadata: [:event]
