defmodule BadBinary do
  @moduledoc false

  @base64_unsafe "g3QAAAAEbQAAABFmZWRlY2tzLWRldmljZS1pZG0AAAALbmVydmVzLTU0M3htAAAABW90aGVyZAARbm90X2V4aXN0aW5nX2F0b21tAAAACHBhc3N3b3JkbQAAABBwYXJhbm9pZC1hbmRyb2lkbQAAAAh1c2VybmFtZW0AAAAGbWFydmlu"
  @unsafe Base.decode64!(@base64_unsafe)

  @doc """
  Base 64 binary term containing an atom that does not exist in this project so
  will be unsafe to decode.

  It is actually
  ```
  %{
    "fedecks-device-id" => "nerves-543x",
    "other" => :not_existing_atom,
    "password" => "paranoid-android",
    "username" => "marvin"
  }
  ```
  """
  def unsafe, do: @unsafe

  @doc """
  Base 64 encoded version of `unsafe/0`
  """
  def base64_unsafe, do: @base64_unsafe
end
