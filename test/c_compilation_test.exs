defmodule CCompilationTest do
  use ExUnit.Case
  require Frix.Macro
  import Frix.Macro

  @moduletag :c_compilation

  describe "C code compilation" do
    test "generates and compiles C program with struct and function" do
      # Generate C code using the macro
      ir = c_program do
        struct :Point, [x: :int, y: :int]
        struct :Rectangle, [width: :int, height: :int]
        
        var :global_count, :int, 0
        
        function :calculate_area, :int, [width: :int, height: :int] do
          area = width * height
          return area
        end
        
        function :point_sum, :int, [x: :int, y: :int] do
          result = x + y
          return result
        end
        
        function :main, :int do
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
      
      c_code = Frix.IR.to_c_code(ir)
      
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
        
        # Verify output contains expected strings
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
        function :calculate, :int, [a: :int, b: :int] do
          sum = a + b
          product = a * b
          return sum + product
        end
        
        function :main, :int do
          result = calculate(5, 3)
          printf("5 + 3 + (5 * 3) = %d\\n", result)
          return 0
        end
      end
      
      c_code = Frix.IR.to_c_code(ir)
      
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
        
        assert exit_code == 0
        assert output =~ "5 + 3 + (5 * 3) = 23"
        
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
end