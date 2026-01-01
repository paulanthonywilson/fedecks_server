defmodule FedecksServer.BinaryCodecTest do
  use ExUnit.Case
  alias FedecksServer.BinaryCodec

  test "encodes and decodes a term as a binary" do
    assert bin = BinaryCodec.encode(:hello_matey)
    assert {:ok, :hello_matey} == BinaryCodec.decode(bin)
  end

  test "returns an error if invalid binary is decoded" do
    assert :error == BinaryCodec.decode("hello matey")
    assert :error == BinaryCodec.decode(<<131>> <> "still nope")
  end

  test "will not decode an unsafe binary" do
    assert :error == BinaryCodec.decode(BadBinary.unsafe())
  end

  test "encodes a term to a base64 encoded binary" do
    assert b64_encoded = BinaryCodec.encode_base64(:hello_matey)
    assert {:ok, encoded} = Base.decode64(b64_encoded)

    assert {:ok, :hello_matey} = BinaryCodec.decode(encoded)
  end

  test "decodes a base64 encoded binary to a term" do
    b64_encoded = :hello_matey |> BinaryCodec.encode() |> Base.encode64()

    assert {:ok, :hello_matey} = BinaryCodec.decode_base64(b64_encoded)
  end

  test "error on invalid base 64" do
    assert {:error, :not_base64} == BinaryCodec.decode_base64("hello matey")
  end

  test "error on base64 encoded to something invalid" do
    bad64 = Base.encode64("lolnope")
    assert {:error, :invalid_binary_term} == BinaryCodec.decode_base64(bad64)
  end

  test "will not decode an encoded function" do
    encoded = :erlang.term_to_binary(fn -> IO.puts("hello") end)

    assert :error == BinaryCodec.decode(encoded)
  end
end
