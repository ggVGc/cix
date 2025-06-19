defmodule Cix.ElixirVariableTest do
  use ExUnit.Case
  require Cix.Macro
  import Cix.Macro

  describe "Elixir-like let syntax" do
    test "generates IR for simple variable with type annotation" do
      ir = c_program do
        let count :: int = 42
      end

      assert %Cix.IR{} = ir
      assert length(ir.variables) == 1
      [var] = ir.variables
      assert var.name == "count"
      assert var.type == "int"
      assert var.value == {:literal, 42}
      
      c_code = Cix.IR.to_c_code(ir)
      assert c_code =~ "int count = 42;"
    end

    test "generates IR for string variable" do
      ir = c_program do
        let message :: string = "Hello World"
      end

      assert %Cix.IR{} = ir
      [var] = ir.variables
      assert var.name == "message"
      assert var.type == "string"
      assert var.value == {:literal, "Hello World"}
      
      c_code = Cix.IR.to_c_code(ir)
      assert c_code =~ "string message = \"Hello World\";"
    end

    test "generates IR for multiple variables" do
      ir = c_program do
        let x :: int = 10
        let y :: int = 20
        let sum :: int = 30
      end

      assert %Cix.IR{} = ir
      assert length(ir.variables) == 3
      
      c_code = Cix.IR.to_c_code(ir)
      assert c_code =~ "int x = 10;"
      assert c_code =~ "int y = 20;"
      assert c_code =~ "int sum = 30;"
    end

    test "works with function that uses variables" do
      ir = c_program do
        let global_count :: int = 0
        
        defn increment() :: void do
          global_count = global_count + 1
        end
        
        defn main() :: int do
          increment()
          return global_count
        end
      end

      assert %Cix.IR{} = ir
      assert length(ir.variables) == 1
      assert length(ir.functions) == 2
      
      {:ok, result} = Cix.IR.execute(ir, "main")
      assert result == 1
      
      c_code = Cix.IR.to_c_code(ir)
      assert c_code =~ "int global_count = 0;"
      assert c_code =~ "void increment(void) {"
      assert c_code =~ "int main(void) {"
    end

    test "supports complex expressions in variable initialization" do
      ir = c_program do
        let base :: int = 10
        let multiplier :: int = 5
        
        defn calculate() :: int do
          result = base * multiplier
          return result
        end
      end

      {:ok, result} = Cix.IR.execute(ir, "calculate")
      assert result == 50
      
      c_code = Cix.IR.to_c_code(ir)
      assert c_code =~ "int base = 10;"
      assert c_code =~ "int multiplier = 5;"
    end

    test "compiles to valid C code" do
      ir = c_program do
        let width :: int = 10
        let height :: int = 5
        
        defn calculate_area() :: int do
          area = width * height
          return area
        end
        
        defn main() :: int do
          result = calculate_area()
          printf("Area: %d\\n", result)
          return 0
        end
      end
      
      c_code = Cix.IR.to_c_code(ir)
      
      full_c_code = """
      #include <stdio.h>
      
      #{c_code}
      """
      
      temp_dir = System.tmp_dir!()
      c_file = Path.join(temp_dir, "frix_let_test_#{:rand.uniform(10000)}.c")
      binary_file = Path.join(temp_dir, "frix_let_test_#{:rand.uniform(10000)}")
      
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
        
        assert exit_code == 0
        assert output =~ "Area: 50"
        
      after
        File.rm(c_file)
        File.rm(binary_file)
      end
    end
  end

end