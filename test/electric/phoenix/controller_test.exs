defmodule Electric.Phoenix.ControllerTest do
  use ExUnit.Case, async: true
  use Plug.Test

  require Phoenix.ConnTest

  import Support.DbSetup
  import Support.ElectricHelpers

  @endpoint Electric.Phoenix.LiveViewTest.Endpoint

  Code.ensure_loaded(Support.Todo)

  # setup do
  #   start_link_supervised!({Registry, keys: :duplicate, name: @registry})
  #   :ok
  # end

  setup [:with_stack_id_from_test, :with_unique_db, :with_stack, :with_table, :with_data]

  describe "render_shape/2" do
    @describetag table: {
                   "todos",
                   [
                     "id int8 not null primary key generated always as identity",
                     "title text",
                     "completed boolean default false"
                   ]
                 }
    @describetag data:
                   {"todos", ["title", "completed"],
                    [["one", false], ["two", false], ["three", true]]}

    setup(ctx) do
      Application.put_all_env(electric: electric_opts(ctx))
    end

    test "returns the shape data", _cxt do
      resp =
        Phoenix.ConnTest.build_conn()
        |> Phoenix.ConnTest.get("/todos/all", %{offset: "-1"})

      assert resp.status == 200
      assert Plug.Conn.get_resp_header(resp, "electric-offset") == ["0_0"]

      assert [
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "one"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "two"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "three"}}
             ] = Jason.decode!(resp.resp_body)
    end

    test "supports where clauses", _cxt do
      resp =
        Phoenix.ConnTest.build_conn()
        |> Phoenix.ConnTest.get("/todos/complete", %{offset: "-1"})

      assert resp.status == 200
      assert Plug.Conn.get_resp_header(resp, "electric-offset") == ["0_0"]

      assert [
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "three"}}
             ] = Jason.decode!(resp.resp_body)
    end
  end
end
