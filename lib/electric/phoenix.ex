defmodule Electric.Phoenix do
  @moduledoc """
  Wrappers to ease integration of [Electric’s Postgres syncing
  service](https://electric-sql.com) with [Phoenix
  applications](https://www.phoenixframework.org/).

  There are currently 2 integration modes: [`Phoenix.LiveView`
  streams](#module-phoenix-liveview-streams) and [configuration
  gateway](#module-configuration-gateway).

  ## Phoenix.LiveView Streams

  `live_stream/4` wraps
  [`Phoenix.LiveView.stream/4`](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#stream/4)
  and provides a live updating collection of items.

  ## Configuration Gateway

  Using `Electric.Phoenix.Gateway.Plug` you can create endpoints that
  return configuration information for your Electric Typescript clients. See
  [that module's documentation](`Electric.Phoenix.Gateway.Plug`) for
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
        electric_url: System.get_env("ELECTRIC_URL", "http://localhost:3000")

  """

  @options NimbleOptions.new!(client: [type: {:struct, Electric.Client}])

  @type stream_option() ::
          {:at, integer()}
          | {:limit, pos_integer()}
          | {:reset, boolean()}
          | unquote(NimbleOptions.option_typespec(@options))

  @type stream_options() :: [stream_option()]

  @doc """
  Create a new `Electric.Client` instance based on the application config.
  """
  def client! do
    Electric.Client.new!(base_url: Application.fetch_env!(:electric_phoenix, :electric_url))
  end

  @doc ~S"""
  Maintains a LiveView stream from the given Ecto query.

  - `name` The name to use for the LiveView stream.
  - `query` An [`Ecto`](`Ecto`) query that represents the data to stream from the database.

  For example:

      def mount(_params, _session, socket) do
        socket =
          Electric.Phoenix.live_stream(
            socket,
            :admins,
            from(u in Users, where: u.admin == true)
          )
        {:ok, socket}
      end

  This will subscribe to the configured Electric server and keep the list of
  `:admins` in sync with the database via a `Phoenix.LiveView` stream.

  Updates will be delivered to the view via messages to the LiveView process.

  To handle these you need to add a `handle_info/2` implementation that receives these:

      def handle_info({:electric, event}, socket) do
        {:noreply, Electric.Phoenix.stream_update(socket, event)}
      end

  See the docs for
  [`Phoenix.LiveView.stream/4`](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#stream/4)
  for details on using LiveView streams.

  ## Lifecycle Events

  Most `{:electric, event}` messages are opaque and should be passed directly
  to the `stream_update/3` function, but there are two events that are meant to
  be handled directly in the LiveView component.

  - `{:electric, :loaded}` - sent when the Electric event stream has passed
  from initial state to update mode.

  - `{:electric, :live}` - sent when the Electric stream is in `live` mode,
  that is the initial state has loaded and the client is waiting for updates
  from the db.

  The `{:electric, :live}` event is useful to show the stream component after
  the initial sync. Because of the streaming nature of Electric Shapes, the
  intitial sync can cause flickering as items are added, removed and updated.

  E.g.:

      # in the LiveView component
      def handle_info(`{:electric, :live}`, socket) do
        {:noreply, assign(socket, :show_stream, true)}
      end

      # in the template
      <div phx-update="stream" class={unless(@show_stream, do: "opacity-0")}>
        <div :for={{id, item} <- @streams.items} id={id}>
          <%= item.value %>
        </div>
      </div>

  ## Sub-components

  If you register your Electric stream in a sub-component you will still
  receive Electric messages in the LiveView's root/parent process.

  `Electric.Phoenix` handles this for you by encapsulating component messages
  so it can correctly forward on the event to the component.

  So in the parent `LiveView` process you handle the `:electric` messages as
  above:

      defmodule MyLiveView do
        use Phoenix.LiveView

        def render(assigns) do
          ~H\"""
          <div>
            <.live_component id="my_component" module={MyComponent} />
          </div>
          \"""
        end

        # We setup the Electric live_stream in the component but update messages will
        # be sent to the parent process.
        def handle_info({:electric, event}, socket) do
          {:noreply, Electric.Phoenix.stream_update(socket, event)}
        end
      end

  In the component you must handle these events in the
  `c:Phoenix.LiveComponent.update/2` callback:

      defmodule MyComponent do
        use Phoenix.LiveComponent

        def render(assigns) do
          ~H\"""
          <div id="users" phx-update="stream">
            <div :for={{id, user} <- @streams.users} id={id}>
              <%= user.name %>
            </div>
          </div>
          \"""
        end

        # Equivalent to the `handle_info({:electric, :live}, socket)` callback
        # in the parent LiveView.
        def update(%{electric: :live}, socket) do
          {:ok, socket}
        end

        # Equivalent to the `handle_info({:electric, event}, socket)` callback
        # in the parent LiveView.
        def update(%{electric: event}, socket) do
          {:ok, Electric.Phoenix.stream_update(socket, event)}
        end

        def update(assigns, socket) do
          {:ok, Electric.Phoenix.live_stream(socket, :users, User)}
        end
      end
  """
  @spec live_stream(
          socket :: Phoenix.LiveView.Socket.t(),
          name :: atom() | String.t(),
          query :: Ecto.Queryable.t(),
          opts :: stream_options()
        ) :: Phoenix.LiveView.Socket.t()
  def live_stream(socket, name, query, opts \\ []) do
    Electric.Phoenix.LiveView.stream(socket, name, query, opts)
  end

  @doc """
  Handle Electric events within a LiveView.

      def handle_info({:electric, event}, socket) do
        {:noreply, Electric.Phoenix.stream_update(socket, event, at: 0)}
      end

  The `opts` are passed to the `Phoenix.LiveView.stream_insert/4` call.
  """
  @spec stream_update(
          Phoenix.LiveView.Socket.t(),
          Electric.Phoenix.LiveView.event(),
          Keyword.t()
        ) :: Phoenix.LiveView.Socket.t()
  def stream_update(socket, event, opts \\ []) do
    Electric.Phoenix.LiveView.stream_update(socket, event, opts)
  end
end
