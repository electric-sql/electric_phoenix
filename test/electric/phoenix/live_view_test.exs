defmodule Electric.Phoenix.LiveViewTest do
  use ExUnit.Case, async: true

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  alias Electric.Phoenix.LiveViewTest.Endpoint
  alias Electric.Client

  @endpoint Endpoint

  Code.ensure_loaded(Support.User)

  setup do
    {:ok, conn: Plug.Test.init_test_session(build_conn(), %{})}
  end

  import Plug.Conn

  describe "stream/3" do
    test "simple live view", %{conn: conn} do
      {:ok, client} = Client.Mock.new()

      users = [
        %{id: 1, name: "User 1"},
        %{id: 2, name: "User 2"},
        %{id: 3, name: "User 3"}
      ]

      Client.Mock.async_response(client,
        status: 200,
        headers: [
          schema: %{id: %{type: "int8"}, name: %{type: "text"}},
          last_offset: Client.Offset.first(),
          shape_id: "users-1"
        ],
        body: Client.Mock.transaction(users, operation: :insert)
      )

      conn =
        conn
        |> put_private(:electric_client, client)
        |> put_private(:test_pid, self())

      {:ok, lv, html} = live(conn, "/stream")

      for %{name: name} <- users do
        assert html =~ name
      end

      users2 = [
        %{id: 4, name: "User 4"},
        %{id: 5, name: "User 5"},
        %{id: 6, name: "User 6"}
      ]

      {:ok, _req} =
        Client.Mock.response(client,
          status: 200,
          headers: [
            last_offset: Client.Offset.new(3, 2),
            shape_id: "users-1"
          ],
          body: Client.Mock.transaction(users2, lsn: 3, operation: :insert)
        )

      for _ <- users2 do
        assert_receive {:electric, _}
      end

      html = render(lv)

      for %{name: name} <- users ++ users2 do
        assert html =~ name
      end

      users3 = [
        %{id: 2, name: "User 2"},
        %{id: 4, name: "User 4"},
        %{id: 6, name: "User 6"}
      ]

      {:ok, _req} =
        Client.Mock.response(client,
          status: 200,
          headers: [
            last_offset: Client.Offset.new(4, 2),
            shape_id: "users-1"
          ],
          body: Client.Mock.transaction(users3, lsn: 4, operation: :delete)
        )

      for _ <- users3 do
        assert_receive {:electric, _}
      end

      html = render(lv)

      for %{name: name} <- users3 do
        refute html =~ name
      end
    end

    test "view with component", %{conn: conn} do
      {:ok, client} = Client.Mock.new()

      users = [
        %{id: 1, name: "User 1"},
        %{id: 2, name: "User 2"},
        %{id: 3, name: "User 3"}
      ]

      Client.Mock.async_response(client,
        status: 200,
        headers: [
          schema: %{id: %{type: "int8"}, name: %{type: "text"}},
          last_offset: Client.Offset.first(),
          shape_id: "users-1"
        ],
        body: Client.Mock.transaction(users, operation: :insert)
      )

      conn =
        conn
        |> put_private(:electric_client, client)
        |> put_private(:test_pid, self())

      {:ok, lv, html} = live(conn, "/stream/with-component")

      for %{name: name} <- users do
        assert html =~ name
      end

      users2 = [
        %{id: 4, name: "User 4"},
        %{id: 5, name: "User 5"},
        %{id: 6, name: "User 6"}
      ]

      {:ok, _req} =
        Client.Mock.response(client,
          status: 200,
          headers: [
            last_offset: Client.Offset.new(3, 2),
            shape_id: "users-1"
          ],
          body: Client.Mock.transaction(users2, lsn: 3, operation: :insert)
        )

      for _ <- users2 do
        assert_receive {:electric, _}
      end

      html = render(lv)
      IO.puts(html)

      for %{name: name} <- users ++ users2 do
        assert html =~ name
      end
    end
  end
end
