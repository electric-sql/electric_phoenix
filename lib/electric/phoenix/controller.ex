if Code.ensure_loaded?(Electric.Shapes.Api) do
  defmodule Electric.Phoenix.Controller do
    alias Electric.Shapes.Api

    def render_shape(conn, params, shape) do
      conn
      |> do_render_shape(params, shape)
      |> send_resp(conn)
    end

    defp do_render_shape(conn, params, shape) do
      config = Phoenix.Controller.endpoint_module(conn).config(:electric)
      api = config[:api] || raise "You must configure the Electric application in your endpoint."

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
