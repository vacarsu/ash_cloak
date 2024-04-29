defmodule AshCloak.Changes.Hash do
  @moduledoc false

  use Ash.Resource.Change
  alias AshCloak.Crypto

  def change(changeset, opts, _context) do
    attribute = opts[:field]

    case Ash.Changeset.fetch_argument(changeset, attribute) do
      {:ok, value} ->
        hashed_value = Crypto.hmac(value)

        changeset
        |> Ash.Changeset.force_change_attribute(attribute, hashed_value)

      :error ->
        changeset
    end
  end
end
