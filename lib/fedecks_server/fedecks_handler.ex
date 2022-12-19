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
  Use the fedecks information supplied at login authenticate the user? Only called if there
  is no `fedecks-token` supplied, so is likely to be an initial registration, a re-registration
  (perhaps to associate the device with a new user), or a re-registration due to an expired token which
  can occur if a device has not connected for a few days.

  Will be a map with string keys. The key "fedecks-device-id" will present which you can use
  to associate the device with a user (should you wish).

  """
  @callback authenticate?(map()) :: boolean()

  @doc """
  Can handle incoming text or binary messages.
  - For no reply, return ':ok'
  - To reply, return '{:reply, message}` where opcode is `:text` or `binary`
  - To terminate the connection, return `{:stop, reason}`
  """
  @callback handle_incoming(device_id :: String.t(), {opcode(), message :: binary()}) ::
              :ok | {:reply, {opcode(), message :: binary}} | {:stop, term()}

  @doc """
  Called when a new connection is established, with the Fedecks box device_id.
  """
  @callback connection_established(device_id :: String.t()) :: any()

  @doc """
  The name of the OTP app used to get the configuration details.
  """
  @callback otp_app :: atom()

  @doc """
  Called when the connection process has received a message (to its process mailbox). Internal Fedecks messages, ie `:refresh_token` have been filtered
  out. The info message and a map of user data is sent. Return

  * `:ok` for now action
  * `{:push, {:opcode, message}}`  to send a message down the socket
  * `{:stop, reason}` to

  """
  @callback handle_info(device_id :: String.t(), {opcode(), message :: binary()}) ::
              :ok | {:push, {opcode(), message :: binary()}} | {:stop, reason :: term}

  @type error_type :: :invalid_auth_header | :authentication_failed
  @doc """
  Optionally called when an error occurs, such as receiving an invalid message, authentication failure, or other

  """
  @callback socket_error(device_id :: String.t(), error_type(), info :: term()) :: any()

  @optional_callbacks handle_incoming: 2,
                      connection_established: 1,
                      handle_info: 2,
                      socket_error: 3
end
