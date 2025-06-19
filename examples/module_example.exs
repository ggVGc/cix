# Example program demonstrating two Elixir modules using the Cix macro-based DSL
# Run with: elixir -S mix run examples/module_example.exs

defmodule MathUtils do
  @moduledoc """
  Math utilities module that generates C functions for basic arithmetic operations.
  """

  import Cix.Macro

  def create_ir do
    c_program do
      defn add(x :: int, y :: int) :: int do
        return x + y
      end

      defn multiply(x :: int, y :: int) :: int do
        return x * y
      end

      defn power(base :: int, exponent :: int) :: int do
        # Simple power function for demonstration (base^2 only)
        result = multiply(base, base)
        return result
      end
    end
  end
end

defmodule MainProgram do
  @moduledoc """
  Main program module that uses math utilities and creates a complete C program.
  This module depends on MathUtils and uses its functions.
  """

  import Cix.Macro

  def create_ir(math_utils_ir) do
    # Create main program IR that references functions from MathUtils
    main_ir = c_program do
      let global_counter :: int = 0

      defn calculate_area(width :: int, height :: int) :: int do
        area = multiply(width, height)
        return area
      end

      defn calculate_volume(length :: int, width :: int, height :: int) :: int do
        base_area = multiply(length, width)
        volume = multiply(base_area, height)
        return volume
      end

      defn demonstrate_power() :: void do
        base = 2
        exp = 3
        result = power(base, exp)
        printf("2^2 = %d\\n", result)
      end

      defn main() :: int do
        printf("=== Module Interaction Demo ===\\n")

        # Test basic arithmetic from math_utils
        sum = add(10, 5)
        product = multiply(6, 7)
        printf("10 + 5 = %d\\n", sum)
        printf("6 * 7 = %d\\n", product)

        # Test composite functions using math_utils functions
        area = calculate_area(8, 6)
        volume = calculate_volume(4, 5, 3)
        printf("Area (8x6) = %d\\n", area)
        printf("Volume (4x5x3) = %d\\n", volume)

        # Test power function
        demonstrate_power()

        # Test global variable increment using add function
        global_counter = add(global_counter, 1)
        global_counter = add(global_counter, 4)
        printf("Final counter: %d\\n", global_counter)

        return 0
      end
    end
    
    # Merge with MathUtils IR to create complete program
    Cix.IR.merge(math_utils_ir, main_ir)
  end
  
  # Convenience function for standalone use (without dependencies)
  def create_ir do
    create_ir(MathUtils.create_ir())
  end
end

defmodule ExampleRunner do
  @moduledoc """
  Demonstrates how MainProgram uses MathUtils module through proper composition.
  """

  def run do
    # Create math utilities IR first
    math_ir = MathUtils.create_ir()
    
    # MainProgram now uses MathUtils by taking it as a dependency
    combined_ir = MainProgram.create_ir(math_ir)

    # Generate and display C code
    IO.puts "=== Generated C Code ==="
    IO.puts Cix.IR.to_c_code(combined_ir)

    IO.puts "\n=== Elixir Execution ==="
    # Execute the program directly in Elixir
    {:ok, result} = Cix.IR.execute(combined_ir, "main")
    IO.puts "Program returned: #{result}"

    # Demonstrate the individual modules and their relationship
    IO.puts "\n=== Module Composition Demo ==="

    IO.puts "\n--- Testing standalone MathUtils module ---"
    {:ok, add_result} = Cix.IR.execute(math_ir, "add", [15, 25])
    IO.puts "MathUtils.add(15, 25) = #{add_result}"

    {:ok, mult_result} = Cix.IR.execute(math_ir, "multiply", [7, 8])
    IO.puts "MathUtils.multiply(7, 8) = #{mult_result}"

    {:ok, power_result} = Cix.IR.execute(math_ir, "power", [3, 2])
    IO.puts "MathUtils.power(3, 2) = #{power_result}"

    IO.puts "\n--- Testing MainProgram functions that use MathUtils ---"
    {:ok, area_result} = Cix.IR.execute(combined_ir, "calculate_area", [12, 8])
    IO.puts "MainProgram.calculate_area(12, 8) = #{area_result}"

    {:ok, volume_result} = Cix.IR.execute(combined_ir, "calculate_volume", [3, 4, 5])
    IO.puts "MainProgram.calculate_volume(3, 4, 5) = #{volume_result}"

    IO.puts "\n--- Module composition statistics ---"
    IO.puts "MathUtils functions: #{length(math_ir.functions)} (#{math_ir.functions |> Enum.map(& &1.name) |> Enum.join(", ")})"
    
    main_only_functions = combined_ir.functions 
    |> Enum.reject(&(&1.name in ["add", "multiply", "power"]))
    |> Enum.map(& &1.name)
    
    IO.puts "MainProgram functions: #{length(main_only_functions)} (#{Enum.join(main_only_functions, ", ")})"
    IO.puts "Combined total functions: #{length(combined_ir.functions)}"
    IO.puts "Combined total variables: #{length(combined_ir.variables)}"
    
    IO.puts "\n--- Dependency relationship ---"
    IO.puts "✓ MainProgram depends on MathUtils"
    IO.puts "✓ MainProgram.create_ir/1 takes MathUtils IR as parameter"
    IO.puts "✓ Combined IR merges both modules automatically"
    IO.puts "✓ All functions work together in the final C program"
  end
end

ExampleRunner.run()
