# Example demonstrating DSL modules using Elixir's "use" functionality
# Run with: elixir -S mix run examples/dsl_module_example.exs

defmodule CalculatorProgram do
  @moduledoc """
  A program that uses multiple DSL modules to create a comprehensive calculator.
  """
  
  use Cix.DSLModule
  use Cix.DSLModules.MathLib
  use Cix.DSLModules.GeometryLib
  use Cix.DSLModules.IOLib
  
  export_functions [:main]
  
  dsl_content do
    let global_counter :: int = 0
    
    defn perform_math_demo() :: void do
      printf("=== Math Library Demo ===\\n")
      
      # Basic arithmetic
      sum = add(15, 25)
      difference = subtract(50, 20)
      product = multiply(8, 7)
      quotient = divide(100, 4)
      square = power(6, 2)
      
      print_calculation_result(1, 15, 25, sum)
      print_calculation_result(2, 50, 20, difference)
      print_calculation_result(3, 8, 7, product)
      print_calculation_result(4, 100, 4, quotient)
      print_int(square)
    end
    
    defn perform_geometry_demo() :: void do
      printf("=== Geometry Library Demo ===\\n")
      
      # Rectangle calculations
      rect_area = rectangle_area(12, 8)
      rect_perimeter = rectangle_perimeter(12, 8)
      
      printf("Rectangle 12x8: Area = %d, Perimeter = %d\\n", rect_area, rect_perimeter)
      
      # Circle approximation
      circle_area = circle_area_approx(5)
      printf("Circle radius 5: Approximate area = %d\\n", circle_area)
      
      # Cube volume
      cube_vol = cube_volume(4)
      printf("Cube side 4: Volume = %d\\n", cube_vol)
    end
    
    defn perform_combined_demo() :: void do
      printf("=== Combined Operations Demo ===\\n")
      
      # Use functions from multiple libraries
      width = 6
      height = 8
      
      area = rectangle_area(width, height)
      perimeter = rectangle_perimeter(width, height)
      
      # Combine area and perimeter with basic math
      total = add(area, perimeter)
      scaled = multiply(total, 2)
      
      printf("Rectangle %dx%d:\\n", width, height)
      printf("  Area: %d\\n", area)
      printf("  Perimeter: %d\\n", perimeter)
      printf("  Combined (area + perimeter): %d\\n", total)
      printf("  Scaled x2: %d\\n", scaled)
    end
    
    defn increment_counter() :: int do
      global_counter = add(global_counter, 1)
      return global_counter
    end
    
    defn main() :: int do
      printf("=== DSL Module Composition Demo ===\\n\\n")
      
      # Demonstrate math library
      perform_math_demo()
      printf("\\n")
      
      # Demonstrate geometry library
      perform_geometry_demo()
      printf("\\n")
      
      # Demonstrate combined usage
      perform_combined_demo()
      printf("\\n")
      
      # Test counter with imported function
      count1 = increment_counter()
      count2 = increment_counter()
      count3 = increment_counter()
      
      printf("Counter tests: %d, %d, %d\\n", count1, count2, count3)
      
      # Final calculation using all libraries
      final_result = add(multiply(count3, 10), power(5, 2))
      printf("\\nFinal result: %d\\n", final_result)
      
      return final_result
    end
  end
  
  def create_program do
    get_dsl_ir()
  end
end

# Demonstrate the DSL module system
IO.puts "=== DSL Module System Demo ==="

# Create the program IR
program_ir = CalculatorProgram.create_program()

# Show module composition information
IO.puts "\n--- Module Composition Analysis ---"
IO.puts "Imported modules: #{inspect(CalculatorProgram.get_imported_modules())}"
IO.puts "Total functions in IR: #{length(program_ir.functions)}"

function_names = program_ir.functions |> Enum.map(& &1.name) |> Enum.sort()
IO.puts "Functions available: #{Enum.join(function_names, ", ")}"

# Generate and display C code
IO.puts "\n=== Generated C Code ==="
c_code = Cix.IR.to_c_code(program_ir)
IO.puts c_code

# Execute the program
IO.puts "\n=== Elixir Execution ==="
{:ok, result} = Cix.IR.execute(program_ir, "main")
IO.puts "Program returned: #{result}"

# Test individual DSL modules
IO.puts "\n=== Individual DSL Module Testing ==="

IO.puts "\n--- Testing MathLib module ---"
math_ir = Cix.DSLModules.MathLib.get_dsl_ir()
{:ok, add_result} = Cix.IR.execute(math_ir, "add", [20, 30])
{:ok, multiply_result} = Cix.IR.execute(math_ir, "multiply", [7, 9])
IO.puts "MathLib.add(20, 30) = #{add_result}"
IO.puts "MathLib.multiply(7, 9) = #{multiply_result}"

IO.puts "\n--- Testing GeometryLib module (includes MathLib) ---"
geometry_ir = Cix.DSLModules.GeometryLib.get_dsl_ir()
{:ok, area_result} = Cix.IR.execute(geometry_ir, "rectangle_area", [15, 20])
{:ok, volume_result} = Cix.IR.execute(geometry_ir, "cube_volume", [5])
IO.puts "GeometryLib.rectangle_area(15, 20) = #{area_result}"
IO.puts "GeometryLib.cube_volume(5) = #{volume_result}"

# Show validation
IO.puts "\n--- DSL Module Validation ---"
case Cix.DSLModule.validate_dsl_imports(CalculatorProgram) do
  :ok -> IO.puts "✓ All DSL module imports are valid"
  {:error, reason} -> IO.puts "❌ Validation failed: #{reason}"
end

IO.puts "\n=== DSL Module System working perfectly! ==="