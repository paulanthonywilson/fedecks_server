defmodule FedecksServer.ConfigTest do
  use ExUnit.Case
  alias FedecksServer.Config
  alias FedecksServer.SocketTest

  test "reads secrets from config" do
    {secret, salt} = Config.token_secrets({:fedecks_server, SocketTest.FullHandler})
    assert String.ends_with?(secret, "6zq4")
    assert String.ends_with?(salt, "+PP5E")
  end

  test "can override timings" do
    assert 1 == Config.token_refresh_millis({:fedecks_server, SocketTest.FullHandler})
    assert 123_456 == Config.token_expiry_secs({:fedecks_server, SocketTest.FullHandler})
  end

  test "timings have defaults" do
    assert 10_800_000 == Config.token_refresh_millis({:fedecks_server, SocketTest.BareHandler})
    assert 2_419_200 == Config.token_expiry_secs({:fedecks_server, SocketTest.BareHandler})
  end
end
