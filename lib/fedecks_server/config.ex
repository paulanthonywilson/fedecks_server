defmodule FedecksServer.Config do
  @moduledoc false
  _doc = """
  Reads configuration associated with a particular Fedecks socket handler.
  """

  @secs_in_4_weeks 60 * 60 * 24 * 7 * 4

  @type config_key :: {otp_app :: atom(), handler_module :: atom()}

  @spec token_secrets(config_key()) :: {String.t(), String.t()}
  def token_secrets(key) do
    {secret(key), salt(key)}
  end

  @spec token_refresh_millis(config_key()) :: pos_integer()
  def token_refresh_millis(key) do
    key
    |> config()
    |> Keyword.get(:token_refresh_millis, :timer.hours(3))
  end

  @spec token_expiry_secs(config_key()) :: pos_integer()
  def token_expiry_secs(key) do
    key
    |> config()
    |> Keyword.get(:token_expiry_secs, @secs_in_4_weeks)
  end

  defp secret(key) do
    key
    |> config()
    |> Keyword.fetch!(:secret)
  end

  defp salt(key) do
    key
    |> config()
    |> Keyword.fetch!(:salt)
  end

  defp config({otp_app, mod}), do: Application.fetch_env!(otp_app, mod)
end
