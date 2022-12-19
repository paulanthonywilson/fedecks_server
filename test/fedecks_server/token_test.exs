defmodule FedecksServer.TokenTest do
  use ExUnit.Case
  alias FedecksServer.Token

  @secret "C28zaqpZ0sN6tTF17TIrrOZa53Otp4Q9A+yKagZNJFcn2HB3REk+e+UPWe1hG5Ut"

  @salt "61A+uph5tSr0axj+IpQk8K8i6Nz6qMV5GUoBY0Ckm/z5645p1BK3pw+6BzlFG6V5"
  @secret_salt {@secret, @salt}

  test "from and to token" do
    token = Token.to_token("an identifier", 60, @secret_salt)
    assert {:ok, "an identifier"} = Token.from_token(token, @secret_salt)
  end

  test "expired token" do
    expired_token =
      "QTEyOEdDTQ.um9qPeO_8hC5rfrR6NQC4VuwcdxXPBzdrxAlSk_mzev7MJUzVyMN-wg-yac.kgTssPMNXgP38TX0.pi24usC_fTwuMGGBQFhbOMtDT_6CyjEJZ_MjvmGWBEE.BtS7GbPTr_GvUpDm5TkyFA"

    assert {:error, :expired} == Token.from_token(expired_token, @secret_salt)
  end

  test "bad secrets" do
    token = Token.to_token("an identifier", 60, @secret_salt)
    assert {:error, :invalid} == Token.from_token(token, {@secret, @secret})
    assert {:error, :invalid} == Token.from_token(token, {@salt, @salt})
  end
end
