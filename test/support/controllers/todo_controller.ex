defmodule Electric.Phoenix.LiveViewTest.TodoController do
  use Phoenix.Controller, formats: [:html, :json]

  import Plug.Conn
  import Electric.Phoenix.Controller

  def all(conn, params) do
    render_shape(conn, params, table: "todos")
  end

  def complete(conn, params) do
    render_shape(conn, params, table: "todos", where: "completed = true")
  end
end
