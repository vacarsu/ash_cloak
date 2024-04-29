defmodule AshCloakTest do
  use ExUnit.Case
  require Ash.Query
  doctest AshCloak

  defp decode(value) do
    "encrypted " <> value = Base.decode64!(value)
    :erlang.binary_to_term(value)
  end

  test "it encrypts and hashes the input values" do
    encrypted =
      AshCloak.Test.Resource
      |> Ash.Changeset.for_create(:create, %{
        not_encrypted: "plain",
        hashed: "test",
        encrypted: 12,
        encrypted_always_loaded: %{hello: :world}
      })
      |> Ash.Changeset.set_context(%{foo: :bar})
      |> Ash.create!()

    # encrypted value is stored
    assert decode(encrypted.encrypted_encrypted) == 12

    # complex values are encrypted
    assert decode(encrypted.encrypted_encrypted_always_loaded) == %{hello: :world}

    # values are not loaded unless you request them
    assert %Ash.NotLoaded{} = encrypted.encrypted

    assert "test" != encrypted.hashed

    # values that are requested are loaded by default
    assert encrypted.encrypted_always_loaded == %{hello: :world}

    # plain attribtues are not affected
    assert encrypted.not_encrypted == "plain"

    # on_decrypt is notified
    assert_received {:decrypting, AshCloak.Test.Resource, [_], :encrypted_always_loaded, %{}}

    # only for fields that are being decrypted
    refute_received {:decrypting, _, _, _, _}
  end

  test "hashed values can be filtered on" do
    created_resource =
      AshCloak.Test.Resource
      |> Ash.Changeset.for_create(:create, %{
        not_encrypted: "plain",
        hashed: "test",
        encrypted: 12,
        encrypted_always_loaded: %{hello: :world}
      })
      |> Ash.Changeset.set_context(%{foo: :bar})
      |> Ash.create!()

    eq_filtered = Ash.read_one!(Ash.Query.filter(AshCloak.Test.Resource, hashed == "test"))

    not_eq_filtered =
      Ash.read_one!(Ash.Query.filter(AshCloak.Test.Resource, hashed != "not the value"))

    incorrect_filtered =
      Ash.read_one!(Ash.Query.filter(AshCloak.Test.Resource, hashed == "not the value"))

    assert created_resource.id == eq_filtered.id

    assert created_resource.id == not_eq_filtered.id

    assert is_nil(incorrect_filtered)
  end
end
