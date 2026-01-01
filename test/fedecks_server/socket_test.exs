defmodule FedecksServer.SocketTest do
  use ExUnit.Case
  alias FedecksServer.{Socket, FedecksHandler}

  defmodule FullHandler do
    @behaviour FedecksHandler

    @impl FedecksHandler

    def handle_in(device_id, %{"talk to" => "me"}) do
      {:reply, "#{device_id} term wat?"}
    end

    def handle_in(device_id, %{"Please" => "stop"}) do
      {:stop, "#{device_id} asked to stop"}
    end

    def handle_in(device_id, _) do
      send(self(), {device_id, :noreply_term_message})
      :ok
    end

    @impl FedecksHandler
    def handle_raw_in(device_id, "talk to me") do
      {:reply, "#{device_id} raw wat?"}
    end

    def handle_raw_in(device_id, "Please stop.") do
      {:stop, "#{device_id} asked to stop"}
    end

    def handle_raw_in(device_id, _) do
      send(self(), {device_id, :noreply_raw_message})
      :ok
    end

    @impl FedecksHandler
    def handle_info(device_id, :hello_matey) do
      {:push, "#{device_id}, hello matey boy"}
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

    @impl FedecksHandler
    def socket_error(device_id, error_type, info) do
      send(self(), {:socket_error, {device_id, error_type, info}})
    end
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

      assert_received {:socket_error, {"nerves-543x", :authentication_failed, ""}}
    end

    test "fails if device_id missing" do
      assert :error ==
               %{"username" => "marvin", "password" => "paranoid-android"}
               |> conn_with_auth_headers(FullHandler)
               |> Socket.connect()

      assert_received {:socket_error, {nil, :invalid_auth_header, "no device id"}}
    end
  end

  test "socket error callback is optional" do
    :error =
      %{"username" => "marvin", "password" => "paranoid-android"}
      |> conn_with_auth_headers(BareHandler)
      |> Socket.connect()
  end

  describe "reconnect with token" do
    test "from refresh enables connection" do
      state = %Socket{device_id: "nerves-987x", handler: FullHandler}

      assert {:push, {:binary, msg}, ^state} = Socket.handle_info(:refresh_token, state)

      assert {~c"token", token} = :erlang.binary_to_term(msg)

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

      assert_received {:socket_error, {"nerves-987x", :invalid_token, ""}}
    end

    test "does not reconnect if device_id embedded in token does not match that passed as a parameter" do
      {:push, {_, msg}, _} =
        Socket.handle_info(:refresh_token, %Socket{device_id: "nerves-987x", handler: FullHandler})

      {~c"token", token} = :erlang.binary_to_term(msg)

      assert :error =
               %{"fedecks-token" => token, "fedecks-device-id" => "sciatica-987"}
               |> conn_with_auth_headers(FullHandler)
               |> Socket.connect()

      assert_received {:socket_error,
                       {"sciatica-987", :invalid_token,
                        "wrong device id in token, 'nerves-987x'"}}
    end
  end

  describe "fails when fedecks auth header is invalid because" do
    test "it is missing" do
      assert :error ==
               Socket.connect(conn(FullHandler, []))

      assert_received {:socket_error, {nil, :invalid_auth_header, "missing"}}
    end

    test "it is not base 64 encoded" do
      assert :error ==
               Socket.connect(conn(FullHandler, [{"x-fedecks-auth", "1"}]))

      assert_received {:socket_error, {nil, :invalid_auth_header, "not base64"}}
    end

    test "it does not encode to a binary term" do
      assert :error ==
               Socket.connect(conn(FullHandler, [{"x-fedecks-auth", Base.encode64("nope")}]))

      assert_received {:socket_error, {nil, :invalid_auth_header, info}}
      assert info =~ "invalid or unsafe"
    end

    test "it does not encode to a map" do
      val = "hello matey" |> :erlang.term_to_binary() |> Base.encode64()
      assert :error == Socket.connect(conn(FullHandler, [{"x-fedecks-auth", val}]))
      assert_received {:socket_error, {nil, :invalid_auth_header, "not a map"}}
    end

    test "it will not decode an unsafe term" do
      assert :error ==
               Socket.connect(conn(FullHandler, [{"x-fedecks-auth", BadBinary.base64_unsafe()}]))

      assert_received {:socket_error, {nil, :invalid_auth_header, info}}
      assert info =~ "invalid or unsafe"
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

      assert_received {:socket_error, {nil, :invalid_auth_header, "too long"}}
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

    test "connection established callback is, well, called" do
      {:ok, _} = Socket.init(state(FullHandler, "nerves-123b"))
      assert_received {:FullHandler, :connected, "nerves-123b"}
    end

    test "connection established callback is optional" do
      {:ok, _} = Socket.init(state(BareHandler, "nerves-123b"))
      refute_received {_, :connected, _}
    end

    test "schedules a token refresh" do
      {:ok, _} = Socket.init(state(FullHandler, "nerves-123b"))
      # FullHandler refresh is a milliseconds, so it will turn up
      assert_receive :refresh_token

      # BareHandler refresh is the default, which is hours, so will not turn up
      {:ok, _} = Socket.init(state(BareHandler, "nerves-456"))
      refute_receive :refresh_token
    end
  end

  test "requesting a token" do
    assert {:push, {:binary, token}, %{device_id: "y"}} =
             Socket.handle_in(
               {:erlang.term_to_binary(~c"token_please"), opcode: :binary},
               state(BareHandler, "y")
             )

    assert {~c"token", _} = :erlang.binary_to_term(token)
  end

  describe "incoming binary term messages" do
    test "ignored if handle_in is not implemented" do
      assert {:ok, %{device_id: "y"}} =
               Socket.handle_in(
                 {:binary, :erlang.term_to_binary("hello matey")},
                 state(BareHandler, "y")
               )
    end

    test "handled, if handle_in is implemented" do
      assert {:ok, %{device_id: "123"}} =
               Socket.handle_in(
                 {:binary, :erlang.term_to_binary("no reply needed")},
                 state(FullHandler, "123")
               )
    end

    test "can also reply" do
      assert {:reply, :ok, {:binary, reply}, %{device_id: "xyz"}} =
               Socket.handle_in(
                 {:erlang.term_to_binary(%{"talk to" => "me"}), opcode: :binary},
                 state(FullHandler, "xyz")
               )

      assert "xyz term wat?" == :erlang.binary_to_term(reply)
    end

    test "can terminate the websocket" do
      assert {:stop, "123 asked to stop", %{device_id: "123"}} =
               Socket.handle_in(
                 {:erlang.term_to_binary(%{"Please" => "stop"}), opcode: :binary},
                 state(FullHandler, "123")
               )
    end
  end

  describe "incoming binary messages that are not erlang terms" do
    test "ignored if handle_raw_in is not implemented" do
      assert {:ok, %{device_id: "y"}} =
               Socket.handle_in(
                 {:binary, "hello matey"},
                 state(BareHandler, "y")
               )
    end

    test "messages handled with `handle_raw_in`" do
      assert {:ok, %{device_id: "xyz"}} =
               Socket.handle_in(
                 {"no reply", opcode: :binary},
                 state(FullHandler, "xyz")
               )

      assert_received {"xyz", :noreply_raw_message}
    end

    test "can also reply" do
      assert {:reply, :ok, {:binary, reply}, %{device_id: "xyz"}} =
               Socket.handle_in(
                 {"talk to me", opcode: :binary},
                 state(FullHandler, "xyz")
               )

      assert "xyz raw wat?" == :erlang.binary_to_term(reply)
    end

    test "can terminate the websocket" do
      assert {:stop, "123 asked to stop", %{device_id: "123"}} =
               Socket.handle_in(
                 {"Please stop.", opcode: :binary},
                 state(FullHandler, "123")
               )
    end

    test "binary messages beginning with <<131>> which are not valid terms are handled with `handle_raw_in`" do
      assert {:ok, %{device_id: "xyz"}} =
               Socket.handle_in(
                 {<<131>> <> "lol", opcode: :binary},
                 state(FullHandler, "xyz")
               )

      assert_received {"xyz", :noreply_raw_message}
    end

    test "unsafe binary messages are handled with `handle_raw_in`" do
      assert {:ok, %{device_id: "xyz"}} =
               Socket.handle_in(
                 {BadBinary.unsafe(), opcode: :binary},
                 state(FullHandler, "xyz")
               )

      assert_received {"xyz", :noreply_raw_message}
    end
  end

  test "incoming test messages are always ignored" do
    assert {:ok, %{device_id: "y"}} =
             Socket.handle_in(
               {:text, "hello matey"},
               state(BareHandler, "y")
             )
  end

  describe "handling info messages" do
    test "passes on messages to the the callback" do
      assert {:push, {:binary, <<131>> <> _ = message}, %{device_id: "has-a-nerve"}} =
               Socket.handle_info(:hello_matey, state(FullHandler, "has-a-nerve"))

      assert "has-a-nerve, hello matey boy" = :erlang.binary_to_term(message)
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
