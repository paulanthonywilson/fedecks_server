defmodule FedecksServer.FedecksHandler do
  @moduledoc """
  Behaviour that should be implemented for handling authentication and communcication over a Fedecks
  Websocket.

  Requires a keyword-list configuration value
  keyed by the OTP app name, returned by the `otp_app/0` callback and the  module name, which returns a
  keyword list with the keys:

  * `secret` used to encode and sign an authentication token
  * `salt` also used to encode and sign and authentication token
  * (optional) `token_refresh_millis` - how often the token is refreshed and sent to the client, in
    milliseconds. The default is 3 hours
  * `token_expiry_secs` - how many seconds before a token expires. The default is 4 weeks.

  For example, an handle called `MyApp.MyHandler` with an application name `:my_app` may have the following
  configuration set

  ```elixir
  config :my_app, MyAppHandler,
    secret: "ULO1b5eiGSPNcrnAvnIXGy7JhH0WorbLkVq/pT10V/0/Hq7Dw66A5XIbZT0X6zq4",
    salt: "b/BuhKLXOIqYM8sD53XnT51gwiBHmBpv+eM5I6HrvERTleoIq0EHYi76aNo+PP5E",
    token_refresh_millis: :timer.minutes(30),
    token_expiry_secs: 360
  ```
  """

  @type opcode :: :binary | :text

  @doc """
  Use the fedecks information supplied at login authenticate the user.

  Only called if there is no `fedecks-token` supplied, so is likely to be an initial registration, a re-registration
  (perhaps to associate the device with a new user), or a re-registration due to an expired token which
  can occur if a device has not connected for a few days.

  Will be a map with string keys. The key "fedecks-device-id" will present which you can use
  to associate the device with a user (should you wish).

  """
  @callback authenticate?(map()) :: boolean()

  @doc """
  Optional.

  Handles incoming message, which has been encoded by the Fedecks client as an Erlang binary term that
  is safe to decode. Binary messages which are not safe Erlang terms can be handled by `handle_raw_in/2`. Text
  messages are ignored.

  - For no reply, return ':ok'
  - To reply, return `{:reply, "some message"}`. The message will be coded as an Erlang binary term. As the
  Fedecks client will used safe decoding avoid atoms (or structs) that are not present on the client. It
  is safer to stick to maps, rather than structs, and strings rather than atoms (eg for map keys).
  - To terminate the connection, return `{:stop, reason}`
  """
  @callback handle_in(device_id :: String.t(), message :: term()) ::
              :ok | {:reply, message :: term()} | {:stop, term()}

  @doc """
  Optional.

  Handles incoming messages raw binary messages.

  - For no reply, return `:ok`
  - To reply, return `{:reply, message}`. The message will be sent to the client as a binary.
  - To terminate the connection, return `{:stop, reason}`
  """
  @callback handle_raw_in(device_id :: String.t(), message :: binary()) ::
              :ok | {:reply, message :: term()} | {:stop, term()}

  @doc """
  Optional.

  Called when a new connection is established, with the Fedecks box device_id.
  """
  @callback connection_established(device_id :: String.t()) :: any()

  @doc """
  The name of the OTP app used to get the configuration details.
  """
  @callback otp_app :: atom()

  @doc """
  Optional.

  Called when the connection process has received a message (to its process mailbox). Internal Fedecks messages, ie `:refresh_token` have been filtered
  out. The info message and a map of user data is sent. Return

  * `:ok` for now action
  * `{:push, message}`  to send a message down the socket, as an erlang binary term
  * `{:stop, reason}` to

  """
  @callback handle_info(device_id :: String.t(), message :: term()) ::
              :ok | {:push, message :: term()} | {:stop, reason :: term}

  @type error_type :: :invalid_auth_header | :authentication_failed
  @doc """
  Optionally called when an error occurs, such as receiving an invalid message, authentication failure, or other

  """
  @callback socket_error(device_id :: String.t(), error_type(), info :: term()) :: any()

  @optional_callbacks handle_in: 2,
                      handle_raw_in: 2,
                      connection_established: 1,
                      handle_info: 2,
                      socket_error: 3
end
