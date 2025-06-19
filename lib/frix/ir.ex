defmodule Frix.IR do
  @moduledoc """
  Intermediate Representation (IR) for the Frix DSL.
  
  The IR provides a common format that can be:
  1. Converted to C code
  2. Executed directly in Elixir
  """

  defstruct variables: [], functions: [], structs: []

  @type t :: %__MODULE__{
    variables: [variable()],
    functions: [ir_function()],
    structs: [struct_def()]
  }

  @type variable :: %{
    name: String.t(),
    type: String.t(),
    value: term()
  }

  @type ir_function :: %{
    name: String.t(),
    return_type: String.t(),
    params: [param()],
    body: [statement()]
  }

  @type param :: %{
    name: String.t(),
    type: String.t()
  }

  @type struct_def :: %{
    name: String.t(),
    fields: [field()]
  }

  @type field :: %{
    name: String.t(),
    type: String.t()
  }

  @type statement ::
    {:return, expression()} |
    {:assign, String.t(), expression()} |
    {:call, String.t(), [expression()]}

  @type expression ::
    {:var, String.t()} |
    {:literal, term()} |
    {:binary_op, :add | :sub | :mul | :div, expression(), expression()} |
    {:call, String.t(), [expression()]} |
    {:struct_new, String.t(), [{String.t(), expression()}]} |
    {:field_access, expression(), String.t()}

  def new do
    %__MODULE__{}
  end

  def add_variable(ir, name, type, value) do
    variable = %{name: name, type: type, value: value}
    %{ir | variables: [variable | ir.variables]}
  end

  def add_function(ir, name, return_type, params, body) do
    function = %{name: name, return_type: return_type, params: params, body: body}
    %{ir | functions: [function | ir.functions]}
  end

  def add_struct(ir, name, fields) do
    struct_def = %{name: name, fields: fields}
    %{ir | structs: [struct_def | ir.structs]}
  end

  @doc """
  Convert IR to C code.
  """
  def to_c_code(%__MODULE__{} = ir) do
    structs_code = generate_c_structs(ir.structs)
    variables_code = generate_c_variables(ir.variables)
    functions_code = generate_c_functions(ir.functions, ir.variables)
    
    [structs_code, variables_code, functions_code]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  @doc """
  Execute IR directly in Elixir.
  """
  def execute(%__MODULE__{} = ir, function_name \\ "main", args \\ []) do
    # Initialize variables in process dictionary
    Enum.each(ir.variables, fn var ->
      value = case var.value do
        {:literal, literal_value} -> literal_value
        expr -> evaluate_expression(expr)
      end
      Process.put({:var, var.name}, value)
    end)

    # Store struct definitions for runtime use
    Enum.each(ir.structs, fn struct_def ->
      Process.put({:struct_def, struct_def.name}, struct_def)
    end)

    # Find and execute function
    case Enum.find(ir.functions, &(&1.name == function_name)) do
      nil -> {:error, "Function #{function_name} not found"}
      function -> execute_function(ir, function, args)
    end
  end

  # Private helper functions for C code generation

  defp generate_c_structs([]), do: ""
  defp generate_c_structs(structs) do
    structs
    |> Enum.reverse()
    |> Enum.map(&generate_c_struct/1)
    |> Enum.join("\n\n")
  end

  defp generate_c_struct(%{name: name, fields: fields}) do
    fields_str = fields
    |> Enum.map(fn %{name: field_name, type: field_type} ->
      "    #{field_type} #{field_name};"
    end)
    |> Enum.join("\n")
    
    "typedef struct {\n#{fields_str}\n} #{name};"
  end

  defp generate_c_variables([]), do: ""
  defp generate_c_variables(variables) do
    variables
    |> Enum.reverse()
    |> Enum.map(&generate_c_variable/1)
    |> Enum.join("\n")
  end

  defp generate_c_variable(%{name: name, type: type, value: value}) do
    value_str = case value do
      {:literal, literal_value} -> format_c_value(literal_value)
      {:struct_new, _, _} = expr -> generate_c_expression(expr)
      _ -> format_c_value(value)
    end
    "#{type} #{name} = #{value_str};"
  end

  defp generate_c_functions([], _), do: ""
  defp generate_c_functions(functions, global_vars) do
    functions
    |> Enum.reverse()
    |> Enum.map(&generate_c_function(&1, global_vars))
    |> Enum.join("\n\n")
  end

  defp generate_c_function(%{name: name, return_type: return_type, params: params, body: body}, global_vars) do
    params_str = generate_c_params(params)
    
    # Extract local variables from assignments, excluding globals and params
    local_vars = extract_local_variables(body, params, global_vars)
    local_decls = generate_local_declarations(local_vars)
    body_str = generate_c_body(body)
    
    function_body = case local_decls do
      "" -> body_str
      _ -> "#{local_decls}\n#{body_str}"
    end
    
    "#{return_type} #{name}(#{params_str}) {\n#{function_body}\n}"
  end

  defp extract_local_variables(body, params, global_vars) do
    param_names = params |> Enum.map(& &1.name) |> MapSet.new()
    global_names = global_vars |> Enum.map(& &1.name) |> MapSet.new()
    
    body
    |> Enum.flat_map(&extract_assigned_vars/1)
    |> Enum.uniq()
    |> Enum.reject(&(MapSet.member?(param_names, &1) or MapSet.member?(global_names, &1)))
  end

  defp extract_assigned_vars({:assign, var_name, _expr}), do: [var_name]
  defp extract_assigned_vars(_), do: []

  defp generate_local_declarations([]), do: ""
  defp generate_local_declarations(vars) do
    vars
    |> Enum.map(fn var_name -> "    int #{var_name};" end)
    |> Enum.join("\n")
  end

  defp generate_c_params([]), do: "void"
  defp generate_c_params(params) do
    params
    |> Enum.map(fn %{name: name, type: type} -> "#{type} #{name}" end)
    |> Enum.join(", ")
  end

  defp generate_c_body([]), do: ""
  defp generate_c_body(statements) do
    statements
    |> Enum.map(&generate_c_statement/1)
    |> Enum.map(&("    " <> &1))
    |> Enum.join("\n")
  end

  defp generate_c_statement({:return, expr}) do
    "return #{generate_c_expression(expr)};"
  end

  defp generate_c_statement({:assign, var_name, expr}) do
    "#{var_name} = #{generate_c_expression(expr)};"
  end

  defp generate_c_statement({:call, func_name, args}) do
    args_str = args |> Enum.map(&generate_c_expression/1) |> Enum.join(", ")
    "#{func_name}(#{args_str});"
  end

  defp generate_c_expression({:var, name}), do: name
  defp generate_c_expression({:literal, value}), do: format_c_value(value)
  defp generate_c_expression({:binary_op, :add, left, right}) do
    "#{generate_c_expression(left)} + #{generate_c_expression(right)}"
  end
  defp generate_c_expression({:binary_op, :sub, left, right}) do
    "#{generate_c_expression(left)} - #{generate_c_expression(right)}"
  end
  defp generate_c_expression({:binary_op, :mul, left, right}) do
    "#{generate_c_expression(left)} * #{generate_c_expression(right)}"
  end
  defp generate_c_expression({:binary_op, :div, left, right}) do
    "#{generate_c_expression(left)} / #{generate_c_expression(right)}"
  end
  defp generate_c_expression({:call, func_name, args}) do
    args_str = args |> Enum.map(&generate_c_expression/1) |> Enum.join(", ")
    "#{func_name}(#{args_str})"
  end
  defp generate_c_expression({:struct_new, struct_name, field_inits}) do
    # Generate C struct literal initialization
    field_inits_str = field_inits
    |> Enum.map(fn {field_name, expr} ->
      ".#{field_name} = #{generate_c_expression(expr)}"
    end)
    |> Enum.join(", ")
    
    "(#{struct_name}){#{field_inits_str}}"
  end
  defp generate_c_expression({:field_access, struct_expr, field_name}) do
    "#{generate_c_expression(struct_expr)}.#{field_name}"
  end

  defp format_c_value(value) when is_integer(value), do: to_string(value)
  defp format_c_value(value) when is_binary(value), do: "\"#{value}\""
  defp format_c_value(value), do: inspect(value)

  # Private helper functions for Elixir execution

  defp execute_function(ir, function, args) do
    # Bind parameters to arguments
    Enum.zip(function.params, args)
    |> Enum.each(fn {param, arg} ->
      Process.put({:var, param.name}, arg)
    end)

    # Execute function body
    try do
      result = execute_statements(ir, function.body)
      {:ok, result}
    catch
      {:return, value} -> {:ok, value}
    end
  end

  defp execute_statements(_ir, []), do: nil
  defp execute_statements(ir, [stmt | rest]) do
    execute_statement(ir, stmt)
    execute_statements(ir, rest)
  end

  defp execute_statement(_ir, {:return, expr}) do
    value = evaluate_expression(expr)
    throw({:return, value})
  end

  defp execute_statement(_ir, {:assign, var_name, expr}) do
    value = evaluate_expression(expr)
    Process.put({:var, var_name}, value)
  end

  defp execute_statement(ir, {:call, func_name, args}) do
    case func_name do
      "printf" ->
        # Handle printf specially for demo purposes
        evaluated_args = Enum.map(args, &evaluate_expression/1)
        case evaluated_args do
          [format | [_ | _] = values] -> 
            IO.puts(:io_lib.format(to_charlist(format), values))
          [format] -> 
            IO.puts(format)
          [] -> 
            IO.puts("")
        end
      _ ->
        # Try to find and call function from IR
        case Enum.find(ir.functions, &(&1.name == func_name)) do
          nil -> {:error, "Function #{func_name} not found"}
          function ->
            evaluated_args = Enum.map(args, &evaluate_expression/1)
            execute_function(ir, function, evaluated_args)
        end
    end
  end

  defp evaluate_expression({:var, name}) do
    Process.get({:var, name}, 0)
  end

  defp evaluate_expression({:literal, value}), do: value

  defp evaluate_expression({:binary_op, :add, left, right}) do
    evaluate_expression(left) + evaluate_expression(right)
  end

  defp evaluate_expression({:binary_op, :sub, left, right}) do
    evaluate_expression(left) - evaluate_expression(right)
  end

  defp evaluate_expression({:binary_op, :mul, left, right}) do
    evaluate_expression(left) * evaluate_expression(right)
  end

  defp evaluate_expression({:binary_op, :div, left, right}) do
    div(evaluate_expression(left), evaluate_expression(right))
  end

  defp evaluate_expression({:call, func_name, args}) do
    # This is a placeholder - in a real implementation we'd need the IR context
    # For now, return 0 as placeholder
    _ = func_name
    _ = args
    0
  end

  defp evaluate_expression({:struct_new, struct_name, field_inits}) do
    # Create a map representing the struct instance
    field_values = field_inits
    |> Enum.map(fn {field_name, expr} ->
      {field_name, evaluate_expression(expr)}
    end)
    |> Map.new()
    
    %{__struct__: struct_name, __fields__: field_values}
  end

  defp evaluate_expression({:field_access, struct_expr, field_name}) do
    struct_value = evaluate_expression(struct_expr)
    case struct_value do
      %{__fields__: fields} -> Map.get(fields, field_name, 0)
      _ -> 0
    end
  end
end