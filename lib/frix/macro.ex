defmodule Frix.Macro do
  @moduledoc """
  Macros for writing DSL expressions with natural Elixir syntax that compiles to C code.
  """

  @doc """
  Macro for building DSL with natural Elixir expressions.
  
  Returns an intermediate representation (IR) that can be:
  - Converted to C code with `Frix.IR.to_c_code/1`
  - Executed directly in Elixir with `Frix.IR.execute/1`
  
  Example:
      ir = c_program do
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
      
      # Generate C code
      c_code = Frix.IR.to_c_code(ir)
      
      # Or execute directly
      {:ok, result} = Frix.IR.execute(ir)
  """
  defmacro c_program(do: block) do
    quote do
      import Frix.Macro, only: [var: 3, function: 3, function: 4, return: 1]
      var!(ir) = Frix.IR.new()
      unquote(transform_block(block))
      var!(ir)
    end
  end

  @doc """
  Adds a variable to the current IR context.
  """
  defmacro var(name, type, value) do
    quote do
      var!(ir) = Frix.IR.add_variable(var!(ir), unquote(to_string(name)), unquote(to_string(type)), unquote(value))
    end
  end

  @doc """
  Adds a function with parameters to the current IR context.
  """
  defmacro function(name, return_type, params, do: body) do
    quote do
      params_list = unquote(build_ir_params(params))
      body_list = unquote(transform_function_body(body))
      var!(ir) = Frix.IR.add_function(var!(ir), unquote(to_string(name)), unquote(to_string(return_type)), params_list, body_list)
    end
  end

  @doc """
  Adds a function without parameters to the current IR context.
  """
  defmacro function(name, return_type, do: body) do
    quote do
      body_list = unquote(transform_function_body(body))
      var!(ir) = Frix.IR.add_function(var!(ir), unquote(to_string(name)), unquote(to_string(return_type)), [], body_list)
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
      var!(ir) = Frix.IR.add_variable(var!(ir), unquote(to_string(name)), unquote(to_string(type)), unquote(value))
    end
  end

  defp transform_statement({:function, _, [name, return_type, params, [do: body]]}) do
    quote do
      params_list = unquote(build_ir_params(params))
      body_list = unquote(transform_function_body(body))
      var!(ir) = Frix.IR.add_function(var!(ir), unquote(to_string(name)), unquote(to_string(return_type)), params_list, body_list)
    end
  end

  defp transform_statement({:function, _, [name, return_type, [do: body]]}) do
    quote do
      body_list = unquote(transform_function_body(body))
      var!(ir) = Frix.IR.add_function(var!(ir), unquote(to_string(name)), unquote(to_string(return_type)), [], body_list)
    end
  end

  defp transform_statement(stmt) do
    stmt
  end

  defp build_ir_params(params) when is_list(params) do
    params
    |> Enum.map(fn {name, type} ->
      quote do: %{name: unquote(to_string(name)), type: unquote(to_string(type))}
    end)
  end

  defp transform_function_body({:__block__, _, statements}) do
    statements |> Enum.map(&transform_body_statement/1)
  end

  defp transform_function_body(single_statement) do
    [transform_body_statement(single_statement)]
  end

  # Transform function body statements to IR format
  defp transform_body_statement({:return, _, [expr]}) do
    quote do: {:return, unquote(transform_ir_expression(expr))}
  end

  defp transform_body_statement({:=, _, [{var_name, _, nil}, expr]}) when is_atom(var_name) do
    quote do: {:assign, unquote(to_string(var_name)), unquote(transform_ir_expression(expr))}
  end

  defp transform_body_statement({{:., _, [{func_name, _, nil}]}, _, args}) when is_atom(func_name) do
    transformed_args = args |> Enum.map(&transform_ir_expression/1)
    quote do: {:call, unquote(to_string(func_name)), unquote(transformed_args)}
  end

  defp transform_body_statement({func_name, _, args}) when is_atom(func_name) and is_list(args) do
    transformed_args = args |> Enum.map(&transform_ir_expression/1)
    quote do: {:call, unquote(to_string(func_name)), unquote(transformed_args)}
  end

  defp transform_body_statement({func_name, _, nil}) when is_atom(func_name) do
    quote do: {:call, unquote(to_string(func_name)), []}
  end

  # Transform expressions to IR format
  defp transform_ir_expression({:+, _, [left, right]}) do
    quote do: {:binary_op, :add, unquote(transform_ir_expression(left)), unquote(transform_ir_expression(right))}
  end

  defp transform_ir_expression({:-, _, [left, right]}) do
    quote do: {:binary_op, :sub, unquote(transform_ir_expression(left)), unquote(transform_ir_expression(right))}
  end

  defp transform_ir_expression({:*, _, [left, right]}) do
    quote do: {:binary_op, :mul, unquote(transform_ir_expression(left)), unquote(transform_ir_expression(right))}
  end

  defp transform_ir_expression({:/, _, [left, right]}) do
    quote do: {:binary_op, :div, unquote(transform_ir_expression(left)), unquote(transform_ir_expression(right))}
  end

  defp transform_ir_expression({var_name, _, nil}) when is_atom(var_name) do
    quote do: {:var, unquote(to_string(var_name))}
  end

  defp transform_ir_expression(literal) when is_integer(literal) or is_binary(literal) do
    quote do: {:literal, unquote(literal)}
  end

  defp transform_ir_expression({func_name, _, args}) when is_atom(func_name) and is_list(args) do
    transformed_args = args |> Enum.map(&transform_ir_expression/1)
    quote do: {:call, unquote(to_string(func_name)), unquote(transformed_args)}
  end

  defp transform_ir_expression(expr) do
    quote do: {:literal, unquote(expr)}
  end
end