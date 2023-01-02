defmodule BadBinaryTest do
  use ExUnit.Case

  test "the unsafe binary is unsafe" do
    assert_raise ArgumentError, fn -> :erlang.binary_to_term(BadBinary.unsafe(), [:safe]) end
  end

  test "unsafe_base64 is a base64 encoded version of the unsafe binary" do
    assert {:ok, <<131, 116>> <> _} = Base.decode64(BadBinary.base64_unsafe())
  end
end
