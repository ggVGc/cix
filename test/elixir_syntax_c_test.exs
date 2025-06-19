defmodule ElixirSyntaxCTest do
  use ExUnit.Case
  require Frix.Macro
  import Frix.Macro

  @moduletag :c_compilation

  describe "Elixir-like syntax C compilation" do
    test "compiles program with new defn syntax" do
      ir = c_program do
        struct :Point, [x: :int, y: :int]
        
        let global_value :: int = 100
        
        defn add_numbers(a :: int, b :: int) :: int do
          sum = a + b
          return sum
        end
        
        defn calculate_distance(x1 :: int, y1 :: int, x2 :: int, y2 :: int) :: int do
          dx = x2 - x1
          dy = y2 - y1
          distance = dx + dy  # Simple Manhattan distance
          return distance
        end
        
        defn main() :: int do
          sum = add_numbers(5, 7)
          distance = calculate_distance(0, 0, 3, 4)
          
          printf("Sum: %d\\n", sum)
          printf("Distance: %d\\n", distance)
          printf("Global value: %d\\n", global_value)
          
          return 0
        end
      end
      
      c_code = Frix.IR.to_c_code(ir)
      
      full_c_code = """
      #include <stdio.h>
      
      #{c_code}
      """
      
      temp_dir = System.tmp_dir!()
      c_file = Path.join(temp_dir, "frix_elixir_syntax_#{:rand.uniform(10000)}.c")
      binary_file = Path.join(temp_dir, "frix_elixir_syntax_#{:rand.uniform(10000)}")
      
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
        
        assert exit_code == 0, "Program execution failed with exit code #{exit_code}"
        
        # Verify output
        assert output =~ "Sum: 12"
        assert output =~ "Distance: 7"
        assert output =~ "Global value: 100"
        
        # Verify generated C code has proper syntax
        assert c_code =~ "int add_numbers(int a, int b) {"
        assert c_code =~ "int calculate_distance(int x1, int y1, int x2, int y2) {"
        assert c_code =~ "int main(void) {"
        
      after
        File.rm(c_file)
        File.rm(binary_file)
      end
    end

    test "multiple functions compile correctly" do
      ir = c_program do
        let counter :: int = 0
        
        defn double_value(x :: int) :: int do
          return x * 2
        end
        
        defn triple_value(y :: int) :: int do
          return y * 3
        end
        
        defn main() :: int do
          doubled = double_value(5)
          tripled = triple_value(4)
          total = doubled + tripled
          
          printf("Doubled: %d, Tripled: %d, Total: %d\\n", doubled, tripled, total)
          return 0
        end
      end
      
      c_code = Frix.IR.to_c_code(ir)
      
      full_c_code = """
      #include <stdio.h>
      
      #{c_code}
      """
      
      temp_dir = System.tmp_dir!()
      c_file = Path.join(temp_dir, "frix_multiple_#{:rand.uniform(10000)}.c")
      binary_file = Path.join(temp_dir, "frix_multiple_#{:rand.uniform(10000)}")
      
      try do
        File.write!(c_file, full_c_code)
        
        {result, exit_code} = System.cmd("gcc", ["-o", binary_file, c_file], stderr_to_stdout: true)
        
        if exit_code != 0 do
          IO.puts("Generated C code:")
          IO.puts(full_c_code)
          flunk("C compilation failed")
        end
        
        {output, exit_code} = System.cmd(binary_file, [])
        
        assert exit_code == 0
        assert output =~ "Doubled: 10, Tripled: 12, Total: 22"
        
      after
        File.rm(c_file)
        File.rm(binary_file)
      end
    end
  end
end