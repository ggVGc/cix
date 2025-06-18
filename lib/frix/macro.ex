defmodule Frix.Macro do
  @moduledoc """
  Macros for writing DSL expressions with natural Elixir syntax that compiles to C code.
  """

  @doc """
  Macro for building DSL with natural Elixir expressions.
  
  Example:
      c_program do
        var :count, :int, 42
        var :max_size, :long, 1024
        
        function :add, :int, [x: :int, y: :int] do
          return x + y
        end
        
        function :main, :int do
          printf("Hello World!")
          return 0
        end
      end
  """
  defmacro c_program(do: block) do
    quote do
      import Frix.Macro, only: [var: 3, function: 3, function: 4, return: 1]
      var!(dsl) = Frix.DSL.new()
      unquote(transform_block(block))
      Frix.DSL.generate_c_code(var!(dsl))
    end
  end

  @doc """
  Adds a variable to the current DSL context.
  """
  defmacro var(name, type, value) do
    quote do
      var!(dsl) = Frix.DSL.add_variable(var!(dsl), unquote(to_string(name)), unquote(to_string(type)), unquote(value))
    end
  end

  @doc """
  Adds a function with parameters to the current DSL context.
  """
  defmacro function(name, return_type, params, do: body) do
    quote do
      params_list = unquote(build_params(params))
      body_list = unquote(transform_function_body(body))
      var!(dsl) = Frix.DSL.add_function(var!(dsl), unquote(to_string(name)), unquote(to_string(return_type)), params_list, body_list)
    end
  end

  @doc """
  Adds a function without parameters to the current DSL context.
  """
  defmacro function(name, return_type, do: body) do
    quote do
      body_list = unquote(transform_function_body(body))
      var!(dsl) = Frix.DSL.add_function(var!(dsl), unquote(to_string(name)), unquote(to_string(return_type)), [], body_list)
    end
  end

  @doc """
  Return statement for functions.
  """
  defmacro return(_expr) do
    # This is handled by transform_function_body - should not be called directly
    raise "return/1 can only be used inside function bodies"
  end

  # Private helper functions for AST transformation

  defp transform_block({:__block__, _, statements}) do
    statements
    |> Enum.map(&transform_statement/1)
    |> Enum.reduce(quote(do: nil), fn stmt, acc ->
      quote do
        unquote(acc)
        unquote(stmt)
      end
    end)
  end

  defp transform_block(single_statement) do
    transform_statement(single_statement)
  end

  defp transform_statement({:var, _, [name, type, value]}) do
    quote do
      var!(dsl) = Frix.DSL.add_variable(var!(dsl), unquote(to_string(name)), unquote(to_string(type)), unquote(value))
    end
  end

  defp transform_statement({:function, _, [name, return_type, params, [do: body]]}) do
    quote do
      params_list = unquote(build_params(params))
      body_list = unquote(transform_function_body(body))
      var!(dsl) = Frix.DSL.add_function(var!(dsl), unquote(to_string(name)), unquote(to_string(return_type)), params_list, body_list)
    end
  end

  defp transform_statement({:function, _, [name, return_type, [do: body]]}) do
    quote do
      body_list = unquote(transform_function_body(body))
      var!(dsl) = Frix.DSL.add_function(var!(dsl), unquote(to_string(name)), unquote(to_string(return_type)), [], body_list)
    end
  end

  defp transform_statement(stmt) do
    stmt
  end

  defp build_params(params) when is_list(params) do
    params
    |> Enum.map(fn {name, type} ->
      quote do: Frix.DSL.param(unquote(to_string(name)), unquote(to_string(type)))
    end)
  end

  defp transform_function_body({:__block__, _, statements}) do
    statements |> Enum.map(&transform_body_statement/1)
  end

  defp transform_function_body(single_statement) do
    [transform_body_statement(single_statement)]
  end

  # Transform function body statements
  defp transform_body_statement({:return, _, [expr]}) do
    quote do: Frix.DSL.return_stmt(unquote(transform_expression(expr)))
  end

  defp transform_body_statement({:=, _, [{var_name, _, nil}, expr]}) when is_atom(var_name) do
    quote do: Frix.DSL.assign(unquote(to_string(var_name)), unquote(transform_expression(expr)))
  end

  defp transform_body_statement({{:., _, [{func_name, _, nil}]}, _, args}) when is_atom(func_name) do
    transformed_args = args |> Enum.map(&transform_expression/1)
    quote do: Frix.DSL.call_function(unquote(to_string(func_name)), unquote(transformed_args))
  end

  defp transform_body_statement({func_name, _, args}) when is_atom(func_name) and is_list(args) do
    transformed_args = args |> Enum.map(&transform_expression/1)
    quote do: Frix.DSL.call_function(unquote(to_string(func_name)), unquote(transformed_args))
  end

  defp transform_body_statement({func_name, _, nil}) when is_atom(func_name) do
    quote do: Frix.DSL.call_function(unquote(to_string(func_name)), [])
  end

  # Transform expressions to C-like strings
  defp transform_expression({:+, _, [left, right]}) do
    quote do
      "#{unquote(transform_expression(left))} + #{unquote(transform_expression(right))}"
    end
  end

  defp transform_expression({:-, _, [left, right]}) do
    quote do
      "#{unquote(transform_expression(left))} - #{unquote(transform_expression(right))}"
    end
  end

  defp transform_expression({:*, _, [left, right]}) do
    quote do
      "#{unquote(transform_expression(left))} * #{unquote(transform_expression(right))}"
    end
  end

  defp transform_expression({:/, _, [left, right]}) do
    quote do
      "#{unquote(transform_expression(left))} / #{unquote(transform_expression(right))}"
    end
  end

  defp transform_expression({var_name, _, nil}) when is_atom(var_name) do
    to_string(var_name)
  end

  defp transform_expression(literal) when is_integer(literal) do
    literal
  end

  defp transform_expression(literal) when is_binary(literal) do
    "\"#{literal}\""
  end

  defp transform_expression(expr) do
    expr
  end
end