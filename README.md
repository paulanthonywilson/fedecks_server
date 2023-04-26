# Fedecks Server


Provides a websocket for a Phoenix application, for establishing communications with a _Fedecks Client_, probably running on a Nerves Device.

## Installation

Add to deps

```elixir

{:fedecks_server, "~> 0.1"}
```

## Using

### Step 1 - Implement a handler

Implement a `FedecksServer.FedecksHandler` to handle connecting and upstream messages. 

eg
```elixir
defmodule MyAppWeb.MyFedecksHandler do
  @behaviour FedecksHandler

  @impl FedecksHandler
  def authenticate(%{"username" => username, 
                    "password" => password, 
                    "fedecks-device-id" => device_id}) do
    MyApp.MyAuth.device_auth(username, password, device_id)
  end

  def authenticate?(_), do: false

  @impl FedecksHandler
  def otp_app, do: :my_app
end
```

Other optional callbacks you can implement include

* `c:FedecksServer.FedecksHandler.handle_in/2` for handling incoming messages as Erlang terms
* `c:FedecksServer.FedecksHandler.handle_raw_in/2` for handling incoming raw binary messsages
* `c:FedecksServer.FedecksHandler.connection_established/1` - this will be called  every time a connection is established with a client. You can use this for things like tracking with [Phoenix.Presence](https://hexdocs.pm/phoenix/Phoenix.Presence.html) or subscribing to a Pub Sub topic with your device id, to allow messages to be sent to your device.
* `c:FedecksServer.FedecksHandler.handle_info/2` - handle internal messages sent to your socket's process inbox. If you have subscribed to a Pub Sub topic  with your device id, then this is how you would initiate sending messages to your device.
* `c:FedecksServer.FedecksHandler.socket_error/3` - any errors that have happened, such as receiving an invalid message or authentication failures, would be reported here.

### Step 2 - Add configuration

In your config you must add configuration for your handler. eg

```elixir
import Config

config :my_app, MyAppWeb.MyFedecksHandler,
  salt: System.fetch_env!("FEDECKS_SALT"),
  secret: System.fetch_env!("FEDECKS_SECRET")

```

The salt and secret are used to encode the authentication token that is used for restablishing connections without logging in. You can generate them, for instance, with `mix phx.gen.secret`.

Additional optional configuration options are 
* `token_refresh_millis`: the number of milliseconds between a refreshed token being sent to the client. Defaults to 3 hours.
* `token_expiry_secs`: the number of seconds after which a token will expire. Currently set to 4 weeks, which is arguably over long.


### Step 3 - Add to the endpoint

Add the endpoint with the macro `FedecksServer.Socket.fedecks_socket/2`. Eg

```elixir
defmodule MyAppWeb.Endpoint
  use Phoenix.Endpoint, otp_app: :my_app

  import FedecksServer.Socket, only: [fedecks_socket: 1]

  fedecks_socket(MyApp.SocketHandler)
end

```

The socket path defaults to "fedecks" but can be optionally provided to the `FedecksServer.Socket.fedecks_socket/2`. Note that the actual path will have "/websocket" appended as [Phoenix.Socket.Transport](https://hexdocs.pm/phoenix/Phoenix.Socket.Transport.html) also supports long polling and needs to know which the client wants: the default path is actually "fedecks/websocket". 

### Step 4 - Implement ~~the rest of the owl~~ the client side

Use [Fedecks Client](https://hexdocs.pm/fedecks_client/) on your Nerves device to communicate with the server.


