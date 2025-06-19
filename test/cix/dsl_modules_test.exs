defmodule Cix.DSLModulesTest do
  use ExUnit.Case, async: true

  alias Cix.DSLModules.{MathLib, GeometryLib, IOLib}

  describe "MathLib DSL module" do
    test "provides basic math functions" do
      ir = MathLib.create_ir()
      
      # Test exports
      exports = MathLib.get_dsl_exports()
      assert :add in exports
      assert :subtract in exports
      assert :multiply in exports
      assert :divide in exports
      assert :power in exports
      
      # Test function execution
      {:ok, add_result} = Cix.IR.execute(ir, "add", [15, 25])
      assert add_result == 40
      
      {:ok, subtract_result} = Cix.IR.execute(ir, "subtract", [50, 20])
      assert subtract_result == 30
      
      {:ok, multiply_result} = Cix.IR.execute(ir, "multiply", [8, 7])
      assert multiply_result == 56
      
      {:ok, divide_result} = Cix.IR.execute(ir, "divide", [100, 4])
      assert divide_result == 25
      
      {:ok, power_result} = Cix.IR.execute(ir, "power", [6, 2])
      assert power_result == 36
    end

    test "generates correct C code" do
      ir = MathLib.create_ir()
      c_code = Cix.IR.to_c_code(ir)
      
      assert c_code =~ "int add(int x, int y) {"
      assert c_code =~ "return x + y;"
      assert c_code =~ "int multiply(int x, int y) {"
      assert c_code =~ "return x * y;"
    end
  end

  describe "GeometryLib DSL module" do
    test "provides geometry functions and uses MathLib" do
      ir = GeometryLib.create_ir()
      
      # Test exports
      exports = GeometryLib.get_dsl_exports()
      assert :rectangle_area in exports
      assert :rectangle_perimeter in exports
      assert :circle_area_approx in exports
      assert :cube_volume in exports
      
      # Test that MathLib functions are included
      function_names = ir.functions |> Enum.map(& &1.name)
      assert "add" in function_names
      assert "multiply" in function_names
      assert "rectangle_area" in function_names
      
      # Test geometry function execution
      {:ok, area_result} = Cix.IR.execute(ir, "rectangle_area", [12, 8])
      assert area_result == 96
      
      {:ok, perimeter_result} = Cix.IR.execute(ir, "rectangle_perimeter", [12, 8])
      assert perimeter_result == 40  # 2*12 + 2*8
      
      {:ok, circle_result} = Cix.IR.execute(ir, "circle_area_approx", [5])
      assert circle_result == 75  # 3 * 5^2
      
      {:ok, volume_result} = Cix.IR.execute(ir, "cube_volume", [4])
      assert volume_result == 64  # 4^3
      
      # Test that underlying MathLib functions still work
      {:ok, math_result} = Cix.IR.execute(ir, "add", [10, 5])
      assert math_result == 15
    end

    test "has correct module dependencies" do
      imported_modules = GeometryLib.get_imported_modules()
      assert MathLib in imported_modules
    end
  end

  describe "IOLib DSL module" do
    test "provides I/O utility functions" do
      ir = IOLib.create_ir()
      
      # Test exports
      exports = IOLib.get_dsl_exports()
      assert :print_int in exports
      assert :print_two_ints in exports
      assert :print_calculation_result in exports
      
      # Test that functions are defined (we can't easily test printf output in tests)
      function_names = ir.functions |> Enum.map(& &1.name)
      assert "print_int" in function_names
      assert "print_two_ints" in function_names
      assert "print_calculation_result" in function_names
    end

    test "generates correct C code with printf calls" do
      ir = IOLib.create_ir()
      c_code = Cix.IR.to_c_code(ir)
      
      assert c_code =~ "void print_int(int value) {"
      assert c_code =~ "printf(\"Value: %d\\n\", value);"
      assert c_code =~ "void print_two_ints(int a, int b) {"
      assert c_code =~ "printf(\"A: %d, B: %d\\n\", a, b);"
    end
  end

  describe "module composition" do
    test "can combine all DSL modules" do
      defmodule TestCompositeModule do
        use Cix.DSLModule
        use MathLib
        use GeometryLib
        use IOLib
        
        def get_dsl_exports, do: [:test_all]
        
        def get_dsl_functions do
          import Cix.Macro
          
          [
            quote do
          defn test_all() :: int do
            # Use math functions
            sum = add(10, 5)
            product = multiply(4, 6)
            
            # Use geometry functions
            area = rectangle_area(8, 6)
            volume = cube_volume(3)
            
            # Combine results
            total = add(sum, product)
            total = add(total, area)
            total = add(total, volume)
            
            return total
          end
            end
          ]
        end
      end
      
      ir = TestCompositeModule.create_ir()
      
      # Should have functions from all modules
      function_names = ir.functions |> Enum.map(& &1.name)
      assert "add" in function_names
      assert "multiply" in function_names
      assert "rectangle_area" in function_names
      assert "cube_volume" in function_names
      assert "print_int" in function_names
      assert "test_all" in function_names
      
      # Test execution
      {:ok, result} = Cix.IR.execute(ir, "test_all")
      # 15 + 24 + 48 + 27 = 114
      assert result == 114
    end

    test "can create program from multiple modules" do
      combined_ir = Cix.DSLModule.create_program([MathLib, GeometryLib, IOLib])
      
      function_names = combined_ir.functions |> Enum.map(& &1.name)
      
      # Should have functions from all modules
      assert "add" in function_names
      assert "rectangle_area" in function_names
      assert "print_int" in function_names
      
      # Test individual module functions work
      {:ok, math_result} = Cix.IR.execute(combined_ir, "multiply", [7, 8])
      assert math_result == 56
      
      {:ok, geometry_result} = Cix.IR.execute(combined_ir, "rectangle_area", [5, 6])
      assert geometry_result == 30
    end

    test "validates module imports correctly" do
      defmodule ValidCompositeModule do
        use Cix.DSLModule
        use MathLib
        use GeometryLib
        
        def get_dsl_exports, do: [:composite_func]
        
        def get_dsl_functions do
          import Cix.Macro
          
          [
            quote do
          defn composite_func() :: int do
            return add(1, 2)
          end
            end
          ]
        end
      end
      
      # Should validate successfully
      assert Cix.DSLModule.validate_dsl_imports(ValidCompositeModule) == :ok
      
      # Test that module works correctly
      ir = ValidCompositeModule.create_ir()
      {:ok, result} = Cix.IR.execute(ir, "composite_func")
      assert result == 3
    end
  end
end