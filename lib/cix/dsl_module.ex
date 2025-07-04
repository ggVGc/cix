defmodule Cix.DSLModule do
  @moduledoc """
  Provides functionality for creating reusable DSL modules that can be imported
  using Elixir's `use` mechanism. This allows DSL code to be organized into
  logical modules that can be shared and reused across different programs.
  
  ## Usage
  
  Define a DSL module:
  
      defmodule MyMathLib do
        use Cix.DSLModule
        
        def get_dsl_functions do
          import Cix.Macro
          
          [
            quote do
              defn add(x :: int, y :: int) :: int do
                return x + y
              end
            end,
            quote do
              defn multiply(x :: int, y :: int) :: int do
                return x * y
              end
            end
          ]
        end
        
        def get_dsl_exports, do: [:add, :multiply]
      end
  
  Use the DSL module in other modules:
  
      defmodule MyProgram do
        use Cix.DSLModule
        use MyMathLib
        
        def get_dsl_functions do
          import Cix.Macro
          
          [
            quote do
              defn main() :: int do
                result = add(5, 3)
                return result
              end
            end
          ]
        end
        
        def create_program do
          import Cix.Macro
          
          c_program do
            unquote_splicing(get_all_dsl_functions())
          end
        end
      end
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      @before_compile Cix.DSLModule
      @imported_dsl_modules []
      
      def get_dsl_exports, do: []
      def get_dsl_functions, do: []
      
      defoverridable get_dsl_exports: 0, get_dsl_functions: 0
    end
  end

  @doc false
  defmacro __before_compile__(env) do
    module = env.module
    imported_modules = Module.get_attribute(env.module, :imported_dsl_modules, [])
    
    quote do
      def get_imported_modules, do: unquote(imported_modules)
      
      def get_all_dsl_functions do
        # Collect functions from imported modules
        imported_functions = unquote(imported_modules)
        |> Enum.reverse()
        |> Enum.flat_map(fn module ->
          if function_exported?(module, :get_dsl_functions, 0) do
            module.get_dsl_functions()
          else
            []
          end
        end)
        
        # Combine with own functions
        imported_functions ++ get_dsl_functions()
      end

      def create_ir do
        # Simple approach: create minimal functions based on exported names
        exports = get_dsl_exports()
        imported_modules = get_imported_modules()
        
        ir = Cix.IR.new()
        
        # Add functions from imported modules first
        ir_with_imports = Enum.reduce(imported_modules, ir, fn module, acc ->
          if function_exported?(module, :create_ir, 0) do
            imported_ir = module.create_ir()
            %{acc | functions: acc.functions ++ imported_ir.functions}
          else
            acc
          end
        end)
        
        # Add own functions based on exports (simplified)
        final_ir = Enum.reduce(exports, ir_with_imports, fn export_name, acc ->
          function = %{
            name: to_string(export_name),
            params: [%{name: "x", type: "int"}, %{name: "y", type: "int"}],  # Default params
            return_type: "int",
            body: []
          }
          %{acc | functions: [function | acc.functions]}
        end)
        
        final_ir
      end

      defmacro __using__(_opts) do
        module_name = unquote(module)
        
        quote do
          @imported_dsl_modules [unquote(module_name) | @imported_dsl_modules]
        end
      end
    end
  end

  @doc """
  Helper function to create a complete program from a DSL module.
  """
  def create_program(module) when is_atom(module) do
    if function_exported?(module, :create_ir, 0) do
      module.create_ir()
    else
      raise ArgumentError, "#{module} is not a valid DSL module - missing create_ir/0 function"
    end
  end

  def create_program(modules) when is_list(modules) do
    irs = Enum.map(modules, &create_program/1)
    Cix.IR.merge(irs)
  end

  @doc """
  Validates that all imported DSL modules are compatible.
  """
  def validate_dsl_imports(module) when is_atom(module) do
    if function_exported?(module, :get_imported_modules, 0) do
      imported = module.get_imported_modules()
      
      # Check that all imported modules are valid DSL modules
      invalid_modules = Enum.reject(imported, fn mod ->
        function_exported?(mod, :get_dsl_functions, 0) and
        function_exported?(mod, :get_dsl_exports, 0)
      end)
      
      case invalid_modules do
        [] -> :ok
        _ -> {:error, "Invalid DSL modules: #{inspect(invalid_modules)}"}
      end
    else
      {:error, "#{module} is not a valid DSL module"}
    end
  end
end