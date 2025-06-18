defmodule Frix.DSLTest do
  use ExUnit.Case
  alias Frix.DSL

  describe "DSL construction" do
    test "creates empty DSL" do
      dsl = DSL.new()
      assert dsl.functions == []
      assert dsl.variables == []
    end

    test "adds variables with integer values" do
      dsl = 
        DSL.new()
        |> DSL.add_variable("count", "int", 42)
        |> DSL.add_variable("size", "long", 1024)

      assert length(dsl.variables) == 2
      assert Enum.any?(dsl.variables, &(&1.name == "count" and &1.value == 42))
      assert Enum.any?(dsl.variables, &(&1.name == "size" and &1.value == 1024))
    end

    test "adds functions with parameters and body" do
      params = [DSL.param("x", "int"), DSL.param("y", "int")]
      body = [DSL.return_stmt("x + y")]
      
      dsl = 
        DSL.new()
        |> DSL.add_function("add", "int", params, body)

      assert length(dsl.functions) == 1
      [func] = dsl.functions
      assert func.name == "add"
      assert func.return_type == "int"
      assert length(func.params) == 2
      assert length(func.body) == 1
    end
  end

  describe "C code generation" do
    test "generates C code for variables" do
      dsl = 
        DSL.new()
        |> DSL.add_variable("counter", "int", 0)
        |> DSL.add_variable("max_size", "long", 2048)

      c_code = DSL.generate_c_code(dsl)
      
      assert c_code =~ "int counter = 0;"
      assert c_code =~ "long max_size = 2048;"
    end

    test "generates C code for simple function" do
      body = [DSL.return_stmt(42)]
      
      dsl = 
        DSL.new()
        |> DSL.add_function("get_answer", "int", [], body)

      c_code = DSL.generate_c_code(dsl)
      
      assert c_code =~ "int get_answer(void) {"
      assert c_code =~ "    return 42;"
      assert c_code =~ "}"
    end

    test "generates C code for function with parameters" do
      params = [DSL.param("a", "int"), DSL.param("b", "int")]
      body = [DSL.return_stmt("a + b")]
      
      dsl = 
        DSL.new()
        |> DSL.add_function("add", "int", params, body)

      c_code = DSL.generate_c_code(dsl)
      
      assert c_code =~ "int add(int a, int b) {"
      assert c_code =~ "    return a + b;"
      assert c_code =~ "}"
    end

    test "generates C code for function with assignments" do
      body = [
        DSL.assign("result", 10),
        DSL.assign("result", "result * 2"),
        DSL.return_stmt("result")
      ]
      
      dsl = 
        DSL.new()
        |> DSL.add_function("calculate", "int", [], body)

      c_code = DSL.generate_c_code(dsl)
      
      assert c_code =~ "int calculate(void) {"
      assert c_code =~ "    result = 10;"
      assert c_code =~ "    result = result * 2;"
      assert c_code =~ "    return result;"
      assert c_code =~ "}"
    end

    test "generates C code for function calls" do
      body = [
        DSL.call_function("printf", ["\"Hello World\\n\""]),
        DSL.return_stmt(0)
      ]
      
      dsl = 
        DSL.new()
        |> DSL.add_function("main", "int", [], body)

      c_code = DSL.generate_c_code(dsl)
      
      assert c_code =~ "int main(void) {"
      assert c_code =~ "    printf(\"Hello World\\n\");"
      assert c_code =~ "    return 0;"
      assert c_code =~ "}"
    end

    test "generates complete C program" do
      params = [DSL.param("n", "int")]
      factorial_body = [
        DSL.assign("result", 1),
        DSL.assign("i", 1),
        DSL.return_stmt("result")
      ]
      
      main_body = [
        DSL.call_function("printf", ["\"Factorial: %d\\n\"", "factorial(5)"]),
        DSL.return_stmt(0)
      ]
      
      dsl = 
        DSL.new()
        |> DSL.add_variable("global_counter", "int", 0)
        |> DSL.add_function("factorial", "int", params, factorial_body)
        |> DSL.add_function("main", "int", [], main_body)

      c_code = DSL.generate_c_code(dsl)
      
      assert c_code =~ "int global_counter = 0;"
      assert c_code =~ "int factorial(int n) {"
      assert c_code =~ "int main(void) {"
      assert c_code =~ "printf(\"Factorial: %d\\n\", factorial(5));"
    end
  end
end