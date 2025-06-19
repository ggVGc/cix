defmodule Cix.ElixirSyntaxTest do
  use ExUnit.Case
  require Cix.Macro
  import Cix.Macro

  describe "Elixir-like defn syntax" do
    test "generates IR for function with typed parameters" do
      ir = c_program do
        defn add(x :: int, y :: int) :: int do
          return x + y
        end
      end

      assert %Cix.IR{} = ir
      assert length(ir.functions) == 1
      [func] = ir.functions
      assert func.name == "add"
      assert func.return_type == "int"
      assert length(func.params) == 2
      
      c_code = Cix.IR.to_c_code(ir)
      assert c_code =~ "int add(int x, int y) {"
      assert c_code =~ "    return x + y;"
    end

    test "generates IR for function without parameters" do
      ir = c_program do
        defn get_answer() :: int do
          return 42
        end
      end

      assert %Cix.IR{} = ir
      [func] = ir.functions
      assert func.name == "get_answer"
      assert func.return_type == "int"
      assert func.params == []
      
      c_code = Cix.IR.to_c_code(ir)
      assert c_code =~ "int get_answer(void) {"
      assert c_code =~ "    return 42;"
    end

    test "generates complete program with new syntax" do
      ir = c_program do
        let count :: int = 0
        
        defn increment() :: void do
          count = count + 1
        end
        
        defn get_count() :: int do
          return count
        end
        
        defn main() :: int do
          increment()
          result = get_count()
          printf("Count: %d\\n", result)
          return 0
        end
      end

      assert %Cix.IR{} = ir
      assert length(ir.variables) == 1
      assert length(ir.functions) == 3
      
      c_code = Cix.IR.to_c_code(ir)
      assert c_code =~ "int count = 0;"
      assert c_code =~ "void increment(void) {"
      assert c_code =~ "int get_count(void) {"
      assert c_code =~ "int main(void) {"
      assert c_code =~ "increment();"
      assert c_code =~ "result = get_count();"
    end

    test "can execute new syntax in Elixir" do
      ir = c_program do
        let value :: int = 10
        
        defn double(x :: int) :: int do
          return x * 2
        end
        
        defn main() :: int do
          result = double(value)
          return result
        end
      end

      {:ok, result} = Cix.IR.execute(ir, "main")
      assert result == 20
    end

    test "handles complex function with new syntax" do
      ir = c_program do
        defn calculate(a :: int, b :: int, c :: int) :: int do
          sum = a + b
          product = sum * c
          return product
        end
        
        defn main() :: int do
          result = calculate(5, 3, 2)
          return result
        end
      end

      {:ok, result} = Cix.IR.execute(ir, "main")
      # (5 + 3) * 2 = 16
      assert result == 16
      
      c_code = Cix.IR.to_c_code(ir)
      assert c_code =~ "int calculate(int a, int b, int c) {"
      assert c_code =~ "sum = a + b;"
      assert c_code =~ "product = sum * c;"
      assert c_code =~ "return product;"
    end
  end

  describe "multiple functions compatibility" do
    test "multiple defn functions work together" do
      ir = c_program do
        let counter :: int = 0
        
        defn increment_by_one() :: void do
          counter = counter + 1
        end
        
        defn increment_by_two() :: void do
          counter = counter + 2
        end
        
        defn main() :: int do
          increment_by_one()
          increment_by_two()
          return counter
        end
      end

      {:ok, result} = Cix.IR.execute(ir, "main")
      assert result == 3
      
      c_code = Cix.IR.to_c_code(ir)
      assert c_code =~ "void increment_by_one(void) {"
      assert c_code =~ "void increment_by_two(void) {"
    end
  end
end