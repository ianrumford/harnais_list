defmodule Harnais.List do
  @moduledoc ~S"""
  Functions for Testing Lists.

  ## Errors

  Errors are managed by `Harnais.Error`.

  The doctests include examples where the exception message
  (`Exception.message/1`) is shown. Other doctests export the
  exception (`Harnais.Error.export/1`) and show the exception field
  breakdown.
  """

  require Plymio.Fontais.Option
  use Plymio.Codi
  use Harnais.Attribute
  use Harnais.Error.Attribute

  @codi_opts [
    {@plymio_codi_key_vekil, Plymio.Vekil.Codi.__vekil__()}
  ]

  import Plymio.Fontais.Option,
    only: [
      opts_create_aliases_dict: 1,
      opts_canonical_keys: 2
    ]

  import Harnais.Error,
    only: [
      new_error_result: 1,
      new_errors_result: 1
    ]

  import Plymio.Funcio.Enum.Map.Collate,
    only: [
      map_concurrent_collate2_enum: 2
    ]

  @type opts :: Harnais.opts()
  @type error :: Harnais.error()

  @harnais_list_error_message_list_invalid "list invalid"
  @harnais_list_error_message_list_compare_failed "list compare failed"

  @harnais_list_compare_worker_kvs_aliases [
    {@harnais_key_compare_values, nil},
    {@harnais_key_transform_list, nil}
  ]

  @harnais_list_compare_worker_dict_aliases @harnais_list_compare_worker_kvs_aliases
                                            |> opts_create_aliases_dict

  @doc false
  def opts_canonical_compare_worker_opts(opts, dict \\ @harnais_list_compare_worker_dict_aliases) do
    opts |> opts_canonical_keys(dict)
  end

  defp list_fetch_index(list, index)
       when is_list(list) and is_integer(index) do
    case index > length(list) - 1 do
      false ->
        {:ok, Enum.at(list, index)}

      true ->
        new_error_result(m: "list #{inspect(list)} index invalid", v: index)
    end
  end

  defp list_fetch_index!(list, index)
       when is_list(list) and is_integer(index) do
    case list_fetch_index(list, index) do
      {:ok, value} ->
        value

      {:error, error} ->
        raise error
    end
  end

  defp list_compare_worker(list1, list2, opts)

  defp list_compare_worker(list1, list2, opts)
       when is_list(list1) and is_list(list2) do
    with {:ok, opts} <- opts |> opts_canonical_compare_worker_opts do
      fun_compare_values =
        opts
        |> Keyword.get(:compare_values, fn _key, v1, v2 -> v1 == v2 end)

      {transform_list1, transform_list2} =
        opts
        |> Keyword.get(:transform_list)
        |> case do
          fun when is_function(fun) -> {fun.(list1), fun.(list2)}
          _ -> {list1, list2}
        end

      index1_max = length(transform_list1) - 1

      index2_max = length(transform_list2) - 1

      [index1_max, index2_max]
      |> Enum.max()
      |> (fn
            max when max < 0 -> []
            max -> Range.new(0, max)
          end).()
      |> map_concurrent_collate2_enum(fn ndx ->
        transform_list1
        |> list_fetch_index(ndx)
        |> case do
          {:ok, v1} ->
            transform_list2
            |> list_fetch_index(ndx)
            |> case do
              {:ok, v2} ->
                fun_compare_values.(ndx, v1, v2)
                |> case do
                  true ->
                    @plymio_fontais_the_unset_value

                  x when x in [nil, false] ->
                    new_error_result(
                      t: :value,
                      m: @harnais_list_error_message_list_compare_failed,
                      r: @harnais_error_reason_mismatch,
                      i: ndx,
                      v1: v1,
                      v2: v2
                    )

                  {:ok, _} ->
                    @plymio_fontais_the_unset_value

                  {:error, %{__exception__: true}} = result ->
                    result
                end

              _ ->
                new_error_result(
                  t: @harnais_error_value_field_type_value,
                  m: @harnais_list_error_message_list_compare_failed,
                  r: @harnais_error_reason_missing,
                  i: ndx,
                  v1: v1,
                  v2: @harnais_error_status_value_no_value
                )
            end

          _ ->
            new_error_result(
              t: @harnais_error_value_field_type_value,
              m: @harnais_list_error_message_list_compare_failed,
              r: @harnais_error_reason_missing,
              i: ndx,
              v1: @harnais_error_status_value_no_value,
              v2: list_fetch_index!(transform_list2, ndx)
            )
        end
      end)
      |> case do
        {:error, %{__exception__: true}} = result -> result
        {:ok, _} -> {:ok, list1}
      end
    else
      {:error, %{__exception__: true}} = result -> result
    end
  end

  @doc ~S"""
  `harnais_list_compare/3` takes two values, each expected to be a
  `List`, and optional *opts*, and compares them, concurrently, element by element.

  If the compare succeeds `{:ok, first_argument}` is returned, else `{:error, error}`.

  The default is to use `Kernel.==/2` to compare the elements at the same index of each
  list. A `falsy` result will add  a new error result.

  The compare function can be overriden using the `:compare_values` key
  together with a function of arity 3 which is passed the `index` (zero offset), `value1` and
  `value2` and should return `true`, `false`, `nil`, `{:ok, value}`
  or `{error, error}`.

  The `:transform_list` option can be used to e.g. sort each list
  before comparsion. The value must be a function of arity 1; it will
  be passed each list in turn. (Note, if the compare succeeds, the
  value in the `{:ok, value}` result is the original, un-transformed first argument.)

  ## Examples

  Some simple sucessful compares:

      iex> harnais_list_compare([], [])
      {:ok, []}

      iex> harnais_list_compare([1, 2, 3], [1, 2, 3])
      {:ok, [1, 2, 3]}

      iex> harnais_list_compare([a: 1, b: 2, c: 3], [a: 1, b: 2, c: 3])
      {:ok, [a: 1, b: 2, c: 3]}

  The next two examples demonstrate an element mismatch (`3` v `4`) at
  index `2`. One shows the exception message and the other shows the
  exception export:

      iex> {:error, error} = harnais_list_compare([1, 2, 3], [1, 2, 4])
      ...> error |> Exception.message
      "list compare failed, reason=:mismatch, type=:value, location=2, value1=3, value2=4"

      iex> {:error, error} = harnais_list_compare([1, 2, 3], [1, 2, 4])
      ...> error |> Harnais.Error.export
      {:ok, [error: [[m: "list compare failed", r: :mismatch, t: :value, l: 2, v1: 3, v2: 4]]]}

  These two demonstrate unequal length lists:

      iex> {:error, error} = harnais_list_compare([1, 2, 3], [1, 2])
      ...> error |> Exception.message
      "list compare failed, reason=:missing, type=:value, location=2, value1=3, value2=:no_value"

      iex> {:error, error} = harnais_list_compare([1, 2], [1, 2, 3])
      ...> error |> Harnais.Error.export
      {:ok, [error: [[m: "list compare failed", r: :missing, t: :value, l: 2, v1: :no_value, v2: 3]]]}

  Here the lists are sorted before the compare, ensuring a sucessful
  compare.  Note the returned list is the original 1st argument.

      iex> harnais_list_compare([2, 1, 3], [3, 2, 1], transform_list: &Enum.sort/1)
      {:ok, [2, 1, 3]}

  The next two have a `:compare_values` function. The first one always
  returns `true` even if `:value1` and `:value2` are different.

      iex> harnais_list_compare([2, 1, 3], [3, 2, 1], compare_values: fn _k,_v1,_v2 -> true end)
      {:ok, [2, 1, 3]}

  The next one can return `{:error, error}` as well as `true`.

      iex> {:error, error} = harnais_list_compare([2, 1, 3], [3, 2, 1],
      ...>   compare_values: fn
      ...>     k,_v1,_v2 when k < 2 -> true
      ...>     _,v1,v2 -> Harnais.Error.new_error_result(
      ...>         r: :override, t: :special, l: :the_one, v1: v1, v2: v2)
      ...>   end)
      ...> error |> Harnais.Error.export
      {:ok, [error: [[r: :override, t: :special, l: :the_one, v1: 3, v2: 1]]]}

  First argument is not a list:

      iex> {:error, error} = harnais_list_compare(42, [b: 2])
      ...> error |> Harnais.Error.export
      {:ok, [error: [[m: "list compare failed", r: :not_list, t: :arg, l: 0, v: 42]]]}

  Second argument is not a list:

      iex> {:error, error} = harnais_list_compare([a: 1], 42)
      ...> error |> Exception.message
      "list compare failed, reason=:not_list, type=:arg, location=1, got: 42"

  Comparing `Keyword` lists works as expected:

      iex> {:error, error} = harnais_list_compare([a: 1], [b: 2])
      ...> error |> Harnais.Error.export
      {:ok, [error: [[m: "list compare failed", r: :mismatch, t: :value, l: 0, v1: {:a, 1}, v2: {:b, 2}]]]}

  Examples for the bang function:

      iex> harnais_list_compare!([1, 2, 3], [1, 2, 3])
      [1, 2, 3]

      iex> harnais_list_compare!([a: 1], [a: 1])
      [a: 1]

      iex> harnais_list_compare!([1, 21, 3], [1, 22, 3])
      ** (Harnais.Error) list compare failed, reason=:mismatch, type=:value, location=1, value1=21, value2=22

      iex> harnais_list_compare!([1, 2, 3], [1, 2])
      ** (Harnais.Error) list compare failed, reason=:missing, type=:value, location=2, value1=3, value2=:no_value

  Examples for the query function:

      iex> harnais_list_compare?([1, 2, 3], [1, 2, 3])
      true

      iex> harnais_list_compare?([a: 1], [a: 1])
      true

      iex> harnais_list_compare?([1, 21, 3], [1, 22, 3])
      false

      iex> harnais_list_compare?([1, 2, 3], [1, 2])
      false

  """
  @since "0.1.0"

  @spec harnais_list_compare(any, any, opts) :: {:ok, list} | {:error, error}

  def harnais_list_compare(list1, list2, opts \\ [])

  def harnais_list_compare(list1, list2, opts) do
    # build errors incrementally
    [list1, list2]
    |> Stream.with_index()
    |> Enum.reduce([], fn
      {list, _ndx}, errors when is_list(list) ->
        errors

      {value, ndx}, errors ->
        [
          new_error_result(
            t: @harnais_error_value_field_type_arg,
            m: @harnais_list_error_message_list_compare_failed,
            r: @harnais_error_reason_not_list,
            i: ndx,
            v: value
          )
          | errors
        ]
    end)
    |> case do
      # no errors so far
      [] ->
        list_compare_worker(list1, list2, opts)

      # error already
      errors ->
        errors |> Enum.reverse() |> Enum.map(&elem(&1, 1)) |> new_errors_result
    end
  end

  @doc ~S"""
  `harnais_list/1` tests whether argument is a `List` and,
   if true, returns `{:ok, argument}` else `{:error, errors}`.

  ## Examples

  Some simple succesful tests:

      iex> harnais_list([1, 2, 3])
      {:ok, [1, 2, 3]}

      iex> harnais_list([1, :two, "tre"])
      {:ok, [1, :two, "tre"]}

      iex> harnais_list([a: 1, b: 2, c: 3])
      {:ok, [a: 1, b: 2, c: 3]}

   The next two examples have an non-list argument (`42`). The first
   show the exception message and the second the exception export:

      iex> {:error, error} = harnais_list(42)
      ...> error |> Exception.message
      "list invalid, got: 42"

      iex> {:error, error} = harnais_list(42)
      ...> error |> Harnais.Error.export
      {:ok, [error: [[m: "list invalid", r: :not_list, t: :arg, v: 42]]]}

  Examples for the bang function:

      iex> harnais_list!([1, 2, 3])
      [1, 2, 3]

      iex> harnais_list!([1, :two, "tre"])
      [1, :two, "tre"]

      iex> harnais_list!([a: 1])
      [a: 1]

      iex> harnais_list!(42)
      ** (Harnais.Error) list invalid, got: 42

      iex> harnais_list!(%{a: 1})
      ** (Harnais.Error) list invalid, got: %{a: 1}

  Examples for the query function:

      iex> harnais_list?([a: 1, b: 2, c: 3])
      true

      iex> harnais_list?(42)
      false

      iex> harnais_list?(%{a: 1})
      false

  """

  @since "0.1.0"

  @spec harnais_list(any) :: {:ok, list} | {:error, error}

  def harnais_list(value)

  def harnais_list(value) when is_list(value) do
    {:ok, value}
  end

  def harnais_list(value) do
    new_error_result(
      message_config: [:message, :value],
      t: @harnais_error_value_field_type_arg,
      m: @harnais_list_error_message_list_invalid,
      r: @harnais_error_reason_not_list,
      v: value
    )
  end

  @quote_result_list_no_return quote(do: list | no_return)

  [
    # there is a bug in codi v0.3.0 that gets the doc wrong when `:as` is given.
    delegate: [
      name: :harnais_list?,
      as: :is_list,
      to: Kernel,
      args: :list,
      since: "0.1.0",
      result: :boolean,
      doc: "Delegated to `Kernel.is_list/1`"
    ],
    bang: [as: :harnais_list, args: :list, since: "0.1.0", result: @quote_result_list_no_return],
    bang: [
      as: :harnais_list_compare,
      args: [:list1, :list2],
      since: "0.1.0",
      result: @quote_result_list_no_return
    ],
    query: [as: :harnais_list_compare, args: [:list1, :list2], since: "0.1.0", result: true],
    bang: [
      as: :harnais_list_compare,
      args: [:list1, :list2, :opts],
      since: "0.1.0",
      result: @quote_result_list_no_return
    ],
    query: [
      as: :harnais_list_compare,
      args: [:list1, :list2, :opts],
      since: "0.1.0",
      result: true
    ]
  ]
  |> Enum.flat_map(fn {pattern, opts} ->
    [pattern: [pattern: pattern] ++ opts]
  end)
  |> CODI.reify_codi(@codi_opts)
end
