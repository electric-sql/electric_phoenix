defmodule Electric.Phoenix.Gateway do
  @moduledoc false

  alias Electric.Client
  alias Electric.Client.Fetch
  alias Electric.Client.ShapeDefinition

  @type configuration :: %{url: binary(), headers: %{binary() => binary()}, where: binary()}

  @doc false
  @spec configuration(Client.t(), ShapeDefinition.t()) :: configuration()
  def configuration(%Client{} = client, %Client.ShapeDefinition{} = shape) do
    request = Client.request(client, shape: shape)
    auth_headers = Client.authenticate_shape(client, shape)
    shape_params = ShapeDefinition.params(shape)
    url = Fetch.Request.url(request, query: false)

    Map.merge(%{url: url, headers: auth_headers}, shape_params)
  end
end
