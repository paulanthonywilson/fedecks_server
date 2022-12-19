defmodule FedecksServer.Socket do
  @moduledoc """
  Sets up a `Phoenix.Socket.Transport` that connects to a Fedecks Websocket client

  Usage:

  tbd

  """
  alias FedecksServer.{Config, Token}
  @behaviour Phoenix.Socket.Transport

  keys = [:device_id, :handler]
  @enforce_keys keys
  defstruct keys

  @type t :: %{device_id: String.t(), handler: handler_module :: atom()}

  @impl Phoenix.Socket.Transport
  def child_spec(_) do
    %{id: Task, start: {Task, :start_link, [fn -> :ok end]}, restart: :transient}
  end

  @impl Phoenix.Socket.Transport
  def connect(%{connect_info: %{x_headers: x_headers, fedecks_handler: handler}}) do
    case List.keyfind(x_headers, "x-fedecks-auth", 0) do
      {_, encoded_auth} ->
        authenticate_encoded(encoded_auth, handler)

      nil ->
        socket_error(handler, nil, :invalid_auth_header, "missing")
        :error
    end
  end

  def connect(_), do: :error

  @impl Phoenix.Socket.Transport
  def terminate(_reason, _state) do
    :ok
  end

  defp authenticate_encoded(encoded_auth, handler) when byte_size(encoded_auth) < 1_024 do
    case Base.decode64(encoded_auth) do
      {:ok, term} ->
        term |> :erlang.binary_to_term([:safe]) |> authenticate_decoded(handler)

      :error ->
        socket_error(handler, nil, :invalid_auth_header, "not base64")
        :error
    end
  rescue
    e in ArgumentError ->
      socket_error(handler, nil, :invalid_auth_header, e.message)
      :error
  end

  defp authenticate_encoded(_, handler) do
    socket_error(handler, nil, :invalid_auth_header, "too long")
    :error
  end

  defp authenticate_decoded(
         %{"fedecks-device-id" => device_id, "fedecks-token" => token},
         handler
       ) do
    case Token.from_token(token, token_secrets(handler)) do
      {:ok, ^device_id} ->
        {:ok, %__MODULE__{device_id: device_id, handler: handler}}

      {:ok, token_device} ->
        socket_error(
          handler,
          device_id,
          :invalid_token,
          "wrong device id in token, '#{token_device}'"
        )

        :error

      _err ->
        socket_error(handler, device_id, :invalid_token, "")
        :error
    end
  end

  defp authenticate_decoded(%{"fedecks-device-id" => device_id} = auth, handler) do
    if apply(handler, :authenticate?, [auth]) do
      {:ok, %__MODULE__{device_id: device_id, handler: handler}}
    else
      socket_error(handler, device_id, :authentication_failed, "")
      :error
    end
  end

  defp authenticate_decoded(%{}, handler) do
    socket_error(handler, nil, :invalid_auth_header, "no device id")
    :error
  end

  defp authenticate_decoded(_, handler) do
    socket_error(handler, nil, :invalid_auth_header, "not a map")
    :error
  end

  @impl Phoenix.Socket.Transport
  def init(state) do
    send(self(), :refresh_token)
    maybe_handle(state, :connection_established, [])
    {:ok, state}
  end

  @impl Phoenix.Socket.Transport
  def handle_info(:refresh_token, %{device_id: device_id, handler: handler} = state) do
    Process.send_after(self(), :refresh_token, token_refresh_millis(handler))
    token = device_id |> Token.to_token(token_expiry_secs(handler), token_secrets(handler))
    msg = :erlang.term_to_binary({'token', token})
    {:push, {:binary, msg}, state}
  end

  def handle_info(message, state) do
    case maybe_handle(state, :handle_info, [message]) do
      {:push, message} -> {:push, message, state}
      {:stop, reason} -> {:stop, reason, state}
      _ -> {:ok, state}
    end
  end

  @impl Phoenix.Socket.Transport
  def handle_in(message, state) do
    case maybe_handle(state, :handle_incoming, [message]) do
      {:reply, message} -> {:reply, :ok, message, state}
      {:stop, reason} -> {:stop, reason, state}
      _ -> {:ok, state}
    end
  end

  defp token_expiry_secs(handler) do
    handler
    |> config_key()
    |> Config.token_expiry_secs()
  end

  defp token_refresh_millis(handler) do
    handler
    |> config_key()
    |> Config.token_refresh_millis()
  end

  defp token_secrets(handler) do
    handler
    |> config_key()
    |> Config.token_secrets()
  end

  defp config_key(handler) do
    {apply(handler, :otp_app, []), handler}
  end

  defp socket_error(handler, device_id, error_type, info) do
    maybe_apply(handler, :socket_error, [device_id, error_type, info])
  end

  defp maybe_handle(%{handler: m, device_id: device_id}, f, a) do
    maybe_apply(m, f, [device_id | a])
  end

  defp maybe_apply(m, f, a) do
    if function_exported?(m, f, length(a)) do
      apply(m, f, a)
    end
  end

  defmacro fedecks_socket(path \\ "/fedecks", mod) do
    quote do
      Phoenix.Endpoint.socket(unquote(path), unquote(__MODULE__),
        websocket: [connect_info: [:x_headers, fedecks_handler: unquote(mod)]],
        longpoll: false
      )
    end
  end
end
