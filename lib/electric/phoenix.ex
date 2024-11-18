defmodule Electric.Phoenix do
  @moduledoc """
  Wrappers to ease integration of [Electric’s Postgres syncing
  service](https://electric-sql.com) with [Phoenix
  applications](https://www.phoenixframework.org/).

  There are currently 2 integration modes: [`Phoenix.LiveView`
  streams](#module-phoenix-liveview-streams) and [configuration
  gateway](#module-configuration-gateway).

  ## Phoenix.LiveView Streams

  `Electric.Phoenix.LiveView.electric_stream/4` integrates with
  [`Phoenix.LiveView.stream/4`](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#stream/4)
  and provides a live updating collection of items.

  ## Configuration Gateway

  Using `Electric.Phoenix.Plug` you can create endpoints that
  return configuration information for your Electric Typescript clients. See
  [that module's documentation](`Electric.Phoenix.Plug`) for
  more information.

  ## Installation

  Add `electric_phoenix` to your application dependencies:

      def deps do
        [
          {:electric_phoenix, "~> 0.1"}
        ]
      end

  ## Configuration

  In your `config/config.exs` or `config/runtime.exs` you **must** configure the
  endpoint for the Electric streaming API:

      import Config

      config :electric_phoenix,
        # required
        electric_url: System.get_env("ELECTRIC_URL", "http://localhost:3000"),
        # optional
        database_id: System.get_env("ELECTRIC_DATABASE_ID", nil)
  """

  @type shape_definition :: Ecto.Queryable.t() | Client.ShapeDefinition.t()

  @doc """
  Create a new `Electric.Client` instance based on the application config.
  """
  def client! do
    Electric.Client.new!(
      base_url: Application.fetch_env!(:electric_phoenix, :electric_url),
      database_id: Application.get_env(:electric_phoenix, :database_id)
    )
  end
end
