defmodule AshCloak.Transformers.SetupHashing do
  @moduledoc false
  use Spark.Dsl.Transformer

  @after_transformers [
    Ash.Resource.Transformers.DefaultAccept,
    Ash.Resource.Transformers.ValidatePrimaryActions
  ]

  # sobelow_skip ["DOS.BinToAtom", "DOS.StringToAtom"]
  def transform(dsl) do
    module = Spark.Dsl.Transformer.get_persisted(dsl, :module)
    hashed_attrs = AshCloak.Info.cloak_hashed_attributes!(dsl)
    encrypted_attrs = AshCloak.Info.cloak_encrypted_attributes!(dsl)
    all = hashed_attrs ++ hashed_attrs

    if Enum.empty?(Enum.uniq(all)) do
      raise Spark.Error.DslError,
        module: module,
        message: "Attributes in hashed and encrypted lists must be unique",
        path: [:cloak, :hashed_attributes]
    end

    transform_hashed_fields(dsl, module, hashed_attrs)
    |> add_preparation()
  end

  defp transform_hashed_fields(dsl, module, attributes) do
    Enum.reduce_while(attributes, {:ok, dsl}, fn attr, {:ok, dsl} ->
      attribute = Ash.Resource.Info.attribute(dsl, attr)

      if !attribute do
        raise Spark.Error.DslError,
          module: module,
          message: "No attribute called #{inspect(attribute)} found",
          path: [:cloak, :hashed_attributes]
      end

      if attribute.primary_key? do
        raise Spark.Error.DslError,
          module: module,
          message: "cannot hash primary key attribute",
          path: [:cloak, :hashed_attributes]
      end

      {:ok, dsl}
      |> build_hashing(attribute)
      |> rewrite_actions(attribute)
      |> case do
        {:ok, dsl} -> {:cont, {:ok, dsl}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp build_hashing({:ok, dsl}, attribute) do
    name = attribute.name

    dsl
    |> Spark.Dsl.Transformer.remove_entity([:attributes], &(&1.name == attribute.name))
    |> Ash.Resource.Builder.add_attribute(name, :binary,
      allow_nil?: attribute.allow_nil?,
      sensitive?: true,
      public?: true,
      description: "Hashed #{name}"
    )
  end

  defp rewrite_actions({:ok, dsl}, attr) do
    dsl
    |> Ash.Resource.Info.actions()
    |> Enum.filter(&(&1.type in [:create, :update, :destroy]))
    |> Enum.reduce_while({:ok, dsl}, fn action, {:ok, dsl} ->
      if attr.name in action.accept do
        new_accept = action.accept -- [attr.name]

        with {:ok, argument} <-
               Ash.Resource.Builder.build_action_argument(attr.name, attr.type,
                 constraints: attr.constraints
               ),
             {:ok, change} <-
               Ash.Resource.Builder.build_action_change({AshCloak.Changes.Hash, field: attr.name}) do
          {:cont,
           {:ok,
            Spark.Dsl.Transformer.replace_entity(
              dsl,
              [:actions],
              %{
                action
                | arguments: [argument | Enum.reject(action.arguments, &(&1.name == attr.name))],
                  changes: [change | action.changes],
                  accept: new_accept
              },
              &(&1.name == action.name)
            )}}
        else
          other ->
            {:halt, other}
        end
      else
        {:cont, {:ok, dsl}}
      end
    end)
  end

  defp rewrite_actions({:error, error}, _), do: {:error, error}

  defp add_preparation({:ok, dsl_state}) do
    Ash.Resource.Builder.add_preparation(
      dsl_state,
      {AshCloak.Preparations.FilterHashed, []}
    )
  end

  def after?(transformer) when transformer in @after_transformers, do: true
  def after?(_), do: false
end
