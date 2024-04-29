defmodule AshCloak.Crypto do
  @moduledoc false

  def hmac(value) do
    config = config()
    :crypto.mac(:hmac, config[:algorithm], config[:secret], value)
  end

  defp config do
    Application.get_env(:ash_cloak, :hmac, [])
    |> validate_config()
  end

  defp validate_config(config) do
    if config[:algorithm] && config[:secret] do
      config
    else
      {:error, "Missing HMAC configuration"}
    end
  end
end
