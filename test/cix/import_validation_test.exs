defmodule Cix.ImportValidationTest do
  use ExUnit.Case, async: true

  import Cix.Macro
  alias Cix.IR

  describe "import validation" do
    test "validates successful imports" do
      # This should work - math_utils exports add, main imports add
      ir = c_program do
        c_module :math_utils, exports: [:add, :multiply] do
          defn add(x :: int, y :: int) :: int do
            return x + y
          end
          
          defn multiply(x :: int, y :: int) :: int do
            return x * y
          end
        end
        
        c_module :main, imports: [math_utils: [:add]] do
          defn main() :: int do
            result = add(5, 3)
            return result
          end
        end
      end

      assert length(ir.modules) == 2
      # Should not raise error since validation passed
    end

    test "fails when importing from non-existent module" do
      assert_raise CompileError, ~r/imports from 'nonexistent' but 'nonexistent' does not exist/, fn ->
        c_program do
          c_module :main, imports: [nonexistent: [:some_func]] do
            defn main() :: int do
              result = some_func()
              return result
            end
          end
        end
      end
    end

    test "fails when importing non-exported function" do
      assert_raise CompileError, ~r/imports function 'private_func' from 'utils' but 'private_func' is not exported/, fn ->
        c_program do
          c_module :utils, exports: [:public_func] do
            defn public_func() :: int do
              return 1
            end
            
            defn private_func() :: int do
              return 2
            end
          end
          
          c_module :main, imports: [utils: [:private_func]] do
            defn main() :: int do
              result = private_func()
              return result
            end
          end
        end
      end
    end

    test "allows importing multiple functions from multiple modules" do
      ir = c_program do
        c_module :math, exports: [:add, :subtract] do
          defn add(x :: int, y :: int) :: int do
            return x + y
          end
          
          defn subtract(x :: int, y :: int) :: int do
            return x - y
          end
        end
        
        c_module :geometry, exports: [:area, :perimeter] do
          defn area(width :: int, height :: int) :: int do
            return multiply(width, height)
          end
          
          defn perimeter(width :: int, height :: int) :: int do
            return add(add(width, height), add(width, height))
          end
        end
        
        c_module :main, imports: [math: [:add], geometry: [:area]] do
          defn main() :: int do
            sum = add(5, 3)
            rect_area = area(4, 6)
            return add(sum, rect_area)
          end
        end
      end

      assert length(ir.modules) == 3
      
      # Verify the imports are correctly stored
      main_module = Enum.find(ir.modules, &(&1.name == "main"))
      assert length(main_module.imports) == 2
      
      math_import = Enum.find(main_module.imports, &(&1.module_name == "math"))
      assert math_import.functions == ["add"]
      
      geometry_import = Enum.find(main_module.imports, &(&1.module_name == "geometry"))
      assert geometry_import.functions == ["area"]
    end

    test "validates complex import chains" do
      ir = c_program do
        c_module :low_level, exports: [:basic_add] do
          defn basic_add(x :: int, y :: int) :: int do
            return x + y
          end
        end
        
        c_module :mid_level, exports: [:enhanced_add], imports: [low_level: [:basic_add]] do
          defn enhanced_add(x :: int, y :: int, z :: int) :: int do
            temp = basic_add(x, y)
            return basic_add(temp, z)
          end
        end
        
        c_module :high_level, imports: [mid_level: [:enhanced_add]] do
          defn calculate() :: int do
            return enhanced_add(1, 2, 3)
          end
        end
      end

      assert length(ir.modules) == 3
      
      # Test execution to ensure the import chain works
      {:ok, result} = IR.execute(ir, "calculate")
      assert result == 6  # 1 + 2 + 3
    end

    test "fails with detailed error for multiple import issues" do
      assert_raise CompileError, fn ->
        c_program do
          c_module :utils, exports: [:func1] do
            defn func1() :: int do
              return 1
            end
            
            defn func2() :: int do
              return 2
            end
          end
          
          c_module :main, imports: [utils: [:func2, :func3], missing: [:func4]] do
            defn main() :: int do
              return 0
            end
          end
        end
      end
    end
  end

  describe "c_program with valid modules" do
    test "executes imported functions correctly" do
      ir = c_program do
        c_module :calculator, exports: [:multiply, :power] do
          defn multiply(x :: int, y :: int) :: int do
            return x * y
          end
          
          defn power(base :: int, exp :: int) :: int do
            result = multiply(base, base)
            return result
          end
        end
        
        c_module :geometry, imports: [calculator: [:multiply]] do
          defn area(width :: int, height :: int) :: int do
            return multiply(width, height)
          end
          
          defn volume(length :: int, width :: int, height :: int) :: int do
            base_area = multiply(length, width)
            return multiply(base_area, height)
          end
        end
      end

      # Test that imported functions work correctly
      {:ok, area_result} = IR.execute(ir, "area", [8, 6])
      assert area_result == 48

      {:ok, volume_result} = IR.execute(ir, "volume", [3, 4, 5])
      assert volume_result == 60
      
      # Test that calculator functions still work independently
      {:ok, multiply_result} = IR.execute(ir, "multiply", [7, 9])
      assert multiply_result == 63
    end
  end
end