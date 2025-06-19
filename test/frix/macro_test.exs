defmodule Frix.MacroTest do
  use ExUnit.Case
  require Frix.Macro
  import Frix.Macro

  describe "c_program macro with IR output" do
    test "generates IR for simple program with variables" do
      ir = c_program do
        var :count, :int, 42
        var :max_size, :long, 1024
      end

      assert %Frix.IR{} = ir
      assert length(ir.variables) == 2
      assert Enum.any?(ir.variables, &(&1.name == "count" and &1.value == 42))
      assert Enum.any?(ir.variables, &(&1.name == "max_size" and &1.value == 1024))
      
      # Test C code generation
      c_code = Frix.IR.to_c_code(ir)
      assert c_code =~ "int count = 42;"
      assert c_code =~ "long max_size = 1024;"
    end

    test "generates IR and C code for function without parameters" do
      ir = c_program do
        function :get_answer, :int do
          return 42
        end
      end

      assert %Frix.IR{} = ir
      assert length(ir.functions) == 1
      [func] = ir.functions
      assert func.name == "get_answer"
      assert func.return_type == "int"
      assert func.params == []
      
      c_code = Frix.IR.to_c_code(ir)
      assert c_code =~ "int get_answer(void) {"
      assert c_code =~ "    return 42;"
      assert c_code =~ "}"
    end

    test "generates IR and C code for function with parameters" do
      ir = c_program do
        function :add, :int, [x: :int, y: :int] do
          return x + y
        end
      end

      assert %Frix.IR{} = ir
      [func] = ir.functions
      assert length(func.params) == 2
      
      c_code = Frix.IR.to_c_code(ir)
      assert c_code =~ "int add(int x, int y) {"
      assert c_code =~ "    return x + y;"
      assert c_code =~ "}"
    end

    test "generates IR and C code for function with assignments" do
      ir = c_program do
        function :calculate, :int do
          result = 10
          result = result * 2
          return result
        end
      end

      assert %Frix.IR{} = ir
      [func] = ir.functions
      assert length(func.body) == 3
      
      c_code = Frix.IR.to_c_code(ir)
      assert c_code =~ "int calculate(void) {"
      assert c_code =~ "    result = 10;"
      assert c_code =~ "    result = result * 2;"
      assert c_code =~ "    return result;"
      assert c_code =~ "}"
    end

    test "generates IR and C code for function with function calls" do
      ir = c_program do
        function :main, :int do
          printf("Hello World!")
          return 0
        end
      end

      assert %Frix.IR{} = ir
      
      c_code = Frix.IR.to_c_code(ir)
      assert c_code =~ "int main(void) {"
      assert c_code =~ "    printf(\"Hello World!\");"
      assert c_code =~ "    return 0;"
      assert c_code =~ "}"
    end

    test "generates complete IR and C program" do
      ir = c_program do
        var :global_counter, :int, 0
        
        function :increment, :void do
          global_counter = global_counter + 1
        end
        
        function :main, :int do
          increment()
          printf("Counter: %d\\n", global_counter)
          return 0
        end
      end

      assert %Frix.IR{} = ir
      assert length(ir.variables) == 1
      assert length(ir.functions) == 2
      
      c_code = Frix.IR.to_c_code(ir)
      assert c_code =~ "int global_counter = 0;"
      assert c_code =~ "void increment(void) {"
      assert c_code =~ "global_counter = global_counter + 1;"
      assert c_code =~ "int main(void) {"
      assert c_code =~ "increment();"
      assert c_code =~ "printf(\"Counter: %d\\n\", global_counter);"
      assert c_code =~ "return 0;"
    end

    test "can execute IR directly in Elixir" do
      ir = c_program do
        var :counter, :int, 5
        
        function :add, :int, [x: :int, y: :int] do
          return x + y
        end
        
        function :main, :int do
          result = counter + 3
          return result
        end
      end

      {:ok, result} = Frix.IR.execute(ir, "main")
      assert result == 8
    end

    test "handles arithmetic expressions in IR" do
      ir = c_program do
        function :math_ops, :int, [a: :int, b: :int] do
          sum = a + b
          diff = a - b
          product = a * b
          quotient = a / b
          return sum + diff + product + quotient
        end
      end

      c_code = Frix.IR.to_c_code(ir)
      assert c_code =~ "sum = a + b;"
      assert c_code =~ "diff = a - b;"
      assert c_code =~ "product = a * b;"
      assert c_code =~ "quotient = a / b;"
      assert c_code =~ "return sum + diff + product + quotient;"
      
      # Test execution
      {:ok, result} = Frix.IR.execute(ir, "math_ops", [10, 2])
      # 10+2 + 10-2 + 10*2 + 10/2 = 12 + 8 + 20 + 5 = 45
      assert result == 45
    end
  end

  describe "DSL helper functions" do
    test "builds DSL manually with helper functions" do
      import Frix.DSL
      
      dsl = 
        new()
        |> add_variable("counter", "int", 100)
        |> add_function("get_counter", "int", [], [return_stmt("counter")])

      c_code = generate_c_code(dsl)
      
      assert c_code =~ "int counter = 100;"
      assert c_code =~ "int get_counter(void) {"
      assert c_code =~ "    return counter;"
    end

    test "return macro outside function raises error" do
      assert_raise RuntimeError, "return/1 can only be used inside function bodies", fn ->
        quote do
          return(42)
        end |> Code.eval_quoted()
      end
    end
  end
end