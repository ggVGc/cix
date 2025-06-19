defmodule Cix.IR do
  @moduledoc """
  Intermediate Representation (IR) for the Cix DSL.
  
  The IR provides a common format that can be:
  1. Converted to C code
  2. Executed directly in Elixir
  """

  defstruct variables: [], functions: [], structs: [], modules: []

  @type t :: %__MODULE__{
    variables: [variable()],
    functions: [ir_function()],
    structs: [struct_def()],
    modules: [module_def()]
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

  @type module_def :: %{
    name: String.t(),
    exports: [String.t()],
    imports: [module_import()],
    variables: [variable()],
    functions: [ir_function()],
    structs: [struct_def()]
  }

  @type module_import :: %{
    module_name: String.t(),
    functions: [String.t()]
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

  def add_module(ir, name, exports, imports, variables, functions, structs) do
    module_def = %{
      name: name,
      exports: exports,
      imports: imports,
      variables: variables,
      functions: functions,
      structs: structs
    }
    %{ir | modules: [module_def | ir.modules]}
  end

  @doc """
  Merge multiple IR instances into a single IR.
  Functions, variables, and structs are combined.
  """
  def merge(irs) when is_list(irs) do
    Enum.reduce(irs, new(), fn ir, acc ->
      %{acc |
        variables: acc.variables ++ ir.variables,
        functions: acc.functions ++ ir.functions,
        structs: acc.structs ++ ir.structs,
        modules: acc.modules ++ ir.modules
      }
    end)
  end

  def merge(ir1, ir2) do
    merge([ir1, ir2])
  end

  @doc """
  Validate module imports against available exports.
  Returns {:ok, ir} if all imports are satisfied, {:error, reasons} otherwise.
  """
  def validate_imports(%__MODULE__{} = ir) do
    errors = ir.modules
    |> Enum.flat_map(&validate_module_imports(&1, ir.modules))
    
    case errors do
      [] -> {:ok, ir}
      _ -> {:error, errors}
    end
  end
  
  defp validate_module_imports(module, all_modules) do
    module.imports
    |> Enum.flat_map(fn import ->
      validate_import(import, module.name, all_modules)
    end)
  end
  
  defp validate_import(%{module_name: imported_module, functions: imported_functions}, importing_module, all_modules) do
    case Enum.find(all_modules, &(&1.name == imported_module)) do
      nil ->
        ["Module '#{importing_module}' imports from '#{imported_module}' but '#{imported_module}' does not exist"]
      
      target_module ->
        imported_functions
        |> Enum.reject(&(&1 in target_module.exports))
        |> Enum.map(fn func ->
          "Module '#{importing_module}' imports function '#{func}' from '#{imported_module}' but '#{func}' is not exported"
        end)
    end
  end

  @doc """
  Convert IR to C code.
  """
  def to_c_code(%__MODULE__{} = ir) do
    # Generate module code if modules exist, otherwise generate flat code
    if Enum.empty?(ir.modules) do
      structs_code = generate_c_structs(ir.structs)
      variables_code = generate_c_variables(ir.variables)
      functions_code = generate_c_functions(ir.functions, ir.variables)
      
      [structs_code, variables_code, functions_code]
      |> Enum.reject(&(&1 == ""))
      |> Enum.join("\n\n")
    else
      generate_c_modules(ir)
    end
  end

  @doc """
  Execute IR directly in Elixir.
  """
  def execute(%__MODULE__{} = ir, function_name \\ "main", args \\ []) do
    # Store IR context in process dictionary for function calls
    Process.put(:current_ir, ir)
    
    # Initialize global variables in process dictionary
    Enum.each(ir.variables, fn var ->
      value = case var.value do
        {:literal, literal_value} -> literal_value
        expr -> evaluate_expression(expr)
      end
      Process.put({:var, var.name}, value)
    end)

    # Initialize module variables
    Enum.each(ir.modules, fn module ->
      Enum.each(module.variables, fn var ->
        value = case var.value do
          {:literal, literal_value} -> literal_value
          expr -> evaluate_expression(expr)
        end
        Process.put({:var, var.name}, value)
      end)
    end)

    # Store struct definitions for runtime use
    Enum.each(ir.structs, fn struct_def ->
      Process.put({:struct_def, struct_def.name}, struct_def)
    end)
    
    # Store module struct definitions
    Enum.each(ir.modules, fn module ->
      Enum.each(module.structs, fn struct_def ->
        Process.put({:struct_def, struct_def.name}, struct_def)
      end)
    end)

    # Find and execute function - check global functions first, then modules
    result = case find_function(ir, function_name) do
      nil -> {:error, "Function #{function_name} not found"}
      function -> execute_function(ir, function, args)
    end
    
    # Clean up process dictionary
    Process.delete(:current_ir)
    result
  end
  
  defp find_function(ir, function_name) do
    # Check global functions first
    case Enum.find(ir.functions, &(&1.name == function_name)) do
      nil ->
        # Check module functions
        ir.modules
        |> Enum.flat_map(& &1.functions)
        |> Enum.find(&(&1.name == function_name))
      function -> function
    end
  end

  # Private helper functions for C code generation

  defp generate_c_modules(ir) do
    # Generate header declarations for all exported functions
    headers = generate_module_headers(ir.modules)
    
    # Generate implementation for all modules
    implementations = ir.modules
    |> Enum.reverse()
    |> Enum.map(&generate_c_module/1)
    |> Enum.join("\n\n")
    
    [headers, implementations]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  defp generate_module_headers(modules) do
    modules
    |> Enum.flat_map(&generate_module_header/1)
    |> Enum.join("\n")
  end

  defp generate_module_header(module) do
    # Generate forward declarations for exported functions
    module.functions
    |> Enum.filter(&(&1.name in module.exports))
    |> Enum.map(fn func ->
      params_str = generate_c_params(func.params)
      "#{func.return_type} #{func.name}(#{params_str});"
    end)
  end

  defp generate_c_module(module) do
    comment = "// Module: #{module.name}"
    structs_code = generate_c_structs(module.structs)
    variables_code = generate_c_variables(module.variables)
    functions_code = generate_c_functions(module.functions, module.variables)
    
    [comment, structs_code, variables_code, functions_code]
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

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
        # Handle printf specially for demo purposes - simplified version
        evaluated_args = Enum.map(args, &evaluate_expression/1)
        case evaluated_args do
          [format | [_ | _] = values] -> 
            # For testing purposes, just use Elixir's printf-like formatting
            try do
              # Convert C format specifiers to Elixir format
              elixir_format = String.replace(format, ~r/%[dld]/, "~w")
              |> String.replace("\\n", "\n")
              IO.puts(:io_lib.format(to_charlist(elixir_format), values))
            rescue
              _ ->
                # Fallback: just print format and values
                IO.puts("#{format} [#{Enum.join(values, ", ")}]")
            end
          [format] -> 
            formatted = String.replace(format, "\\n", "\n")
            IO.puts(formatted)
          [] -> 
            IO.puts("")
        end
      _ ->
        # Try to find and call function from IR
        case find_function(ir, func_name) do
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
    # Get the IR context from the process dictionary
    case Process.get(:current_ir) do
      nil -> 0  # Fallback if no IR context available
      ir ->
        case find_function(ir, func_name) do
          nil -> 0  # Function not found
          function ->
            evaluated_args = Enum.map(args, &evaluate_expression/1)
            case execute_function(ir, function, evaluated_args) do
              {:ok, result} -> result
              _ -> 0
            end
        end
    end
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