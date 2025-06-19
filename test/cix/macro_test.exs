defmodule Cix.MacroTest do
  use ExUnit.Case
  require Cix.Macro
  import Cix.Macro

  describe "c_program macro IR generation" do
    test "generates correct IR for variables" do
      ir = c_program do
        let count :: int = 42
        let max_size :: long = 1024
      end

      assert %Cix.IR{} = ir
      assert length(ir.variables) == 2
      
      count_var = Enum.find(ir.variables, &(&1.name == "count"))
      assert count_var.name == "count"
      assert count_var.type == "int"
      assert count_var.value == {:literal, 42}
      
      max_size_var = Enum.find(ir.variables, &(&1.name == "max_size"))
      assert max_size_var.name == "max_size"
      assert max_size_var.type == "long"
      assert max_size_var.value == {:literal, 1024}
    end

    test "generates correct IR for function without parameters" do
      ir = c_program do
        defn get_answer() :: int do
          return 42
        end
      end

      assert %Cix.IR{} = ir
      assert length(ir.functions) == 1
      [func] = ir.functions
      assert func.name == "get_answer"
      assert func.return_type == "int"
      assert func.params == []
      assert length(func.body) == 1
      
      [{:return, return_expr}] = func.body
      assert return_expr == {:literal, 42}
    end

    test "generates correct IR for function with parameters" do
      ir = c_program do
        defn add(x :: int, y :: int) :: int do
          return x + y
        end
      end

      assert %Cix.IR{} = ir
      [func] = ir.functions
      assert func.name == "add"
      assert func.return_type == "int"
      assert length(func.params) == 2
      
      [param1, param2] = func.params
      assert param1.name == "x" and param1.type == "int"
      assert param2.name == "y" and param2.type == "int"
      
      [{:return, return_expr}] = func.body
      assert return_expr == {:binary_op, :add, {:var, "x"}, {:var, "y"}}
    end

    test "generates correct IR for function with assignments" do
      ir = c_program do
        defn calculate() :: int do
          result = 10
          result = result * 2
          return result
        end
      end

      assert %Cix.IR{} = ir
      [func] = ir.functions
      assert func.name == "calculate"
      assert func.return_type == "int"
      assert func.params == []
      assert length(func.body) == 3
      
      [stmt1, stmt2, stmt3] = func.body
      assert stmt1 == {:assign, "result", {:literal, 10}}
      assert stmt2 == {:assign, "result", {:binary_op, :mul, {:var, "result"}, {:literal, 2}}}
      assert stmt3 == {:return, {:var, "result"}}
    end

    test "generates correct IR for function with function calls" do
      ir = c_program do
        defn main() :: int do
          printf("Hello World!")
          return 0
        end
      end

      assert %Cix.IR{} = ir
      [func] = ir.functions
      assert func.name == "main"
      assert func.return_type == "int"
      assert func.params == []
      assert length(func.body) == 2
      
      [call_stmt, return_stmt] = func.body
      assert call_stmt == {:call, "printf", [{:literal, "Hello World!"}]}
      assert return_stmt == {:return, {:literal, 0}}
    end

    test "generates correct IR for complete program with variables and functions" do
      ir = c_program do
        let global_counter :: int = 0
        
        defn increment() :: void do
          global_counter = global_counter + 1
        end
        
        defn main() :: int do
          increment()
          printf("Counter: %d\\n", global_counter)
          return 0
        end
      end

      assert %Cix.IR{} = ir
      assert length(ir.variables) == 1
      assert length(ir.functions) == 2
      
      # Verify variable
      [var] = ir.variables
      assert var.name == "global_counter"
      assert var.type == "int"
      assert var.value == {:literal, 0}
      
      # Verify increment function
      increment_func = Enum.find(ir.functions, &(&1.name == "increment"))
      assert increment_func.return_type == "void"
      assert increment_func.params == []
      [assign_stmt] = increment_func.body
      assert assign_stmt == {:assign, "global_counter", {:binary_op, :add, {:var, "global_counter"}, {:literal, 1}}}
      
      # Verify main function
      main_func = Enum.find(ir.functions, &(&1.name == "main"))
      assert main_func.return_type == "int"
      assert main_func.params == []
      assert length(main_func.body) == 3
      [call_increment, call_printf, return_stmt] = main_func.body
      assert call_increment == {:call, "increment", []}
      assert call_printf == {:call, "printf", [{:literal, "Counter: %d\\n"}, {:var, "global_counter"}]}
      assert return_stmt == {:return, {:literal, 0}}
    end

    test "can execute IR directly in Elixir" do
      ir = c_program do
        let counter :: int = 5
        
        defn add(x :: int, y :: int) :: int do
          return x + y
        end
        
        defn main() :: int do
          result = counter + 3
          return result
        end
      end

      {:ok, result} = Cix.IR.execute(ir, "main")
      assert result == 8
    end

    test "generates correct IR for arithmetic expressions" do
      ir = c_program do
        defn math_ops(a :: int, b :: int) :: int do
          sum = a + b
          diff = a - b
          product = a * b
          quotient = a / b
          return sum + diff + product + quotient
        end
      end

      assert %Cix.IR{} = ir
      [func] = ir.functions
      assert func.name == "math_ops"
      assert func.return_type == "int"
      assert length(func.params) == 2
      assert length(func.body) == 5
      
      [sum_stmt, diff_stmt, product_stmt, quotient_stmt, return_stmt] = func.body
      assert sum_stmt == {:assign, "sum", {:binary_op, :add, {:var, "a"}, {:var, "b"}}}
      assert diff_stmt == {:assign, "diff", {:binary_op, :sub, {:var, "a"}, {:var, "b"}}}
      assert product_stmt == {:assign, "product", {:binary_op, :mul, {:var, "a"}, {:var, "b"}}}
      assert quotient_stmt == {:assign, "quotient", {:binary_op, :div, {:var, "a"}, {:var, "b"}}}
      
      # Verify complex return expression
      {:return, return_expr} = return_stmt
      assert return_expr == {:binary_op, :add, 
        {:binary_op, :add, 
          {:binary_op, :add, {:var, "sum"}, {:var, "diff"}}, 
          {:var, "product"}
        }, 
        {:var, "quotient"}
      }
      
      # Test execution still works
      {:ok, result} = Cix.IR.execute(ir, "math_ops", [10, 2])
      assert result == 45
    end

    test "generates correct IR for struct definitions" do
      ir = c_program do
        struct :Point, [x: :int, y: :int]
        struct :Rectangle, [top_left: :Point, width: :int, height: :int]
      end

      assert %Cix.IR{} = ir
      assert length(ir.structs) == 2
      
      # Verify Point struct
      point_struct = Enum.find(ir.structs, &(&1.name == "Point"))
      assert point_struct.name == "Point"
      assert length(point_struct.fields) == 2
      [field1, field2] = point_struct.fields
      assert field1.name == "x" and field1.type == "int"
      assert field2.name == "y" and field2.type == "int"
      
      # Verify Rectangle struct
      rectangle_struct = Enum.find(ir.structs, &(&1.name == "Rectangle"))
      assert rectangle_struct.name == "Rectangle"
      assert length(rectangle_struct.fields) == 3
      [top_left_field, width_field, height_field] = rectangle_struct.fields
      assert top_left_field.name == "top_left" and top_left_field.type == "Point"
      assert width_field.name == "width" and width_field.type == "int"
      assert height_field.name == "height" and height_field.type == "int"
    end

    test "verifies IR construction with direct IR module usage" do
      # Test direct IR construction and verify structure
      import Cix.IR
      
      ir = 
        new()
        |> add_struct("Point", [%{name: "x", type: "int"}, %{name: "y", type: "int"}])
        |> add_function("main", "int", [], [
          {:assign, "point_x", {:literal, 10}},
          {:assign, "point_y", {:literal, 20}},
          {:return, {:binary_op, :add, {:var, "point_x"}, {:var, "point_y"}}}
        ])

      # Verify IR structure
      assert %Cix.IR{} = ir
      assert length(ir.structs) == 1
      assert length(ir.functions) == 1
      
      # Verify struct
      [struct_def] = ir.structs
      assert struct_def.name == "Point"
      assert length(struct_def.fields) == 2
      
      # Verify function
      [func] = ir.functions
      assert func.name == "main"
      assert func.return_type == "int"
      assert length(func.body) == 3
      
      {:ok, result} = execute(ir, "main")
      assert result == 30
    end
  end

  describe "DSL helper functions" do
    test "builds DSL manually with helper functions" do
      import Cix.DSL
      
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