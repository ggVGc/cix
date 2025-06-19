defmodule Frix.ElixirSyntaxTest do
  use ExUnit.Case
  require Frix.Macro
  import Frix.Macro

  describe "Elixir-like defn syntax" do
    test "generates IR for function with typed parameters" do
      ir = c_program do
        defn add(x :: int, y :: int) :: int do
          return x + y
        end
      end

      assert %Frix.IR{} = ir
      assert length(ir.functions) == 1
      [func] = ir.functions
      assert func.name == "add"
      assert func.return_type == "int"
      assert length(func.params) == 2
      
      c_code = Frix.IR.to_c_code(ir)
      assert c_code =~ "int add(int x, int y) {"
      assert c_code =~ "    return x + y;"
    end

    test "generates IR for function without parameters" do
      ir = c_program do
        defn get_answer() :: int do
          return 42
        end
      end

      assert %Frix.IR{} = ir
      [func] = ir.functions
      assert func.name == "get_answer"
      assert func.return_type == "int"
      assert func.params == []
      
      c_code = Frix.IR.to_c_code(ir)
      assert c_code =~ "int get_answer(void) {"
      assert c_code =~ "    return 42;"
    end

    test "generates complete program with new syntax" do
      ir = c_program do
        var :count, :int, 0
        
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

      assert %Frix.IR{} = ir
      assert length(ir.variables) == 1
      assert length(ir.functions) == 3
      
      c_code = Frix.IR.to_c_code(ir)
      assert c_code =~ "int count = 0;"
      assert c_code =~ "void increment(void) {"
      assert c_code =~ "int get_count(void) {"
      assert c_code =~ "int main(void) {"
      assert c_code =~ "increment();"
      assert c_code =~ "result = get_count();"
    end

    test "can execute new syntax in Elixir" do
      ir = c_program do
        var :value, :int, 10
        
        defn double(x :: int) :: int do
          return x * 2
        end
        
        defn main() :: int do
          result = double(value)
          return result
        end
      end

      {:ok, result} = Frix.IR.execute(ir, "main")
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

      {:ok, result} = Frix.IR.execute(ir, "main")
      # (5 + 3) * 2 = 16
      assert result == 16
      
      c_code = Frix.IR.to_c_code(ir)
      assert c_code =~ "int calculate(int a, int b, int c) {"
      assert c_code =~ "sum = a + b;"
      assert c_code =~ "product = sum * c;"
      assert c_code =~ "return product;"
    end
  end

  describe "mixed syntax compatibility" do
    test "old function syntax and new defn syntax work together" do
      ir = c_program do
        var :counter, :int, 0
        
        # Old syntax
        function :old_increment, :void do
          counter = counter + 1
        end
        
        # New syntax
        defn new_increment() :: void do
          counter = counter + 1
        end
        
        defn main() :: int do
          old_increment()
          new_increment()
          return counter
        end
      end

      {:ok, result} = Frix.IR.execute(ir, "main")
      assert result == 2
      
      c_code = Frix.IR.to_c_code(ir)
      assert c_code =~ "void old_increment(void) {"
      assert c_code =~ "void new_increment(void) {"
    end
  end
end