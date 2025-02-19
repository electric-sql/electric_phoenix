defmodule Electric.PhoenixTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Electric.Client

  doctest Electric.Phoenix

  describe "client!/1" do
    # all the other tests use an explict client config, so we're ok
    # to run this in parallel
    defp with_client_configuration(fun, configuration \\ []) do
      existing = Electric.Phoenix.client_config()
      Application.put_env(:electric_phoenix, Electric.Client, configuration)

      try do
        fun.()
      after
        Application.put_env(:electric_phoenix, Electric.Client, existing)
      end
    end

    test "uses http configuration if present" do
      with_client_configuration(
        fn ->
          assert %Client{fetch: {Client.Fetch.HTTP, _}} = Electric.Phoenix.client!()
        end,
        base_url: "http://localhost:3000"
      )
    end

    test "uses embedded configuration if config empty and electric available" do
      %{fetch: embedded_fetch} = Client.embedded!()

      with_client_configuration(fn ->
        assert %Client{fetch: ^embedded_fetch} = Electric.Phoenix.client!()
      end)
    end
  end

  describe "shape_from_params/[1,2]" do
    alias Electric.Client.ShapeDefinition

    test "returns a ShapeDefinition based on the request query params" do
      conn =
        conn(:get, "/my/path", %{
          "table" => "items",
          "namespace" => "my_app",
          "where" => "something = 'open'",
          "columns" => "id,name,value"
        })

      assert {:ok,
              %ShapeDefinition{
                table: "items",
                namespace: "my_app",
                where: "something = 'open'",
                columns: ["id", "name", "value"]
              }} = Electric.Phoenix.shape_from_params(conn)

      conn = conn(:get, "/my/path", %{"table" => "items"})

      assert {:ok,
              %ShapeDefinition{
                table: "items",
                namespace: nil,
                where: nil,
                columns: nil
              }} = Electric.Phoenix.shape_from_params(conn)

      conn = conn(:get, "/my/path", %{"where" => "true"})

      assert {:error, _} = Electric.Phoenix.shape_from_params(conn)

      conn =
        conn(:get, "/my/path", %{"table" => "items", "columns" => nil})

      assert {:ok, %ShapeDefinition{table: "items", columns: nil}} =
               Electric.Phoenix.shape_from_params(conn)
    end

    test "accepts a parameter map" do
      assert {:ok, %ShapeDefinition{table: "items"}} =
               Electric.Phoenix.shape_from_params(%{
                 "table" => "items",
                 "columns" => nil,
                 "where" => nil
               })

      assert {:error, _} = Electric.Phoenix.shape_from_params(%{})

      assert {:ok, %ShapeDefinition{table: "items"}} =
               Electric.Phoenix.shape_from_params(%{},
                 table: "items"
               )
    end

    test "allows for overriding specific attributes" do
      conn =
        conn(:get, "/my/path", %{
          "table" => "ignored",
          "namespace" => "ignored_as_well",
          "columns" => "ignored,also",
          "where" => "something = 'open'"
        })

      assert {:ok,
              %ShapeDefinition{
                table: "items",
                namespace: "my_app",
                where: "something = 'open'",
                columns: ["id", "name", "value"]
              }} =
               Electric.Phoenix.shape_from_params(conn,
                 table: "items",
                 namespace: "my_app",
                 columns: ["id", "name", "value"]
               )

      conn = conn(:get, "/my/path", %{"where" => "something = 'open'"})

      assert {:ok,
              %ShapeDefinition{
                table: "items",
                namespace: "my_app",
                where: "something = 'open'",
                columns: ["id", "name", "value"]
              }} =
               Electric.Phoenix.shape_from_params(conn,
                 table: "items",
                 namespace: "my_app",
                 columns: ["id", "name", "value"]
               )
    end
  end
end
