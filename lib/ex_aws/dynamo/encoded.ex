defmodule ExAws.Dynamo.Encoded do
  @moduledoc """
  Create a value that is already encoded for DynamoDB.

  This can be useful if you want to override the default encoding for a value.

  > #### Note {: .info}
  > An `ExAws.Dynamo.Encoded` value should not be nested within another
  > `ExAws.Dynamo.Encoded` value.

  ## Examples

  ```elixir
  iex> Encoder.encode(Encoded.new(%{"B" => "this is binary"}))
  %{"B" => "this is binary"}

  iex> Encoder.encode(%{
  ...>   foo: Encoded.new(%{"B" => "this is binary"}),
  ...>   bar: "this is a string"
  ...> })
  %{"M" => %{"foo" => %{"B" => "this is binary"}, "bar" => %{"S" => "this is a string"}}}
  ```
  """

  defstruct [:value]

  @typedoc """
  A value that is already encoded for DynamoDB.

  ## Examples

  ```elixir
  %{"B" => "this is binary"}

  %{"M" => %{"foo" => %{"B" => "this is binary"}, "bar" => %{"N" => "1234"}}}
  ```
  """
  @type typed_value :: %{String.t() => any()}

  @opaque t :: %__MODULE__{value: typed_value()}

  @doc """
  Create a new value from an map that is already encoded with the types
  for DynamoDB.

  See the [AWS docs](https://docs.aws.amazon.com/amazondynamodb/latest/APIReference/API_AttributeValue.html)
  for more information on the types.

  ## Examples

  ```elixir
  iex> Encoded.new(%{"B" => "this is binary"})
  ```
  """
  @spec new(value :: typed_value()) :: t()
  def new(value) when is_map(value) do
    %__MODULE__{value: value}
  end
end
