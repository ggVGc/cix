defmodule Frix.Macro do
  @moduledoc """
  Macros for writing DSL expressions with nicer syntax that compiles to C code.
  """

  @doc """
  Macro for building DSL with a nicer syntax.
  
  Example:
      c_program do
        add_var(:count, :int, 42)
        add_func(:add, :int, [x: :int, y: :int], ["x + y"])
      end
  """
  defmacro c_program(do: block) do
    quote do
      import Frix.Macro
      var!(dsl) = Frix.DSL.new()
      unquote(block)
      Frix.DSL.generate_c_code(var!(dsl))
    end
  end

  @doc """
  Adds a variable to the current DSL context.
  """
  defmacro add_var(name, type, value) do
    quote do
      var!(dsl) = Frix.DSL.add_variable(var!(dsl), unquote(to_string(name)), unquote(to_string(type)), unquote(value))
    end
  end

  @doc """
  Adds a function with parameters to the current DSL context.
  """
  defmacro add_func(name, return_type, params, body) do
    quote do
      params_list = unquote(build_params(params))
      body_list = unquote(build_body_list(body))
      var!(dsl) = Frix.DSL.add_function(var!(dsl), unquote(to_string(name)), unquote(to_string(return_type)), params_list, body_list)
    end
  end

  @doc """
  Adds a function without parameters to the current DSL context.
  """
  defmacro add_func(name, return_type, body) do
    quote do
      body_list = unquote(build_body_list(body))
      var!(dsl) = Frix.DSL.add_function(var!(dsl), unquote(to_string(name)), unquote(to_string(return_type)), [], body_list)
    end
  end

  @doc """
  Helper macro for creating return statements.
  """
  defmacro ret(expr) do
    quote do
      Frix.DSL.return_stmt(unquote(expr))
    end
  end

  @doc """
  Helper macro for creating assignments.
  """
  defmacro assign(var_name, expr) do
    quote do
      Frix.DSL.assign(unquote(to_string(var_name)), unquote(expr))
    end
  end

  @doc """
  Helper macro for creating function calls.
  """
  defmacro call(func_name, args \\ []) do
    quote do
      Frix.DSL.call_function(unquote(to_string(func_name)), unquote(args))
    end
  end

  # Private helper functions

  defp build_params(params) when is_list(params) do
    params
    |> Enum.map(fn {name, type} ->
      quote do: Frix.DSL.param(unquote(to_string(name)), unquote(to_string(type)))
    end)
  end

  defp build_body_list(body_list) when is_list(body_list) do
    body_list
    |> Enum.map(fn
      {:ret, expr} -> quote do: Frix.DSL.return_stmt(unquote(expr))
      {:assign, var, expr} -> quote do: Frix.DSL.assign(unquote(to_string(var)), unquote(expr))
      {:call, func, args} -> quote do: Frix.DSL.call_function(unquote(to_string(func)), unquote(args))
      {:{}, _, [:ret, expr]} -> quote do: Frix.DSL.return_stmt(unquote(expr))
      {:{}, _, [:assign, var, expr]} -> quote do: Frix.DSL.assign(unquote(to_string(var)), unquote(expr))
      {:{}, _, [:call, func, args]} -> quote do: Frix.DSL.call_function(unquote(to_string(func)), unquote(args))
      expr when is_binary(expr) -> quote do: Frix.DSL.return_stmt(unquote(expr))
    end)
  end

  defp build_body_list(single_expr) do
    [quote do: Frix.DSL.return_stmt(unquote(single_expr))]
  end
end