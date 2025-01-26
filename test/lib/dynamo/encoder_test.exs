defmodule ExAws.Dynamo.EncoderTest do
  use ExUnit.Case, async: true

  alias ExAws.Dynamo.Encoded
  alias ExAws.Dynamo.Encoder

  doctest Encoder
  doctest Encoded

  test "Encoder converts numbers to binaries" do
    assert Encoder.encode(34) == %{"N" => "34"}
  end

  test "Encoder can handle map values" do
    result = %{foo: 1, bar: %{baz: 2, zounds: "asdf"}} |> Encoder.encode()

    assert %{
             "M" => %{
               "bar" => %{"M" => %{"baz" => %{"N" => "2"}, "zounds" => %{"S" => "asdf"}}},
               "foo" => %{"N" => "1"}
             }
           } == result
  end

  test "Encoder can handle floats" do
    assert Encoder.encode(0.4) == %{"N" => "0.4"}
  end

  test "Encoder allows empty strings in a map" do
    assert Encoder.encode(%{"data" => "value", "nodata" => ""}) == %{
             "M" => %{
               "data" => %{"S" => "value"},
               "nodata" => %{"S" => ""}
             }
           }
  end

  test "Encoder can handle binaries that are not strings" do
    assert Encoder.encode(:zlib.zip("Encoder can handle binaries that are not strings")) == %{
             "B" => "BcGBCQAgCATAVX6ZBvlKUogP1P3pbmi9bYlFwal9DTPEDCu0s8E06DWqM3TqAw=="
           }
  end

  test "Encoder with structs works properly" do
    user = %Test.User{email: "foo@bar.com", name: "Bob", age: 23, admin: false}

    assert %{
             "admin" => %{"BOOL" => false},
             "age" => %{"N" => "23"},
             "email" => %{"S" => "foo@bar.com"},
             "name" => %{"S" => "Bob"}
           } = Encoder.encode_root(user)
  end

  test "encoder handles lists properly" do
    assert ["foo", "bar"] |> Encoder.encode() == %{"L" => [%{"S" => "foo"}, %{"S" => "bar"}]}
    assert [1, 2] |> Encoder.encode() == %{"L" => [%{"N" => "1"}, %{"N" => "2"}]}
    assert ["foo", 1] |> Encoder.encode() == %{"L" => [%{"S" => "foo"}, %{"N" => "1"}]}
  end

  test "encoder handles mapsets properly" do
    assert MapSet.new([1, 2, 3]) |> Encoder.encode() == %{"NS" => ["1", "2", "3"]}
    assert MapSet.new(["A", "B", "C"]) |> Encoder.encode() == %{"SS" => ["A", "B", "C"]}

    assert_raise RuntimeError, "Cannot determine a proper data type for an empty MapSet", fn ->
      MapSet.new([]) |> Encoder.encode()
    end

    assert_raise RuntimeError,
                 "All elements in a MapSet must be only numbers or only strings",
                 fn ->
                   MapSet.new([1, "A"]) |> Encoder.encode()
                 end
  end

  test "encoder works with nested structs" do
    nested_structs =
      %Test.Nested{items: [%Test.Nested{items: ["asdf"], secret: "foo"}], secret: "bar"}
      |> Encoder.encode_root()

    expected = %{"items" => %{"L" => [%{"M" => %{"items" => %{"L" => [%{"S" => "asdf"}]}}}]}}
    assert nested_structs == expected
  end

  test "encoder nil works" do
    assert Encoder.encode(nil) == %{"NULL" => true}
    assert Encoder.encode(%{"key" => nil}) == %{"M" => %{"key" => %{"NULL" => true}}}
  end

  test "encoder skips struct fields that are marked as excepted" do
    user_except =
      %Test.ExceptUser{email: "foo@bar.com", name: "Bob", age: 23, secret: "secret information"}
      |> Encoder.encode_root()

    assert %{
             "age" => %{"M" => %{"N" => %{"S" => "23"}}},
             "email" => %{"M" => %{"S" => %{"S" => "foo@bar.com"}}},
             "name" => %{"M" => %{"S" => %{"S" => "Bob"}}}
           } == Encoder.encode_root(user_except)
    end

    test "encoder passes through #{Encoded} values unchanged" do
      encoded = Encoded.new(%{"B" => "string data as binary"})

      assert Encoder.encode(encoded) == %{"B" => "string data as binary"}

      assert Encoder.encode(%{"encoded" => encoded, "not_encoded" => "not encoded"}) ==
               %{"M" => %{"encoded" => %{"B" => "string data as binary"}, "not_encoded" => %{"S" => "not encoded"}}}
    end
end
