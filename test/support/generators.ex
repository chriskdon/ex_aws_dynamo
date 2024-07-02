defmodule Test.Generators do
  @moduledoc """
  This module contains StreamData generators for help when writing property
  based tests.
  """

  import StreamData, except: [binary: 0]

  @type_names ["BOOL", "NULL", "B", "S", "M", "L", "BS", "SS", "NS", "N"]

  @doc """
  Dynamo number (i.e. "N") generator.
  """
  def number do
    # Only include non-integer floats. When integer floats (e.g., 123.0) are
    # encoded and decoded, they become integers which makes comparison difficult
    # when nested in other structures.
    # For example: MapSet.new([123.0]) == MapSet.new([123]) is false
    non_int_float = filter(float(), fn f -> trunc(f) != f end)

    one_of([integer(), non_int_float])
  end

  @doc """
  Dynamo string (i.e. "S") generator.
  """
  def string, do: StreamData.string(:utf8)

  @doc """
  Dynamo binary (i.e. "B") generator.
  """
  def binary, do: filter(StreamData.binary(), fn b -> !String.valid?(b) end)

  @doc """
  Dynamo type name generator
  """
  def type_name, do: @type_names |> Enum.map(&constant/1) |> one_of()

  @doc """
  Generator for map key names.

  Problematic keys like the ones that match the names of DynamoDB types are
  explicitly included to ensure they are properly handled.
  """
  def key_name do
    # The min_length is set to 10 to avoid key collisions when generating
    # values which can lead to intermittent test failures.
    one_of([type_name(), string(:alphanumeric, min_length: 10)])
  end

  @doc """
  Dynamo scalar type generator
  """
  def scalar do
    one_of([
      # "N"
      number(),
      # "S"
      string(),
      # "BOOL"
      boolean(),
      # "NULL"
      constant(nil),
      # "B"
      binary()
    ])
  end

  @doc """
  Dynamo set type generator
  """
  def set do
    one_of([
      # "SS"
      mapset_of(string()) |> nonempty(),
      # "NS"
      mapset_of(number()) |> nonempty()
      # "BS" (not currently supported)
      # mapset_of(binary()) |> nonempty()
    ])
  end

  @doc """
  Dynamo document type generator
  """
  def document do
    leaf =
      one_of([
        scalar(),
        set()
      ])

    tree(leaf, fn child ->
      list = list_of(child)
      map = map_of(key_name(), child)

      one_of([list, map])
    end)
  end

  @doc """
  Dynamo attribute generator
  """
  def attribute do
    one_of([
      scalar(),
      set(),
      document()
    ])
  end

  @doc """
  Dynamo item generator
  """
  def item do
    map_of(key_name(), attribute(), max_length: 3)
  end
end
