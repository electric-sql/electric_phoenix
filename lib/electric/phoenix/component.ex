defmodule Electric.Phoenix.Component do
  use Phoenix.Component

  @doc """
  Embed client configuration for a shape into your HTML.

      <Electric.Phoenix.Component.electric_client_configuration
        shape={MyApp.Todo}
        key="todo_shape_config"
      />

  This will put a `<script>` tag into your page setting
  `window.todo_shape_config` to the configuration needed to subscribe to
  changes to the `MyApp.Todo` table.

      <script>
        window.todo_shape_config = {"url":"https://localhost:3000/v1/shape/todos" /* , ... */}
      </script>

  If you include a `:script` slot then you have complete control over how the
  configuration is applied.

      <Electric.Phoenix.Component.electric_client_configuration shape={MyApp.Todo}>
        <:script :let={configuration}>
          const container = document.getElementById("root")
          const root = createRoot(container)
          root.render(
            React.createElement(
              MyApp, {
                client_config: <%= configuration %>
              },
              null
            )
          );
        </:script>
      </Electric.Phoenix.Component.electric_client_configuration>

  The `configuration` variable in the `:script` block is the  JSON-encoded
  client configuration.

      <script>
        const container = document.getElementById("root")
        const root = createRoot(container)
        root.render(
          React.createElement(
            MyApp, {
              client_config: {"url":"https://localhost:3000/v1/shape/todos" /* , ... */}
            },
            null
          )
        );
      </script>
  """
  attr :shape, :any, required: true, doc: "The Ecto query (or schema module) to subscribe to"

  attr :key, :string,
    default: "electric_client_config",
    doc: "The key in the top-level `window` object to put the configuration object."

  attr :client, :any, doc: "Optional client. If not set defaults to `Electric.Phoenix.client!()`"

  slot :script,
    doc:
      "An optional inner block that allows you to override what you want to do with the configuration JSON"

  def electric_client_configuration(%{shape: shape} = assigns) do
    assigns = assign_new(assigns, :client, &Electric.Phoenix.client!/0)

    configuration = Electric.Phoenix.Gateway.configuration(shape, assigns.client)

    assigns =
      assign(
        assigns,
        :configuration,
        Phoenix.HTML.raw(Jason.encode!(configuration))
      )

    ~H"""
    <script>
      <%= if inner = render_slot(@script, @configuration) do %>
      <%= inner %>
      <% else %>
      window.<%= @key %> = <%= @configuration %>
      <% end %>
    </script>
    """
  end
end
