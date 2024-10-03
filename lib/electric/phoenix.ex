defmodule Electric.Phoenix do
  @moduledoc """
  ...Integration with Phoenix...

  # LiveView
  ## LiveView Components

  You can use an electric stream in a component within a view.

  If you do this you must forward events from the Electric client onto the component using 
  `send_update/3`

      def handle_info({:electric, event}, socket) do
        send_update(ApplicationWeb.SomeComponent, id: "todos_list", electric: event)
      end
      def handle_info({:electric, component_id, event}, socket) do
        send_update(ApplicationWeb.SomeComponent, id: "todos_list", electric: event)
      end
  """
  @options NimbleOptions.new!(client: [type: {:struct, Electric.Client}])

  @type stream_option() ::
          {:at, integer()}
          | {:limit, pos_integer()}
          | {:reset, boolean()}
          | unquote(NimbleOptions.option_typespec(@options))

  @type stream_options() :: [stream_option()]

  @doc """
  Maintains a LiveView stream from the given Ecto query.

  For example:

      socket =
        Electric.Phoenix.live_stream(
          socket,
          :admins,
          from(u in Users, where: u.admin == true)
        )

  This will subscribe to the configured Electric server and keep the list of
  `:admins` in sync with the database via a Phoenix.LiveView stream.

  Updates will be delivered to the view via messages to the LiveView process.

  To handle these you need to add a `handle_info/2` implementation that receives these:

      def handle_info({:electric, event}, socket) do
        {:noreply, Electric.Phoenix.stream_update(socket, event)}
      end

  See the docs for
  [`Phoenix.LiveView.stream/4`](https://hexdocs.pm/phoenix_live_view/Phoenix.LiveView.html#stream/4)
  for details on using LiveView streams.
  """
  @spec live_stream(
          Phoenix.LiveView.Socket.t(),
          atom() | String.t(),
          Ecto.Queryable.t(),
          stream_options()
        ) :: Phoenix.LiveView.Socket.t()
  def live_stream(socket, name, query, opts \\ []) do
    Electric.Phoenix.LiveView.stream(socket, name, query, opts)
  end

  @spec stream_update(
          Phoenix.LiveView.Socket.t(),
          Electric.Phoenix.LiveView.event()
        ) :: Phoenix.LiveView.Socket.t()
  def stream_update(socket, event, opts \\ []) do
    Electric.Phoenix.LiveView.stream_update(socket, event, opts)
  end
end
