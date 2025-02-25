import Config

config :logger, level: :critical

config :electric_phoenix, Electric.Phoenix.LiveViewTest.Endpoint, []

config :electric_phoenix, Electric.Client, base_url: "http://localhost:3000"

# configure the support repo with random options so we can validate them in Electric.Phoenix.ConfigTest
config :electric_phoenix, Support.Repo,
  username: "postgres",
  password: "password",
  hostname: "localhost",
  database: "electric",
  port: 54321,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  ssl: true,
  socket_options: [:inet6],
  pool_size: 10
