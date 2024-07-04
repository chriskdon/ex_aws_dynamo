defmodule ExAws.Dynamo.Decoder do
  @moduledoc """
  Decodes a Dynamo response into a struct.

  If Dynamo.Decodable is implemented for the struct, it will be called
  after the completion of the coercion.

  This is important for handling nested maps if you wanted the nested maps
  to have atom keys.
  """

  alias ExAws.Dynamo.Decodable

  @typedoc """
  Options for decoding a Dynamo response.

  ## Options

  - `:as` - The module to decode the response into.
  """
  @type decode_opts :: [{:as, module()}]

  @doc """
  Decode a Dynamo root response element.

  ## Examples

  ```elixir
  iex> Decoder.decode_root(%{"foo" => %{"S" => "bar"}, "baz" => %{"N" => "123"}})
  %{"baz" => 123, "foo" => "bar"}
  ```
  """
  @spec decode_root(map(), decode_opts()) :: map()
  def decode_root(root, opts \\ []) when is_map(root) do
    decode(%{"M" => root}, opts)
  end

  @doc """
  Decode a Dynamo response element.

  ## Examples

  ### Decoding into Elixir value

  ```elixir
  iex> Decoder.decode(%{"S" => "bar"})
  "bar"
  iex> Decoder.decode(%{"M" => %{"foo" => %{"S" => "bar"}}})
  %{"foo" => "bar"}
  ```

  ### Decoding into a struct

  ```elixir
  defmodule User do
    @derive [ExAws.Dynamo.Encodable]
    defstruct [:name, :age]
  end

  encoded = %{"M" => %{"name" => %{"S" => "Jane Doe"}, "age" => %{"N" => "23"}}}

  assert Decoder.decode(encoded, as: User) == %User{name: "Jane Doe", age: 23}
  ```
  """
  @spec decode(map(), decode_opts()) :: map()
  def decode(item, opts)

  def decode(item, as: struct_module) do
    item
    |> decode
    |> binary_map_to_struct(struct_module)
    |> Decodable.decode()
  end

  def decode(item, _opts), do: decode(item)

  @doc """
  Convert Dynamo format to Elixir

  Functions which convert the Dynamo-style values into normal Elixir values.
  Use these if you just want the Dynamo result to look more like Elixir without
  coercing it into a particular struct.
  """
  def decode(%{"BOOL" => true}), do: true
  def decode(%{"BOOL" => false}), do: false
  def decode(%{"BOOL" => "true"}), do: true
  def decode(%{"BOOL" => "false"}), do: false
  def decode(%{"NULL" => true}), do: nil
  def decode(%{"NULL" => "true"}), do: nil
  def decode(%{"B" => value}), do: Base.decode64!(value)
  def decode(%{"S" => value}), do: value
  def decode(%{"BS" => values}), do: MapSet.new(values)
  def decode(%{"M" => value}), do: Map.new(value, fn {k, v} -> {k, decode(v)} end)
  def decode(%{"SS" => values}), do: MapSet.new(values)

  def decode(%{"NS" => values}) do
    values
    |> Stream.map(&binary_to_number/1)
    |> Enum.into(MapSet.new())
  end

  def decode(%{"L" => values}) do
    Enum.map(values, &decode/1)
  end

  def decode(%{"N" => value}) when is_binary(value), do: binary_to_number(value)
  def decode(%{"N" => value}) when value |> is_integer or value |> is_float, do: value

  @doc "Attempts to convert a number to a float, and then an integer"
  def binary_to_number(binary) when is_binary(binary) do
    String.to_float(binary)
  rescue
    ArgumentError -> String.to_integer(binary)
  end

  def binary_to_number(binary), do: binary

  @doc "Converts a map with binary keys to the specified struct"
  def binary_map_to_struct(bmap, module) do
    module.__struct__()
    |> Map.from_struct()
    |> Enum.reduce(%{}, fn {k, v}, map ->
      Map.put(map, k, Map.get(bmap, Atom.to_string(k), v))
    end)
    |> Map.put(:__struct__, module)
  end
end
