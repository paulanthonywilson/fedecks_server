defmodule FedecksServer.SocketTest do
  use ExUnit.Case
  alias FedecksServer.{Socket, FedecksHandler}

  defmodule FullHandler do
    @behaviour FedecksHandler

    @impl FedecksHandler
    def handle_incoming(device_id, {:text, "no reply needed"}) do
      send(self(), {device_id, :noreply_message})
      :ok
    end

    def handle_incoming(device_id, {:text, "talk to me"}) do
      {:reply, {:text, "#{device_id} wat?"}}
    end

    def handle_incoming(device_id, {:text, "stop!"}) do
      {:stop, "#{device_id} asked to stop"}
    end

    @impl FedecksHandler
    def handle_info(device_id, :hello_matey) do
      {:push, {:text, "#{device_id}, hello matey boy"}}
    end

    @impl FedecksHandler
    def connection_established(device_id) do
      send(self(), {:FullHandler, :connected, device_id})
    end

    @impl FedecksHandler
    def authenticate?(%{
          "username" => "marvin",
          "password" => "paranoid-android"
        }),
        do: true

    def authenticate?(_), do: false

    @impl FedecksHandler
    def otp_app, do: :fedecks_server
  end

  defmodule BareHandler do
    @behaviour FedecksHandler

    @impl FedecksHandler
    def authenticate?(_), do: false

    @impl FedecksHandler
    def otp_app, do: :fedecks_server
  end

  describe "connecting with authorisation" do
    test "when valid returns the device_id" do
      assert {:ok, %Socket{device_id: "nerves-543x", handler: FullHandler}} =
               %{
                 "username" => "marvin",
                 "password" => "paranoid-android",
                 "fedecks-device-id" => "nerves-543x"
               }
               |> conn_with_auth_headers(FullHandler)
               |> Socket.connect()
    end

    test "when incorrect, does not connect" do
      assert :error ==
               %{
                 "username" => "marvin@gpp.sirius",
                 "password" => "plastic-pal",
                 "fedecks-device-id" => "nerves-543x"
               }
               |> conn_with_auth_headers(FullHandler)
               |> Socket.connect()
    end

    test "fails if device_id missing" do
      assert :error ==
               %{"username" => "marvin", "password" => "paranoid-android"}
               |> conn_with_auth_headers(FullHandler)
               |> Socket.connect()
    end
  end

  describe "reconnect with token" do
    test "from refresh enables connection" do
      state = %Socket{device_id: "nerves-987x", handler: FullHandler}

      assert {:push, {:binary, msg}, ^state} = Socket.handle_info(:refresh_token, state)

      assert {'token', token} = :erlang.binary_to_term(msg)

      assert {:ok, ^state} =
               %{"fedecks-token" => token, "fedecks-device-id" => "nerves-987x"}
               |> conn_with_auth_headers(FullHandler)
               |> Socket.connect()
    end

    test "does not reconnect if token is invalid" do
      assert :error ==
               %{"fedecks-token" => "hi", "fedecks-device-id" => "nerves-987x"}
               |> conn_with_auth_headers(FullHandler)
               |> Socket.connect()
    end

    test "does not reconnect if device_id embedded in token does not match that passed as a parameter" do
      {:push, {_, msg}, _} =
        Socket.handle_info(:refresh_token, %Socket{device_id: "nerves-987x", handler: FullHandler})

      {'token', token} = :erlang.binary_to_term(msg)

      assert :error =
               %{"fedecks-token" => token, "fedecks-device-id" => "sciatica-987x"}
               |> conn_with_auth_headers(FullHandler)
               |> Socket.connect()
    end
  end

  describe "fails when fedecks auth header is invalid because" do
    test "it is missing" do
      assert :error ==
               Socket.connect(conn(FullHandler, []))
    end

    test "it is not base 64 encoded" do
      assert :error ==
               Socket.connect(conn(FullHandler, [{"x-fedecks-auth", 1}]))
    end

    test "it does not encode to a binary term" do
      assert :error ==
               Socket.connect(conn(FullHandler, [{"x-fedecks-auth", Base.encode64("nope")}]))
    end

    test "it does not encode to a map" do
      val = "hello matey" |> :erlang.term_to_binary() |> Base.encode64()
      assert :error == Socket.connect(conn(FullHandler, [{"x-fedecks-auth", val}]))
    end

    test "it encodes an unsafe term" do
      # Base 64 binary term for
      # iex(28)> h
      # %{
      #   "fedecks-device-id" => "nerves-543x",
      #   "other" => :not_existing_atom,
      #   "password" => "paranoid-android",
      #   "username" => "marvin"
      # }
      val =
        "g3QAAAAEbQAAABFmZWRlY2tzLWRldmljZS1pZG0AAAALbmVydmVzLTU0M3htAAAABW90aGVyZAARbm90X2V4aXN0aW5nX2F0b21tAAAACHBhc3N3b3JkbQAAABBwYXJhbm9pZC1hbmRyb2lkbQAAAAh1c2VybmFtZW0AAAAGbWFydmlu"

      assert :error == Socket.connect(conn(FullHandler, [{"x-fedecks-auth", val}]))
    end

    test "headers over 1k (ish) rejected" do
      device_id = String.pad_leading("123b", 1_000, "0")

      assert :error ==
               %{
                 "username" => "marvin",
                 "password" => "paranoid-android",
                 "fedecks-device-id" => device_id
               }
               |> conn_with_auth_headers(FullHandler)
               |> Socket.connect()
    end
  end

  test "refreshing a token schedules a new refresh" do
    {:push, _, _} = Socket.handle_info(:refresh_token, state(FullHandler))

    # FullHandler refresh is a milliseconds, so it will turn up
    assert_receive :refresh_token

    # BareHandler refresh is the default, which is hours, so will not turn up
    {:push, _, _} = Socket.handle_info(:refresh_token, state(BareHandler))
    refute_receive :refresh_token
  end

  describe "init" do
    test "passes on the state" do
      assert {:ok, state(FullHandler)} ==
               Socket.init(state(FullHandler))
    end

    test "initiates sending a new connection token" do
      {:ok, _} = Socket.init(state(FullHandler))
      assert_received :refresh_token
    end

    test "connection established callback is, well, called" do
      {:ok, _} = Socket.init(state(FullHandler, "nerves-123b"))
      assert_received {:FullHandler, :connected, "nerves-123b"}
    end

    test "connection established callback is optional" do
      {:ok, _} = Socket.init(state(BareHandler, "nerves-123b"))
      refute_received {_, :connected, _}
    end
  end

  describe "incoming messages" do
    test "by default ignores messages" do
      assert {:ok, %{device_id: "y"}} =
               Socket.handle_in(
                 {:binary, :erlang.term_to_binary("hello matey")},
                 state(BareHandler, "y")
               )
    end

    test "calls `handle_incoming_message` if provided" do
      assert {:ok, %{device_id: "xyz"}} =
               Socket.handle_in({:text, "no reply needed"}, state(FullHandler, "xyz"))

      assert_received {"xyz", :noreply_message}
    end

    test "can also reply" do
      assert {:reply, :ok, {:text, "xyz wat?"}, %{device_id: "xyz"}} =
               Socket.handle_in({:text, "talk to me"}, state(FullHandler, "xyz"))
    end

    test "can terminate the websocket" do
      assert {:stop, "123 asked to stop", %{device_id: "123"}} =
               Socket.handle_in({:text, "stop!"}, state(FullHandler, "123"))
    end
  end

  describe "handling info messages" do
    test "passes on messages to the the callback" do
      assert {:push, {:text, "has-a-nerve, hello matey boy"}, %{device_id: "has-a-nerve"}} =
               Socket.handle_info(:hello_matey, state(FullHandler, "has-a-nerve"))
    end

    test "defaults to no op" do
      assert {:ok, %{device_id: "bobby"}} = Socket.handle_info(:ola, state(BareHandler, "bobby"))
    end
  end

  describe "when configuring with `fedecks_socket` in the endpoint" do
    defmodule PretendEndpoint do
      require Socket
      require Phoenix.Endpoint
      Module.register_attribute(__MODULE__, :phoenix_sockets, accumulate: true)

      Socket.fedecks_socket(FullHandler)
      Socket.fedecks_socket("/custom", BareHandler)
      def phoenix_sockets, do: @phoenix_sockets
    end

    test "with no path, sets the default Fedecks path to the socket" do
      assert [
               _,
               {"/fedecks", Socket,
                [
                  websocket: [connect_info: [:x_headers, fedecks_handler: FullHandler]],
                  longpoll: false
                ]}
             ] = PretendEndpoint.phoenix_sockets()
    end

    test "can customise the socket path" do
      assert [
               {"/custom", Socket,
                [
                  websocket: [connect_info: [:x_headers, fedecks_handler: BareHandler]],
                  longpoll: false
                ]},
               _
             ] = PretendEndpoint.phoenix_sockets()
    end
  end

  defp conn_with_auth_headers(headers, handler) do
    auth = headers |> :erlang.term_to_binary() |> Base.encode64()

    conn(handler, [{"x-fedecks-auth", auth}])
  end

  defp conn(handler, x_headers) do
    %{connect_info: %{x_headers: x_headers, fedecks_handler: handler}}
  end

  defp state(handler, device_id \\ "some-device-id") do
    %Socket{handler: handler, device_id: device_id}
  end
end
