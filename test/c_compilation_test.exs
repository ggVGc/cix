defmodule CCompilationTest do
  use ExUnit.Case
  require Cix.Macro
  import Cix.Macro

  @moduletag :c_compilation

  describe "C code compilation" do
    test "generates and compiles C program with struct and function" do
      # Generate C code using the macro
      ir = c_program do
        struct :Point, [x: :int, y: :int]
        struct :Rectangle, [width: :int, height: :int]
        
        let global_count :: int = 0
        
        defn calculate_area(width :: int, height :: int) :: int do
          area = width * height
          return area
        end
        
        defn point_sum(x :: int, y :: int) :: int do
          result = x + y
          return result
        end
        
        defn main() :: int do
          width = 10
          height = 5
          area = calculate_area(width, height)
          
          point_x = 3
          point_y = 4
          sum = point_sum(point_x, point_y)
          
          printf("Rectangle area: %d x %d = %d\\n", width, height, area)
          printf("Point sum: %d + %d = %d\\n", point_x, point_y, sum)
          
          global_count = global_count + 1
          printf("Global count: %d\\n", global_count)
          
          return 0
        end
      end
      
      c_code = Cix.IR.to_c_code(ir)
      
      # Add necessary includes
      full_c_code = """
      #include <stdio.h>
      
      #{c_code}
      """
      
      # Write to temporary file
      temp_dir = System.tmp_dir!()
      c_file = Path.join(temp_dir, "frix_test_#{:rand.uniform(10000)}.c")
      binary_file = Path.join(temp_dir, "frix_test_#{:rand.uniform(10000)}")
      
      try do
        File.write!(c_file, full_c_code)
        
        # Compile with gcc
        {result, exit_code} = System.cmd("gcc", [
          "-o", binary_file,
          c_file,
          "-std=c99"  # Enable C99 for compound literals
        ], stderr_to_stdout: true)
        
        if exit_code != 0 do
          IO.puts("Generated C code:")
          IO.puts(full_c_code)
          IO.puts("Compiler output:")
          IO.puts(result)
          flunk("C compilation failed with exit code #{exit_code}")
        end
        
        # Execute the compiled program
        {output, exit_code} = System.cmd(binary_file, [], stderr_to_stdout: true)
        
        assert exit_code == 0, "Program execution failed with exit code #{exit_code}"
        
        # Uncomment for debugging:
        # IO.puts("=== Generated C code ===")
        # IO.puts(full_c_code)
        # IO.puts("=== Program output ===")
        # IO.puts(output)
        # IO.puts("========================")
        
        # Execute the same IR in Elixir for comparison
        {:ok, elixir_result} = Cix.IR.execute(ir, "main")
        
        # Both should return 0 (success)
        assert exit_code == 0
        assert elixir_result == 0
        
        # Test individual functions return same values in both environments
        {:ok, area_result} = Cix.IR.execute(ir, "calculate_area", [10, 5])
        assert area_result == 50
        
        {:ok, sum_result} = Cix.IR.execute(ir, "point_sum", [3, 4])
        assert sum_result == 7
        
        # Verify C program output contains expected strings
        assert output =~ "Rectangle area: 10 x 5 = 50"
        assert output =~ "Point sum: 3 + 4 = 7"
        assert output =~ "Global count: 1"
        
      after
        # Cleanup
        File.rm(c_file)
        File.rm(binary_file)
      end
    end

    test "compiles simple arithmetic program" do
      ir = c_program do
        defn calculate(a :: int, b :: int) :: int do
          sum = a + b
          product = a * b
          return sum + product
        end
        
        defn main() :: int do
          result = calculate(5, 3)
          printf("5 + 3 + (5 * 3) = %d\\n", result)
          return 0
        end
      end
      
      c_code = Cix.IR.to_c_code(ir)
      
      full_c_code = """
      #include <stdio.h>
      
      #{c_code}
      """
      
      temp_dir = System.tmp_dir!()
      c_file = Path.join(temp_dir, "frix_simple_#{:rand.uniform(10000)}.c")
      binary_file = Path.join(temp_dir, "frix_simple_#{:rand.uniform(10000)}")
      
      try do
        File.write!(c_file, full_c_code)
        
        {result, exit_code} = System.cmd("gcc", ["-o", binary_file, c_file], stderr_to_stdout: true)
        
        if exit_code != 0 do
          IO.puts("Generated C code:")
          IO.puts(full_c_code)
          IO.puts("Compiler output:")
          IO.puts(result)
          flunk("C compilation failed")
        end
        
        {output, exit_code} = System.cmd(binary_file, [])
        
        # Execute the same IR in Elixir for comparison
        {:ok, elixir_result} = Cix.IR.execute(ir, "main")
        
        # Both should return 0 (success)
        assert exit_code == 0
        assert elixir_result == 0
        
        # Verify calculation matches expected result
        assert output =~ "5 + 3 + (5 * 3) = 23"
        
        # Test the function directly in Elixir
        {:ok, calc_result} = Cix.IR.execute(ir, "calculate", [5, 3])
        assert calc_result == 23  # 5+3 + 5*3 = 8 + 15 = 23
        
      after
        File.rm(c_file)
        File.rm(binary_file)
      end
    end

    test "skips compilation test if gcc not available" do
      case System.cmd("gcc", ["--version"], stderr_to_stdout: true) do
        {_, 0} -> 
          # gcc is available, test will run normally
          :ok
        _ -> 
          # gcc not available, skip test
          ExUnit.configure(exclude: [:c_compilation])
          :ok
      end
    end
  end

  describe "C compilation with IR execution comparison" do
    test "compiles and compares simple variables" do
      ir = c_program do
        let count :: int = 42
        let max_size :: long = 1024
        
        defn main() :: int do
          printf("Count: %d, Max size: %ld\\n", count, max_size)
          return 0
        end
      end
      
      c_code = Cix.IR.to_c_code(ir)
      
      full_c_code = """
      #include <stdio.h>
      
      #{c_code}
      """
      
      temp_dir = System.tmp_dir!()
      c_file = Path.join(temp_dir, "frix_variables_#{:rand.uniform(10000)}.c")
      binary_file = Path.join(temp_dir, "frix_variables_#{:rand.uniform(10000)}")
      
      try do
        File.write!(c_file, full_c_code)
        
        {result, exit_code} = System.cmd("gcc", [
          "-o", binary_file,
          c_file,
          "-std=c99"
        ], stderr_to_stdout: true)
        
        if exit_code != 0 do
          IO.puts("Generated C code:")
          IO.puts(full_c_code)
          IO.puts("Compiler output:")
          IO.puts(result)
          flunk("C compilation failed with exit code #{exit_code}")
        end
        
        {output, exit_code} = System.cmd(binary_file, [], stderr_to_stdout: true)
        
        # Execute the same IR in Elixir for comparison
        {:ok, elixir_result} = Cix.IR.execute(ir, "main")
        
        # Both should return 0 (success)
        assert exit_code == 0
        assert elixir_result == 0
        
        # Verify output contains expected values
        assert output =~ "Count: 42, Max size: 1024"
        
      after
        File.rm(c_file)
        File.rm(binary_file)
      end
    end

    test "compiles and compares function with parameters" do
      ir = c_program do
        defn add(x :: int, y :: int) :: int do
          return x + y
        end
        
        defn main() :: int do
          result = add(15, 27)
          printf("15 + 27 = %d\\n", result)
          return 0
        end
      end
      
      c_code = Cix.IR.to_c_code(ir)
      
      full_c_code = """
      #include <stdio.h>
      
      #{c_code}
      """
      
      temp_dir = System.tmp_dir!()
      c_file = Path.join(temp_dir, "frix_params_#{:rand.uniform(10000)}.c")
      binary_file = Path.join(temp_dir, "frix_params_#{:rand.uniform(10000)}")
      
      try do
        File.write!(c_file, full_c_code)
        
        {result, exit_code} = System.cmd("gcc", ["-o", binary_file, c_file], stderr_to_stdout: true)
        
        if exit_code != 0 do
          IO.puts("Generated C code:")
          IO.puts(full_c_code)
          IO.puts("Compiler output:")
          IO.puts(result)
          flunk("C compilation failed")
        end
        
        {output, exit_code} = System.cmd(binary_file, [])
        
        # Execute the same IR in Elixir for comparison
        {:ok, elixir_result} = Cix.IR.execute(ir, "main")
        
        # Both should return 0 (success)
        assert exit_code == 0
        assert elixir_result == 0
        
        # Test the add function directly in both environments
        {:ok, add_result} = Cix.IR.execute(ir, "add", [15, 27])
        assert add_result == 42
        
        # Verify C program output
        assert output =~ "15 + 27 = 42"
        
      after
        File.rm(c_file)
        File.rm(binary_file)
      end
    end

    test "compiles and compares arithmetic expressions" do
      ir = c_program do
        defn math_ops(a :: int, b :: int) :: int do
          sum = a + b
          diff = a - b
          product = a * b
          quotient = a / b
          return sum + diff + product + quotient
        end
        
        defn main() :: int do
          result = math_ops(10, 2)
          printf("Math result: %d\\n", result)
          return 0
        end
      end
      
      c_code = Cix.IR.to_c_code(ir)
      
      full_c_code = """
      #include <stdio.h>
      
      #{c_code}
      """
      
      temp_dir = System.tmp_dir!()
      c_file = Path.join(temp_dir, "frix_math_#{:rand.uniform(10000)}.c")
      binary_file = Path.join(temp_dir, "frix_math_#{:rand.uniform(10000)}")
      
      try do
        File.write!(c_file, full_c_code)
        
        {result, exit_code} = System.cmd("gcc", ["-o", binary_file, c_file], stderr_to_stdout: true)
        
        if exit_code != 0 do
          IO.puts("Generated C code:")
          IO.puts(full_c_code)
          IO.puts("Compiler output:")
          IO.puts(result)
          flunk("C compilation failed")
        end
        
        {output, exit_code} = System.cmd(binary_file, [])
        
        # Execute the same IR in Elixir for comparison
        {:ok, elixir_main_result} = Cix.IR.execute(ir, "main")
        {:ok, elixir_math_result} = Cix.IR.execute(ir, "math_ops", [10, 2])
        
        # Both should return 0 for main function
        assert exit_code == 0
        assert elixir_main_result == 0
        
        # Math function should return same result in both environments
        # 10+2 + 10-2 + 10*2 + 10/2 = 12 + 8 + 20 + 5 = 45
        assert elixir_math_result == 45
        assert output =~ "Math result: 45"
        
      after
        File.rm(c_file)
        File.rm(binary_file)
      end
    end

    test "compiles and compares complete program with global variables" do
      ir = c_program do
        let global_counter :: int = 0
        
        defn increment() :: void do
          global_counter = global_counter + 1
        end
        
        defn get_counter() :: int do
          return global_counter
        end
        
        defn main() :: int do
          increment()
          current = get_counter()
          printf("Counter: %d\\n", current)
          return 0
        end
      end
      
      c_code = Cix.IR.to_c_code(ir)
      
      full_c_code = """
      #include <stdio.h>
      
      #{c_code}
      """
      
      temp_dir = System.tmp_dir!()
      c_file = Path.join(temp_dir, "frix_global_#{:rand.uniform(10000)}.c")
      binary_file = Path.join(temp_dir, "frix_global_#{:rand.uniform(10000)}")
      
      try do
        File.write!(c_file, full_c_code)
        
        {result, exit_code} = System.cmd("gcc", ["-o", binary_file, c_file, "-std=c99"], stderr_to_stdout: true)
        
        if exit_code != 0 do
          IO.puts("Generated C code:")
          IO.puts(full_c_code)
          IO.puts("Compiler output:")
          IO.puts(result)
          flunk("C compilation failed")
        end
        
        {output, exit_code} = System.cmd(binary_file, [])
        
        # Execute the same IR in Elixir for comparison
        {:ok, elixir_result} = Cix.IR.execute(ir, "main")
        
        # Both should return 0 (success)
        assert exit_code == 0
        assert elixir_result == 0
        
        # Test individual functions in Elixir
        {:ok, counter_before} = Cix.IR.execute(ir, "get_counter")
        assert counter_before == 0
        
        # Note: Each execution creates a fresh environment in Elixir
        # So we need to test the complete flow
        {:ok, _} = Cix.IR.execute(ir, "increment")
        
        # Verify C program output
        assert output =~ "Counter: 1"
        
      after
        File.rm(c_file)
        File.rm(binary_file)
      end
    end
  end
end
