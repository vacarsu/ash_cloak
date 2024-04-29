defmodule AshCloak.Preparations.FilterHashed do
  @moduledoc """
  Hash the attributes that are marked as hashed in the query.
  """

  alias Ash.Query.Operator
  alias AshCloak.Crypto

  def init(opts), do: {:ok, opts}

  def prepare(query, _, ctx) when query.action.name in [:read, :update, :destroy] do
    Ash.Query.before_action(query, fn query ->
      hashed_attrs = AshCloak.Info.cloak_hashed_attributes!(query.resource)

      Map.update!(query, :filter, fn filter ->
        Ash.Filter.map(filter, &rebuild_operator(&1, hashed_attrs))
      end)
    end)
  end

  def prepare(query, _, _) do
    query
  end

  defp rebuild_operator(
         %{right: %Ash.Query.Ref{relationship_path: [], attribute: %{name: name}}} = op,
         hashed_attrs
       ) do
    if name in hashed_attrs do
      do_rebuild_operator(op)
    else
      op
    end
  end

  defp rebuild_operator(
         %{left: %Ash.Query.Ref{relationship_path: [], attribute: %{name: name}}} = op,
         hashed_attrs
       ) do
    if name in hashed_attrs do
      do_rebuild_operator(op)
    else
      op
    end
  end

  defp rebuild_operator(op, _) do
    op
  end

  defp do_rebuild_operator(
         %Operator.Eq{
           left: value,
           right: %Ash.Query.Ref{relationship_path: [], attribute: %{name: name}} = left
         } = op
       )
       when is_binary(value) do
    %{op | left: Crypto.hmac(value)}
  end

  defp do_rebuild_operator(
         %Operator.Eq{
           left: %Ash.Query.Ref{relationship_path: [], attribute: %{name: name}},
           right: value
         } = op
       )
       when is_binary(value) do
    %{op | right: Crypto.hmac(value)}
  end

  defp do_rebuild_operator(
         %Operator.NotEq{
           left: value,
           right: %Ash.Query.Ref{relationship_path: [], attribute: %{name: name}}
         } = op
       )
       when is_binary(value) do
    %{op | left: Crypto.hmac(value)}
  end

  defp do_rebuild_operator(
         %Operator.NotEq{
           left: %Ash.Query.Ref{relationship_path: [], attribute: %{name: :hashed}},
           right: value
         } = op
       )
       when is_binary(value) do
    %{op | right: Crypto.hmac(value)}
  end

  defp do_rebuild_operator(op), do: op
end
