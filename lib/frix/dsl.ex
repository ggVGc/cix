defmodule Frix.DSL do
  @moduledoc """
  A minimal DSL for generating C code with support for functions and integer values.
  """

  defstruct functions: [], variables: []

  @type t :: %__MODULE__{
    functions: [dsl_function()],
    variables: [variable()]
  }

  @type dsl_function :: %{
    name: String.t(),
    return_type: String.t(),
    params: [param()],
    body: [statement()]
  }

  @type param :: %{
    name: String.t(),
    type: String.t()
  }

  @type variable :: %{
    name: String.t(),
    type: String.t(),
    value: integer()
  }

  @type statement :: 
    {:return, term()} |
    {:assign, String.t(), term()} |
    {:call, String.t(), [term()]}

  def new do
    %__MODULE__{}
  end

  def add_function(dsl, name, return_type, params \\ [], body \\ []) do
    function = %{
      name: name,
      return_type: return_type,
      params: params,
      body: body
    }
    %{dsl | functions: [function | dsl.functions]}
  end

  def add_variable(dsl, name, type, value) when is_integer(value) do
    variable = %{
      name: name,
      type: type,
      value: value
    }
    %{dsl | variables: [variable | dsl.variables]}
  end

  def param(name, type) do
    %{name: name, type: type}
  end

  def return_stmt(value) do
    {:return, value}
  end

  def assign(var_name, value) do
    {:assign, var_name, value}
  end

  def call_function(func_name, args \\ []) do
    {:call, func_name, args}
  end

  def generate_c_code(%__MODULE__{} = dsl) do
    variables_code = generate_variables(dsl.variables)
    functions_code = generate_functions(dsl.functions)
    
    [variables_code, functions_code]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  defp generate_variables([]), do: ""
  defp generate_variables(variables) do
    variables
    |> Enum.reverse()
    |> Enum.map(&generate_variable/1)
    |> Enum.join("\n")
  end

  defp generate_variable(%{name: name, type: type, value: value}) do
    "#{type} #{name} = #{value};"
  end

  defp generate_functions([]), do: ""
  defp generate_functions(functions) do
    functions
    |> Enum.reverse()
    |> Enum.map(&generate_function/1)
    |> Enum.join("\n\n")
  end

  defp generate_function(%{name: name, return_type: return_type, params: params, body: body}) do
    params_str = generate_params(params)
    body_str = generate_body(body)
    
    "#{return_type} #{name}(#{params_str}) {\n#{body_str}\n}"
  end

  defp generate_params([]), do: "void"
  defp generate_params(params) do
    params
    |> Enum.map(fn %{name: name, type: type} -> "#{type} #{name}" end)
    |> Enum.join(", ")
  end

  defp generate_body([]), do: ""
  defp generate_body(statements) do
    statements
    |> Enum.map(&generate_statement/1)
    |> Enum.map(&("    " <> &1))
    |> Enum.join("\n")
  end

  defp generate_statement({:return, value}) do
    "return #{format_value(value)};"
  end

  defp generate_statement({:assign, var_name, value}) do
    "#{var_name} = #{format_value(value)};"
  end

  defp generate_statement({:call, func_name, args}) do
    args_str = args |> Enum.map(&format_value/1) |> Enum.join(", ")
    "#{func_name}(#{args_str});"
  end

  defp format_value(value) when is_integer(value), do: to_string(value)
  defp format_value(value) when is_binary(value), do: value
  defp format_value(value), do: inspect(value)
end