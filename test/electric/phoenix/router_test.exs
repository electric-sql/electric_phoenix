defmodule Electric.Phoenix.RouterTest do
  use ExUnit.Case, async: true
  use Plug.Test

  import Support.DbSetup
  import Support.ElectricHelpers

  require Phoenix.ConnTest

  @registry __MODULE__.Registry
  @endpoint Electric.Phoenix.LiveViewTest.Endpoint

  setup do
    start_link_supervised!({Registry, keys: :duplicate, name: @registry})
    :ok
  end

  setup [:with_stack_id_from_test, :with_unique_db, :with_stack, :with_table, :with_data]

  setup(ctx) do
    Application.put_all_env(electric: electric_opts(ctx))
  end

  describe "shape/2" do
    @tag table: {
           "todos",
           [
             "id int8 not null primary key generated always as identity",
             "title text",
             "completed boolean default false"
           ]
         }
    @tag data: {"todos", ["title"], [["one"], ["two"], ["three"]]}

    test "uses path as table name by default", _ctx do
      resp =
        Phoenix.ConnTest.build_conn()
        |> Phoenix.ConnTest.get("/shape/todos", %{offset: "-1"})

      assert resp.status == 200
      assert Plug.Conn.get_resp_header(resp, "electric-offset") == ["0_0"]

      assert [
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "one"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "two"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "three"}}
             ] = Jason.decode!(resp.resp_body)
    end

    test "aborts compilation if given path is not a realistic table name" do
      assert_raise ArgumentError, fn ->
        Code.compile_string("""
        defmodule #{__MODULE__}.BadRouter do
          use Phoenix.Router
          import Phoenix.LiveView.Router
          import Electric.Phoenix.Router

          scope "/shapes" do
            shape "/todos/invalid"
          end
        end
        """)
      end
    end

    @tag table: {
           "todos",
           [
             "id int8 not null primary key generated always as identity",
             "title text",
             "completed boolean default false"
           ]
         }
    @tag data: {"todos", ["title"], [["one"], ["two"], ["three"]]}

    test "allows for specifying the table explicitly", _ctx do
      resp =
        Phoenix.ConnTest.build_conn()
        |> Phoenix.ConnTest.get("/shape/things-to-do", %{offset: "-1"})

      assert resp.status == 200
      assert Plug.Conn.get_resp_header(resp, "electric-offset") == ["0_0"]

      assert [
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "one"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "two"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "three"}}
             ] = Jason.decode!(resp.resp_body)
    end

    @tag table: {
           "ideas",
           [
             "id int8 not null primary key generated always as identity",
             "title text",
             "plausible boolean default false",
             "completed boolean default false"
           ]
         }
    @tag data: {
           "ideas",
           ["title", "plausible"],
           [["world peace", false], ["world war", true], ["make tea", true]]
         }

    test "allows for mixed definition using path and [where, column] modifiers", _ctx do
      resp =
        Phoenix.ConnTest.build_conn()
        |> Phoenix.ConnTest.get("/shape/ideas", %{offset: "-1"})

      assert resp.status == 200
      assert Plug.Conn.get_resp_header(resp, "electric-offset") == ["0_0"]

      assert [
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "world war"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "make tea"}}
             ] = Jason.decode!(resp.resp_body)
    end

    @tag table: {
           {"food", "toeats"},
           [
             "id int8 not null primary key generated always as identity",
             "food text"
           ]
         }
    @tag data: {
           {"food", "toeats"},
           ["food"],
           [["peas"], ["beans"], ["sweetcorn"]]
         }

    test "can provide a custom namespace", _ctx do
      resp =
        Phoenix.ConnTest.build_conn()
        |> Phoenix.ConnTest.get("/shape/toeats", %{offset: "-1"})

      assert resp.status == 200
      assert Plug.Conn.get_resp_header(resp, "electric-offset") == ["0_0"]

      assert [
               %{"headers" => %{"operation" => "insert"}, "value" => %{"food" => "peas"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"food" => "beans"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"food" => "sweetcorn"}}
             ] = Jason.decode!(resp.resp_body)
    end

    @tag table: {
           "todos",
           [
             "id int8 not null primary key generated always as identity",
             "title text",
             "completed boolean default false"
           ]
         }
    @tag data: {
           "todos",
           ["title", "completed"],
           [["one", false], ["two", false], ["three", true]]
         }

    test "accepts Ecto queries as the shape definition", _ctx do
      resp =
        Phoenix.ConnTest.build_conn()
        |> Phoenix.ConnTest.get("/shape/query-where", %{offset: "-1"})

      assert resp.status == 200
      assert Plug.Conn.get_resp_header(resp, "electric-offset") == ["0_0"]

      assert [
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "one"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "two"}}
             ] = Jason.decode!(resp.resp_body)

      resp =
        Phoenix.ConnTest.build_conn()
        |> Phoenix.ConnTest.get("/shape/query-bare", %{offset: "-1"})

      assert resp.status == 200
      assert Plug.Conn.get_resp_header(resp, "electric-offset") == ["0_0"]

      assert [
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "one"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "two"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "three"}}
             ] = Jason.decode!(resp.resp_body)

      resp =
        Phoenix.ConnTest.build_conn()
        |> Phoenix.ConnTest.get("/shape/query-config", %{offset: "-1"})

      assert resp.status == 200
      assert Plug.Conn.get_resp_header(resp, "electric-offset") == ["0_0"]

      assert [
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "one"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "two"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "three"}}
             ] = Jason.decode!(resp.resp_body)

      resp =
        Phoenix.ConnTest.build_conn()
        |> Phoenix.ConnTest.get("/shape/query-config2", %{offset: "-1"})

      assert resp.status == 200
      assert Plug.Conn.get_resp_header(resp, "electric-offset") == ["0_0"]

      assert [
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "one"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "two"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "three"}}
             ] = Jason.decode!(resp.resp_body)

      resp =
        Phoenix.ConnTest.build_conn()
        |> Phoenix.ConnTest.get("/shape/query-module", %{offset: "-1"})

      assert resp.status == 200
      assert Plug.Conn.get_resp_header(resp, "electric-offset") == ["0_0"]

      assert [
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "one"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "two"}},
               %{"headers" => %{"operation" => "insert"}, "value" => %{"title" => "three"}}
             ] = Jason.decode!(resp.resp_body)
    end
  end
end
