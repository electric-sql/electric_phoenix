defmodule Electric.Phoenix.Component do
  use Phoenix.Component

  attr :client, :any, default: Electric.Phoenix.client!()
  attr :shape, :any, required: true
  attr :variable_name, :string, default: "electric_client_config"

  def electric_client(%{client: client, shape: shape} = assigns) do
    configuration = Electric.Phoenix.Gateway.configuration(shape, client)

    assigns = assign(assigns, :configuration, configuration)

    ~H"""
    <script>
      window.<%= @variable_name %> = <%= Phoenix.HTML.raw(Jason.encode!(@configuration, pretty: true)) %>
    </script>
    """
  end
end
