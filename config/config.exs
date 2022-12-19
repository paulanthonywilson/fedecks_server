import Config

if Mix.env() == :test do
  config :logger, level: :warn

  config :fedecks_server, FedecksServer.SocketTest.FullHandler,
    secret: "ULO1b5eiGSPNcrnAvnIXGy7JhH0WorbLkVq/pT10V/0/Hq7Dw66A5XIbZT0X6zq4",
    salt: "b/BuhKLXOIqYM8sD53XnT51gwiBHmBpv+eM5I6HrvERTleoIq0EHYi76aNo+PP5E",
    token_refresh_millis: 1,
    token_expiry_secs: 123_456

  config :fedecks_server, FedecksServer.SocketTest.BareHandler,
    secret: "ULO1b5eiGSPNcrnAvnIXGy7JhH0WorbLkVq/pT10V/0/Hq7Dw66A5XIbZT0X6zq4",
    salt: "b/BuhKLXOIqYM8sD53XnT51gwiBHmBpv+eM5I6HrvERTleoIq0EHYi76aNo+PP5E"

  config :phoenix, :json_library, Jason
end
