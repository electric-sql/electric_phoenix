if Code.ensure_loaded?(Electric.Shapes.Api) do
  defmodule Electric.Phoenix.Controller do
    defmacro __using__(opts \\ []) do
      # validate that we're being used in the context of a Plug.Router impl
      Electric.Phoenix.Plug.Utils.env!(__CALLER__)

      quote do
        @electric_assign_opts Electric.Phoenix.Plug.Utils.opts_in_assign!(
                                unquote(opts),
                                __MODULE__,
                                Electric.Phoenix.Controller
                              )

        def render_shape(conn, shape) do
          case get_in(conn.assigns, [@electric_assign_opts, :electric, :api]) do
            %Electric.Shapes.Api{} = api ->
              conn =
                conn
                |> Plug.Conn.fetch_query_params()
                |> Plug.Conn.put_private(:electric_api, api)

              Electric.Phoenix.Controller.render_shape(conn, conn.params, shape)

            _ ->
              raise RuntimeError,
                message:
                  "Please configure your Router opts with [electric: Electric.Shapes.Api.plug_opts()]"
          end
        end
      end
    end

    alias Electric.Shapes.Api

    @spec render_shape(Plug.Conn.t(), Plug.Conn.params(), Electric.Shapes.Api.shape_opts()) ::
            Plug.Conn.t()
    def render_shape(conn, params, shape) do
      conn
      |> do_render_shape(params, shape)
      |> send_resp(conn)
    end

    defp do_render_shape(%{private: %{phoenix_endpoint: endpoint}} = conn, params, shape) do
      config = endpoint.config(:electric)

      api =
        config[:api] ||
          raise RuntimeError,
            message:
              "Please configure your Router opts with [electric: Electric.Shapes.Api.plug_opts()]"

      render_shape_api(conn, api, params, shape)
    end

    defp do_render_shape(%{private: %{electric_api: api}} = conn, params, shape) do
      render_shape_api(conn, api, params, shape)
    end

    defp render_shape_api(conn, api, params, shape) do
      with {:ok, shape_api} <- Api.predefined_shape(api, shape),
           {:ok, request} <- Api.validate(shape_api, params) do
        Plug.Conn.assign(conn, :request, request)
      end
    end

    defp send_resp({:error, response}, conn) do
      conn
      |> Api.Response.send(response)
      |> Plug.Conn.halt()
    end

    defp send_resp(%{assigns: %{request: request}} = conn, _) do
      Api.serve_shape_log(conn, request)
    end
  end
end
