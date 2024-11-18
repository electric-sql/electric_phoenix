defmodule Electric.Phoenix.Gateway do
  @moduledoc false

  alias Electric.Client
  alias Electric.Client.Fetch
  alias Electric.Client.ShapeDefinition

  @type configuration :: %{url: binary(), headers: %{binary() => binary()}, where: binary()}

  @spec configuration(Electric.Phoenix.shape_definition(), Client.t()) :: configuration()
  def configuration(shape_or_queryable, client \\ Electric.Phoenix.client!())

  @doc false
  def configuration(%Client.ShapeDefinition{} = shape, %Client{} = client) do
    request = Client.request(client, shape: shape)
    auth_headers = Client.authenticate_shape(client, shape)
    shape_params = ShapeDefinition.params(shape, format: :json)
    url = Fetch.Request.url(request, query: false)

    Map.merge(%{url: url, headers: auth_headers}, shape_params)
  end

  def configuration(%Ecto.Query{} = query, %Client{} = client) do
    query
    |> Electric.Client.shape!()
    |> configuration(client)
  end

  def configuration(module, %Client{} = client) when is_atom(module) do
    module
    |> Electric.Client.shape!()
    |> configuration(client)
  end
end
