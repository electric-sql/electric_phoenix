defmodule Support.Repo do
  use Ecto.Repo,
    otp_app: :electric_phoenix,
    adapter: Ecto.Adapters.Postgres
end
