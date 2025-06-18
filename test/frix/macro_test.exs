defmodule Frix.MacroTest do
  use ExUnit.Case
  require Frix.Macro
  import Frix.Macro

  describe "c_program macro" do
    test "generates C code for simple program with variables" do
      c_code = c_program do
        add_var(:count, :int, 42)
        add_var(:max_size, :long, 1024)
      end

      assert c_code =~ "int count = 42;"
      assert c_code =~ "long max_size = 1024;"
    end

    test "generates C code for function without parameters" do
      c_code = c_program do
        add_func(:get_answer, :int, "42")
      end

      assert c_code =~ "int get_answer(void) {"
      assert c_code =~ "    return 42;"
      assert c_code =~ "}"
    end

    test "generates C code for function with parameters" do
      c_code = c_program do
        add_func(:add, :int, [x: :int, y: :int], ["x + y"])
      end

      assert c_code =~ "int add(int x, int y) {"
      assert c_code =~ "    return x + y;"
      assert c_code =~ "}"
    end

    test "generates C code for function with assignments and calls" do
      c_code = c_program do
        add_func(:calculate, :int, [
          {:assign, :result, 10},
          {:assign, :result, "result * 2"},
          {:ret, "result"}
        ])
      end

      assert c_code =~ "int calculate(void) {"
      assert c_code =~ "    result = 10;"
      assert c_code =~ "    result = result * 2;"
      assert c_code =~ "    return result;"
      assert c_code =~ "}"
    end

    test "generates C code for function with calls" do
      c_code = c_program do
        add_func(:main, :int, [
          {:call, :printf, ["\"Hello World!\""]},
          {:ret, 0}
        ])
      end

      assert c_code =~ "int main(void) {"
      assert c_code =~ "    printf(\"Hello World!\");"
      assert c_code =~ "    return 0;"
      assert c_code =~ "}"
    end

    test "generates complete C program" do
      c_code = c_program do
        add_var(:global_counter, :int, 0)
        
        add_func(:increment, :void, [
          {:assign, :global_counter, "global_counter + 1"}
        ])
        
        add_func(:main, :int, [
          {:call, :increment, []},
          {:call, :printf, ["\"Counter: %d\\n\"", "global_counter"]},
          {:ret, 0}
        ])
      end

      assert c_code =~ "int global_counter = 0;"
      assert c_code =~ "void increment(void) {"
      assert c_code =~ "global_counter = global_counter + 1;"
      assert c_code =~ "int main(void) {"
      assert c_code =~ "increment();"
      assert c_code =~ "printf(\"Counter: %d\\n\", global_counter);"
      assert c_code =~ "return 0;"
    end
  end

  describe "DSL helper functions" do
    test "builds DSL manually with helper macros" do
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

    test "uses individual helper macros" do
      result_ret = ret(42)
      result_assign = assign(:x, "10")
      result_call = call(:printf, ["hello"])

      assert result_ret == Frix.DSL.return_stmt(42)
      assert result_assign == Frix.DSL.assign("x", "10")
      assert result_call == Frix.DSL.call_function("printf", ["hello"])
    end
  end
end