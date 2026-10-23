defmodule Aiur.ControlCall.Literal do
  @moduledoc false

  @max_depth 6

  @spec convert(list()) :: {:ok, list()} | {:error, atom()}
  def convert(args), do: convert_list(args, 0)

  @spec validate_raw_option_keys(map(), list()) :: :ok | {:error, :option_not_allowed}
  def validate_raw_option_keys(%{options: options}, args) do
    Enum.reduce_while(args, :ok, fn
      keyword, :ok when is_list(keyword) ->
        if option_not_allowed?(keyword, options), do: {:halt, {:error, :option_not_allowed}}, else: {:cont, :ok}

      _value, :ok ->
        {:cont, :ok}
    end)
  end

  defp option_not_allowed?(keyword, options),
    do: Keyword.keyword?(keyword) and Enum.any?(keyword, fn {key, _value} -> not Map.has_key?(options, key) end)

  defp convert_list(values, depth) when depth <= @max_depth and is_list(values) do
    Enum.reduce_while(values, {:ok, []}, fn value, {:ok, acc} ->
      case literal(value, depth + 1) do
        {:ok, converted} -> {:cont, {:ok, [converted | acc]}}
        error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, reversed} -> {:ok, Enum.reverse(reversed)}
      error -> error
    end
  end

  defp convert_list(_values, _depth), do: {:error, :non_literal_argument}

  defp literal(value, depth) when depth <= @max_depth and is_binary(value), do: {:ok, value}
  defp literal(value, depth) when depth <= @max_depth and is_integer(value), do: {:ok, value}
  defp literal(value, depth) when depth <= @max_depth and is_float(value), do: {:ok, value}
  defp literal(value, depth) when depth <= @max_depth and (is_boolean(value) or is_nil(value) or is_atom(value)), do: {:ok, value}
  defp literal({:__aliases__, _, _}, _depth), do: {:error, :non_literal_argument}

  defp literal({{:., _, [{:__aliases__, _, [:Base]}, :decode64!]}, _, [arg]}, depth) when depth < @max_depth do
    with {:ok, encoded} <- literal(arg, depth + 1), true <- is_binary(encoded) do
      case Base.decode64(encoded) do
        {:ok, decoded} -> {:ok, decoded}
        :error -> {:error, :non_literal_argument}
      end
    else
      _ -> {:error, :non_literal_argument}
    end
  end

  defp literal({left, right}, depth) when depth < @max_depth do
    with {:ok, left_value} <- literal(left, depth + 1), {:ok, right_value} <- literal(right, depth + 1), do: {:ok, {left_value, right_value}}
  end

  defp literal({:{}, _, [left, right]}, depth) when depth < @max_depth do
    with {:ok, left_value} <- literal(left, depth + 1), {:ok, right_value} <- literal(right, depth + 1), do: {:ok, {left_value, right_value}}
  end

  defp literal(list, depth) when is_list(list) and depth < @max_depth do
    convert_list(list, depth)
  end

  defp literal(_value, _depth), do: {:error, :non_literal_argument}

  @spec validate_arguments(map(), list()) :: :ok | {:error, atom()}
  def validate_arguments(%{positional: positional, options: options}, args) do
    with :ok <- validate_positional(positional, args),
         do: validate_keyword_arguments(args, options)
  end

  defp validate_positional(positional, args) when length(positional) == length(args) do
    Enum.zip(args, positional)
    |> Enum.reduce_while(:ok, fn {value, constraint}, :ok -> if valid?(value, constraint), do: {:cont, :ok}, else: {:halt, {:error, :non_literal_argument}} end)
  end

  defp validate_positional(_positional, _args), do: {:error, :non_literal_argument}

  defp validate_keyword_arguments(args, options) do
    Enum.reduce_while(args, :ok, fn arg, :ok -> keyword_result(arg, options) end)
  end

  defp validate_keyword_argument(value, options) when is_list(value) do
    if Keyword.keyword?(value), do: validate_keyword_pairs(value, options), else: :ok
  end

  defp validate_keyword_argument(_value, _options), do: :ok

  defp keyword_result(arg, options) do
    case validate_keyword_argument(arg, options) do
      :ok -> {:cont, :ok}
      error -> {:halt, error}
    end
  end

  defp validate_keyword_pairs(value, options) do
    Enum.reduce_while(value, :ok, fn {key, item}, :ok -> validate_option(key, item, options) end)
  end

  defp validate_option(key, item, options) do
    case Map.fetch(options, key) do
      :error -> {:halt, {:error, :option_not_allowed}}
      {:ok, constraint} -> if valid?(item, constraint), do: {:cont, :ok}, else: {:halt, {:error, :non_literal_argument}}
    end
  end

  defp valid?(_value, :any), do: true
  defp valid?(value, :atom), do: is_atom(value)
  defp valid?(value, {:nullable, constraint}), do: is_nil(value) or valid?(value, constraint)
  defp valid?(value, {:regex, regex}), do: is_binary(value) and Regex.match?(regex, value)
  defp valid?(value, :boolean), do: is_boolean(value)
  defp valid?(value, :string), do: is_binary(value)
  defp valid?(value, :positive), do: is_integer(value) and value > 0
  defp valid?(value, :non_negative), do: is_integer(value) and value >= 0
  defp valid?(value, :integer), do: is_integer(value)
  defp valid?(value, :literal_list), do: is_list(value)
  defp valid?(value, :string_list), do: is_list(value) and Enum.all?(value, &is_binary/1)
  defp valid?(value, :keyword), do: is_list(value) and Keyword.keyword?(value)
  defp valid?(value, :env), do: is_list(value) and Enum.all?(value, &match?({key, val} when is_binary(key) and is_binary(val), &1))
  defp valid?(value, {:enum, choices}), do: value in choices
  defp valid?(_value, _constraint), do: false
end
