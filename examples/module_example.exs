# Example program demonstrating two modules using the Cix macro-based DSL
# Run with: elixir -S mix run examples/module_example.exs

defmodule ExampleRunner do
  def run do
    import Cix.Macro

    # Create a program with two interconnected modules  
    ir = c_program do
  # Math utilities module - provides basic arithmetic functions
  c_module :math_utils, exports: [:add, :multiply, :power] do
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
  
  # Main module - uses functions from math_utils
  c_module :main, imports: [math_utils: [:add, :multiply, :power]] do
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
end

    # Generate and display C code
    IO.puts "=== Generated C Code ==="
    IO.puts Cix.IR.to_c_code(ir)

    IO.puts "\n=== Elixir Execution ==="
    # Execute the program directly in Elixir
    {:ok, result} = Cix.IR.execute(ir, "main")
    IO.puts "Program returned: #{result}"
  end
end

ExampleRunner.run()