defmodule Cix.ModuleTest do
  use ExUnit.Case, async: true

  import Cix.Macro
  alias Cix.IR

  describe "module system" do
    test "can define modules with exports" do
      ir = c_program do
        c_module :math, exports: [:add] do
          defn add(x :: int, y :: int) :: int do
            return x + y
          end
        end
      end

      assert length(ir.modules) == 1
      [module] = ir.modules
      assert module.name == "math"
      assert module.exports == ["add"]
      assert length(module.functions) == 1
    end

    test "can generate C code with modules" do
      ir = c_program do
        c_module :math, exports: [:add] do
          defn add(x :: int, y :: int) :: int do
            return x + y
          end
        end
      end

      c_code = IR.to_c_code(ir)
      assert String.contains?(c_code, "// Module: math")
      assert String.contains?(c_code, "int add(int x, int y);")
      assert String.contains?(c_code, "int add(int x, int y) {")
    end

    test "can execute functions from modules" do
      ir = c_program do
        c_module :math, exports: [:add] do
          defn add(x :: int, y :: int) :: int do
            return x + y
          end
        end
        
        c_module :main do
          defn main() :: int do
            result = add(5, 3)
            return result
          end
        end
      end

      {:ok, result} = IR.execute(ir, "main")
      assert result == 8
    end

    test "modules can use each other's functions" do
      ir = c_program do
        c_module :math_utils, exports: [:multiply] do
          defn multiply(x :: int, y :: int) :: int do
            return x * y
          end
        end
        
        c_module :geometry, imports: [math_utils: [:multiply]] do
          defn area(width :: int, height :: int) :: int do
            return multiply(width, height)
          end
        end
        
        c_module :main do
          defn main() :: int do
            result = area(4, 6)
            return result
          end
        end
      end

      {:ok, result} = IR.execute(ir, "main")
      assert result == 24
    end
  end
end