defmodule FedecksServer.BinaryCodec do
  @moduledoc false
  _doc = """
  Provides:-
  - A thin wrapper over `:erlang.binary_to_term/1` and `:erlang.term_to_binary/1`. The latter
  to add some error handling and ensure only safe decoding; the former is included for symmetry.
  - Additional support for encoding / decoding binary terms to base 64
  """

  @doc """
  Wrapper for `:erlang.term_to_binary/1`
  """
  @spec encode(term()) :: binary
  def encode(term), do: :erlang.term_to_binary(term)

  @doc """
  Wrapper for `:erlang.binary_to_term/2`. Will not decode and unsafe binary (ie on which
  will create a new atom). Instead of raising an argument error, invalid or unsafe binaries
  will return `:error`, otherwise an `:ok` tuple is returned
  """
  @spec decode(binary()) :: :error | {:ok, term()}
  def decode(<<131>> <> _ = bin) do
    {:ok, Plug.Crypto.non_executable_binary_to_term(bin, [:safe])}
  rescue
    ArgumentError ->
      :error
  end

  def decode(_), do: :error

  @doc """
  Encodes the term as a binary, then further encodes in base 64 for transmission where
  pure binary would not work, eg in HTTP headers
  """
  @spec encode_base64(term()) :: String.t()
  def encode_base64(term) do
    term |> encode() |> Base.encode64()
  end

  @doc """
  Decodes the base64 encoded binary term. Returns an ok tuple, or
  a different error depending on whether the issue is with base64 or the binary
  term part.
  """
  @spec decode_base64(String.t()) :: {:error, :invalid_binary_term | :not_base64} | {:ok, term()}
  def decode_base64(encoded) do
    with {:b64, {:ok, bin}} <- {:b64, Base.decode64(encoded)},
         {:erl, {:ok, term}} <- {:erl, decode(bin)} do
      {:ok, term}
    else
      {:b64, :error} -> {:error, :not_base64}
      {:erl, :error} -> {:error, :invalid_binary_term}
    end
  end
end
