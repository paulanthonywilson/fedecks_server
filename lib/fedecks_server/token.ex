defmodule FedecksServer.Token do
  @moduledoc false
  _doc = """
  Token used by clients that have already authorised.
  """

  alias Plug.Crypto

  @doc """
  Convert the identifier to a token, that will expire in `expiry_secs` seconds, using the
  secret / salt tuple
  """
  @spec to_token(
          identifier :: term(),
          expiry_secs :: pos_integer(),
          {secret :: binary, salst :: binary}
        ) :: binary()
  def to_token(identifier, expiry_secs, {secret, salt}) do
    Crypto.encrypt(secret, salt, identifier, max_age: expiry_secs)
  end

  @doc """
  Convert the token previously generated with `to_token/1` back to its identifier (if valid)
  """
  @spec from_token(token :: binary(), {secret :: binary, salt :: binary}) ::
          {:error, :expired | :invalid | :missing} | {:ok, identifier :: term()}
  def from_token(token, {secret, salt}) do
    Crypto.decrypt(secret, salt, token)
  end
end
