use Mix.Config

config :omg_eth,
  geth_logging_in_debug: false,
  loggers: [Appsignal.Ecto, Ecto.LogEntry]
