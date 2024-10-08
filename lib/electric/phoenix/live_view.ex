defmodule Electric.Phoenix.LiveView do
  alias Electric.Client.Message

  require Record

  Record.defrecordp(:event, :"$electric_event", [:name, :operation, :item, opts: []])
  Record.defrecordp(:component_event, :"$electric_component_event", [:component, :event])

  @type root_event() ::
          record(:event,
            name: :atom | String.t(),
            operation: :atom,
            item: Electric.Client.message()
          )
  @type component_event() ::
          record(:component_event,
            component: term(),
            event: root_event()
          )
  @opaque event() :: root_event() | component_event()

  @doc false
  def client! do
    Electric.Client.new!(base_url: Application.fetch_env!(:electric_phoenix, :electric_url))
  end

  @doc false
  def stream(socket, name, query, opts \\ []) do
    {electric_opts, stream_opts} = Keyword.split(opts, [:client])

    component =
      case socket.assigns do
        %{myself: %Phoenix.LiveComponent.CID{} = component} -> component
        _ -> nil
      end

    if Phoenix.LiveView.connected?(socket) do
      client = Keyword.get_lazy(electric_opts, :client, &client!/0)
      # we stream until the live point then passover to the stream update messages
      # the raw stream needs to be mapped to pure ecto structs & &1.value

      Phoenix.LiveView.stream(
        socket,
        name,
        client_live_stream(client, name, query, component),
        stream_opts
      )
    else
      Phoenix.LiveView.stream(socket, name, [], stream_opts)
    end
  end

  @doc false
  def stream_update(socket, component_event(component: component, event: event), opts) do
    Phoenix.LiveView.send_update(component, electric: event(event, opts: opts))
    socket
  end

  def stream_update(
        socket,
        event(operation: :insert, name: name, item: item, opts: event_opts),
        opts
      ) do
    Phoenix.LiveView.stream_insert(socket, name, item, Keyword.merge(event_opts, opts))
  end

  def stream_update(socket, event(operation: :delete, name: name, item: item), _opts) do
    Phoenix.LiveView.stream_delete(socket, name, item)
  end

  defp client_live_stream(client, name, query, component) do
    pid = self()

    client
    |> Electric.Client.stream(query, live: false, snapshot: true, send_deltas: false)
    |> Stream.flat_map(&live_stream_message(&1, client, name, query, pid, component))
  end

  defp live_stream_message(
         %Message.ChangeMessage{value: value},
         # %Message.ChangeMessage{headers: %{operation: :insert}, value: value},
         _client,
         _name,
         _query,
         _pid,
         _component
       ) do
    [value]
  end

  defp live_stream_message(%Message.ResumeMessage{} = resume, client, name, query, pid, component) do
    Task.start_link(fn ->
      client
      |> Electric.Client.stream(query, resume: resume, send_deltas: false)
      |> Stream.each(&send_live_event(&1, pid, name, component))
      |> Stream.run()
    end)

    []
  end

  defp live_stream_message(_message, _client, _name, _query, _pid, _component) do
    []
  end

  defp send_live_event(
         %Message.ChangeMessage{headers: %{operation: operation}, value: item},
         pid,
         name,
         component
       )
       when operation in [:insert, :update] do
    send(
      pid,
      {:electric, wrap_event(component, event(operation: :insert, name: name, item: item))}
    )
  end

  defp send_live_event(
         %Message.ChangeMessage{headers: %{operation: :delete}, value: item},
         pid,
         name,
         component
       ) do
    send(
      pid,
      {:electric, wrap_event(component, event(operation: :delete, name: name, item: item))}
    )
  end

  defp send_live_event(_msg, _pid, _name, _component) do
    nil
  end

  defp wrap_event(nil, event) do
    event
  end

  defp wrap_event(component, event) do
    component_event(component: component, event: event)
  end
end
