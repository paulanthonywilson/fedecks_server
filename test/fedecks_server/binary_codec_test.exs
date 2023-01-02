defmodule FedecksServer.BinaryCodecTest do
  use ExUnit.Case
  alias FedecksServer.BinaryCodec
  @base64_encoded_atom_header Base.encode64(<<131, 100, 0>>)

  test "encodes and decodes a term as a binary" do
    assert <<131, 100>> <> _ = bin = BinaryCodec.encode(:hello_matey)
    assert {:ok, :hello_matey} == BinaryCodec.decode(bin)
  end

  test "returns an error if invalid binary is decoded" do
    assert :error == BinaryCodec.decode("hello matey")
    assert :error == BinaryCodec.decode(<<131>> <> "still nope")
  end

  test "will not decode an unsafe binary" do
    assert :error == BinaryCodec.decode(BadBinary.unsafe())
  end

  test "encodes and decodes a term to and from a base64 encoded binary" do
    assert @base64_encoded_atom_header <> _ = encoded = BinaryCodec.encode_base64(:hello_matey)
    assert {:ok, :hello_matey} = BinaryCodec.decode_base64(encoded)
  end

  test "error on invalid base 64" do
    assert {:error, :not_base64} == BinaryCodec.decode_base64("hello matey")
  end

  test "error on base64 encoded to something invalid" do
    bad64 = Base.encode64("lolnope")
    assert {:error, :invalid_binary_term} == BinaryCodec.decode_base64(bad64)
  end
end
