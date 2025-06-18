defmodule Frix.MacroTest do
  use ExUnit.Case
  require Frix.Macro
  import Frix.Macro

  describe "c_program macro with natural syntax" do
    test "generates C code for simple program with variables" do
      c_code = c_program do
        var :count, :int, 42
        var :max_size, :long, 1024
      end

      assert c_code =~ "int count = 42;"
      assert c_code =~ "long max_size = 1024;"
    end

    test "generates C code for function without parameters" do
      c_code = c_program do
        function :get_answer, :int do
          return 42
        end
      end

      assert c_code =~ "int get_answer(void) {"
      assert c_code =~ "    return 42;"
      assert c_code =~ "}"
    end

    test "generates C code for function with parameters" do
      c_code = c_program do
        function :add, :int, [x: :int, y: :int] do
          return x + y
        end
      end

      assert c_code =~ "int add(int x, int y) {"
      assert c_code =~ "    return x + y;"
      assert c_code =~ "}"
    end

    test "generates C code for function with assignments" do
      c_code = c_program do
        function :calculate, :int do
          result = 10
          result = result * 2
          return result
        end
      end

      assert c_code =~ "int calculate(void) {"
      assert c_code =~ "    result = 10;"
      assert c_code =~ "    result = result * 2;"
      assert c_code =~ "    return result;"
      assert c_code =~ "}"
    end

    test "generates C code for function with function calls" do
      c_code = c_program do
        function :main, :int do
          printf("Hello World!")
          return 0
        end
      end

      assert c_code =~ "int main(void) {"
      assert c_code =~ "    printf(\"Hello World!\");"
      assert c_code =~ "    return 0;"
      assert c_code =~ "}"
    end

    test "generates complete C program" do
      c_code = c_program do
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

      assert c_code =~ "int global_counter = 0;"
      assert c_code =~ "void increment(void) {"
      assert c_code =~ "global_counter = global_counter + 1;"
      assert c_code =~ "int main(void) {"
      assert c_code =~ "increment();"
      assert c_code =~ "printf(\"Counter: %d\\n\", global_counter);"
      assert c_code =~ "return 0;"
    end

    test "handles arithmetic expressions" do
      c_code = c_program do
        function :math_ops, :int, [a: :int, b: :int] do
          sum = a + b
          diff = a - b
          product = a * b
          quotient = a / b
          return sum + diff + product + quotient
        end
      end

      assert c_code =~ "sum = a + b;"
      assert c_code =~ "diff = a - b;"
      assert c_code =~ "product = a * b;"
      assert c_code =~ "quotient = a / b;"
      assert c_code =~ "return sum + diff + product + quotient;"
    end

    test "handles function calls with multiple arguments" do
      c_code = c_program do
        function :test_calls, :void do
          printf("Number: %d, String: %s", 42, "hello")
          sprintf(buffer, "Value: %d", value)
        end
      end

      assert c_code =~ "printf(\"Number: %d, String: %s\", 42, \"hello\");"
      assert c_code =~ "sprintf(buffer, \"Value: %d\", value);"
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