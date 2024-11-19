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
  client for the Electric streaming API:

      import Config

      config :electric_phoenix, Electric.Client,
        # one of `base_url` or `endpoint` is required
        base_url: System.get_env("ELECTRIC_URL", "http://localhost:3000"),
        # endpoint: System.get_env("ELECTRIC_ENDPOINT", "http://localhost:3000/v1/shape"),
        # optional
        database_id: System.get_env("ELECTRIC_DATABASE_ID", nil)

  See the documentation for [`Electric.Client.new/1`](`Electric.Client.new/1`)
  for information on the client configuration.
  """

  @type shape_definition :: Ecto.Queryable.t() | Client.ShapeDefinition.t()

  @doc """
  Create a new `Electric.Client` instance based on the application config.

  See [`Electric.Client.new/1`](`Electric.Client.new/1`) for the available
  options.
  """
  def client!(opts \\ []) do
    :electric_phoenix
    |> Application.fetch_env!(Electric.Client)
    |> Keyword.merge(opts)
    |> Electric.Client.new!()
  end
end
