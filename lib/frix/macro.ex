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
        struct :Point, [x: :int, y: :int]
        
        var :count, :int, 42
        var :origin, :Point, Point.new(x: 0, y: 0)
        
        def add(x :: int, y :: int) :: int do
          return x + y
        end
        
        def main() :: int do
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
      import Frix.Macro, only: [var: 3, defn: 2, return: 1, struct: 2]
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
  Adds a function using Elixir-like defn syntax (def conflicts with Kernel.def).
  
  Examples:
    defn add(x :: int, y :: int) :: int do
      return x + y
    end
    
    defn main() :: int do
      return 0
    end
  """
  defmacro defn({:"::", _, [{name, _, params}, return_type]}, do: body) when is_list(params) do
    return_type_str = extract_type_string(return_type)
    quote do
      params_list = unquote(build_elixir_params(params))
      body_list = unquote(transform_function_body(body))
      var!(ir) = Frix.IR.add_function(var!(ir), unquote(to_string(name)), unquote(return_type_str), params_list, body_list)
    end
  end

  defmacro defn({:"::", _, [{name, _, nil}, return_type]}, do: body) do
    return_type_str = extract_type_string(return_type)
    quote do
      body_list = unquote(transform_function_body(body))
      var!(ir) = Frix.IR.add_function(var!(ir), unquote(to_string(name)), unquote(return_type_str), [], body_list)
    end
  end


  @doc """
  Adds a struct definition to the current IR context.
  """
  defmacro struct(name, fields) do
    quote do
      field_list = unquote(build_ir_fields(fields))
      var!(ir) = Frix.IR.add_struct(var!(ir), unquote(to_string(name)), field_list)
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
      var!(ir) = Frix.IR.add_variable(var!(ir), unquote(to_string(name)), unquote(to_string(type)), unquote(transform_ir_expression(value)))
    end
  end

  defp transform_statement({:struct, _, [name, fields]}) do
    quote do
      field_list = unquote(build_ir_fields(fields))
      var!(ir) = Frix.IR.add_struct(var!(ir), unquote(to_string(name)), field_list)
    end
  end

  # Handle new defn syntax in statement transformation
  defp transform_statement({:defn, _, [{:"::", _, [{name, _, params}, return_type]}, [do: body]]}) when is_list(params) do
    return_type_str = extract_type_string(return_type)
    quote do
      params_list = unquote(build_elixir_params(params))
      body_list = unquote(transform_function_body(body))
      var!(ir) = Frix.IR.add_function(var!(ir), unquote(to_string(name)), unquote(return_type_str), params_list, body_list)
    end
  end

  defp transform_statement({:defn, _, [{:"::", _, [{name, _, nil}, return_type]}, [do: body]]}) do
    return_type_str = extract_type_string(return_type)
    quote do
      body_list = unquote(transform_function_body(body))
      var!(ir) = Frix.IR.add_function(var!(ir), unquote(to_string(name)), unquote(return_type_str), [], body_list)
    end
  end


  defp transform_statement(stmt) do
    stmt
  end

  defp build_elixir_params(params) when is_list(params) do
    params
    |> Enum.map(fn
      {:"::", _, [{name, _, nil}, type]} ->
        type_str = case type do
          {type_name, _, nil} -> to_string(type_name)
          type_name when is_atom(type_name) -> to_string(type_name)
          _ -> "int"
        end
        quote do: %{name: unquote(to_string(name)), type: unquote(type_str)}
      {name, _, nil} ->
        # Default to int if no type specified
        quote do: %{name: unquote(to_string(name)), type: "int"}
    end)
  end

  defp build_ir_fields(fields) when is_list(fields) do
    fields
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

  # Handle struct.new(field: value, ...) syntax
  defp transform_ir_expression({{:., _, [{struct_name, _, nil}, :new]}, _, args}) when is_atom(struct_name) do
    # Extract field list from arguments - Elixir keyword list syntax becomes a single list argument
    field_list = case args do
      [field_list] when is_list(field_list) -> field_list
      field_list when is_list(field_list) -> field_list
      _ -> []
    end
    
    field_inits = build_struct_field_inits(field_list)
    quote do: {:struct_new, unquote(to_string(struct_name)), unquote(field_inits)}
  end

  # Handle struct.field access
  defp transform_ir_expression({{:., _, [struct_expr, field_name]}, _, []}) when is_atom(field_name) do
    quote do: {:field_access, unquote(transform_ir_expression(struct_expr)), unquote(to_string(field_name))}
  end

  defp transform_ir_expression(expr) do
    quote do: {:literal, unquote(expr)}
  end

  defp build_struct_field_inits(field_list) when is_list(field_list) do
    field_list
    |> Enum.map(fn {field_name, expr} ->
      quote do: {unquote(to_string(field_name)), unquote(transform_ir_expression(expr))}
    end)
  end

  defp extract_type_string(type) do
    case type do
      {type_name, _, nil} -> to_string(type_name)
      type_name when is_atom(type_name) -> to_string(type_name)
      _ -> "int"
    end
  end
end