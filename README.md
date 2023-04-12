# Fedecks Server


Provides a websocket for a Phoenix application, for establishing communications with a _Fedecks Client_, probably running on a Nerves Device.

## Usage

Add to deps

```elixir
{:fedecks_server, "~> 0.1"}
```

Implement a `FedecksServer.FedecksHandler` to handle connecting and upstream messages. See module for callbacks.

Add the endpoint with `FedecksServer.Socket.fedecks_socket/2`. Eg

```elixir
defmodule MyApp.Endpoint
  use Phoenix.Endpoint, otp_app: :my_app

  import FedecksServer.Socket, only: [fedecks_socket: 1]

  fedecks_socket(MyApp.SocketHandler)
end

```


Messages are received from the _Fedecks Client_ primarily as Erlang terms and handled by the `c:FedecksServer.FedecksHandler.handle_in/2` callback. (Note that the terms are safe decoded, so it is best
to avoid atoms in the messages).

The FedecksClient is not yet on Hex, but can be found in Github [here](https://github.com/paulanthonywilson/fedecks_client).

