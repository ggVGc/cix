# Simple DSL Module System Example
# Run with: elixir -S mix run examples/simple_dsl_module_example.exs

# Simple math library DSL module
defmodule SimpleMathLib do
  use Cix.DSLModule
  
  def get_dsl_exports, do: [:simple_add, :simple_multiply]
  
  def get_dsl_functions do
    import Cix.Macro
    
    [
      quote do
        defn simple_add(x :: int, y :: int) :: int do
          return x + y
        end
      end,
      quote do
        defn simple_multiply(x :: int, y :: int) :: int do
          return x * y
        end
      end
    ]
  end
end

# Program that uses the math library
defmodule SimpleProgram do
  use Cix.DSLModule
  use SimpleMathLib
  
  def get_dsl_exports, do: [:main]
  
  def get_dsl_functions do
    import Cix.Macro
    
    [
      quote do
        defn main() :: int do
          sum = simple_add(10, 20)
          product = simple_multiply(sum, 2)
          printf("Sum: %d, Product: %d\\n", sum, product)
          return product
        end
      end
    ]
  end
end

IO.puts "=== Simple DSL Module System Demo ==="

# Test that SimpleMathLib works on its own
IO.puts "\n--- Testing SimpleMathLib module ---"
math_ir = SimpleMathLib.create_ir()
{:ok, add_result} = Cix.IR.execute(math_ir, "simple_add", [15, 25])
{:ok, multiply_result} = Cix.IR.execute(math_ir, "simple_multiply", [6, 7])
IO.puts "SimpleMathLib.simple_add(15, 25) = #{add_result}"
IO.puts "SimpleMathLib.simple_multiply(6, 7) = #{multiply_result}"

# Test module composition
IO.puts "\n--- Testing SimpleProgram (uses SimpleMathLib) ---"
IO.puts "Imported modules: #{inspect(SimpleProgram.get_imported_modules())}"

program_ir = SimpleProgram.create_ir()
function_names = program_ir.functions |> Enum.map(& &1.name) |> Enum.sort()
IO.puts "Available functions: #{Enum.join(function_names, ", ")}"

# Execute the complete program
IO.puts "\n--- Program Execution ---"
{:ok, result} = Cix.IR.execute(program_ir, "main")
IO.puts "Program returned: #{result}"

# Generate C code
IO.puts "\n--- Generated C Code ---"
c_code = Cix.IR.to_c_code(program_ir)
IO.puts c_code

# Validation
IO.puts "\n--- Module Validation ---"
case Cix.DSLModule.validate_dsl_imports(SimpleProgram) do
  :ok -> IO.puts "✓ All module imports are valid"
  {:error, reason} -> IO.puts "❌ Validation failed: #{reason}"
end

IO.puts "\n=== DSL Module System working! ==="