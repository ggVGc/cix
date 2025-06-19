defmodule Cix.DSLModuleTest do
  use ExUnit.Case, async: true

  describe "DSL module system" do
    test "can define a basic DSL module" do
      defmodule TestMathModule do
        use Cix.DSLModule
        
        def get_dsl_exports, do: [:test_add, :test_multiply]
        
        def get_dsl_functions do
          import Cix.Macro
          
          [
            quote do
              defn test_add(x :: int, y :: int) :: int do
                return x + y
              end
            end,
            quote do
              defn test_multiply(x :: int, y :: int) :: int do
                return x * y
              end
            end
          ]
        end
      end
      
      # Test module introspection
      assert TestMathModule.get_dsl_exports() == [:test_add, :test_multiply]
      assert TestMathModule.get_imported_modules() == []
      
      # Test IR generation
      ir = TestMathModule.create_ir()
      assert %Cix.IR{} = ir
      assert length(ir.functions) == 2
      
      function_names = ir.functions |> Enum.map(& &1.name)
      assert "test_add" in function_names
      assert "test_multiply" in function_names
      
      # Test execution
      {:ok, add_result} = Cix.IR.execute(ir, "test_add", [10, 5])
      assert add_result == 15
      
      {:ok, multiply_result} = Cix.IR.execute(ir, "test_multiply", [6, 7])
      assert multiply_result == 42
    end

    test "can use one DSL module in another" do
      defmodule BaseModule do
        use Cix.DSLModule
        
        def get_dsl_exports, do: [:base_func]
        
        def get_dsl_functions do
          import Cix.Macro
          
          [
            quote do
              defn base_func(x :: int) :: int do
                return x * 2
              end
            end
          ]
        end
      end
      
      defmodule UsingModule do
        use Cix.DSLModule
        use BaseModule
        
        def get_dsl_exports, do: [:derived_func]
        
        def get_dsl_functions do
          import Cix.Macro
          
          [
            quote do
              defn derived_func(x :: int) :: int do
                doubled = base_func(x)
                return doubled + 10
              end
            end
          ]
        end
      end
      
      # Test that using module includes the base module
      assert BaseModule in UsingModule.get_imported_modules()
      
      # Test IR includes functions from both modules
      ir = UsingModule.create_ir()
      function_names = ir.functions |> Enum.map(& &1.name)
      assert "base_func" in function_names
      assert "derived_func" in function_names
      
      # Test execution of derived function that uses base function
      {:ok, result} = Cix.IR.execute(ir, "derived_func", [5])
      assert result == 20  # (5 * 2) + 10
      
      # Test base function still works
      {:ok, base_result} = Cix.IR.execute(ir, "base_func", [8])
      assert base_result == 16
    end

    test "can create program from DSL module" do
      defmodule ProgramModule do
        use Cix.DSLModule
        
        def get_dsl_exports, do: [:main]
        
        def get_dsl_functions do
          import Cix.Macro
          
          [
            quote do
              defn main() :: int do
                return 42
              end
            end
          ]
        end
      end
      
      # Test program creation
      ir = Cix.DSLModule.create_program(ProgramModule)
      assert %Cix.IR{} = ir
      
      {:ok, result} = Cix.IR.execute(ir, "main")
      assert result == 42
    end

    test "can combine multiple DSL modules" do
      defmodule ModuleA do
        use Cix.DSLModule
        
        def get_dsl_exports, do: [:func_a]
        
        def get_dsl_functions do
          import Cix.Macro
          
          [
            quote do
              defn func_a() :: int do
                return 10
              end
            end
          ]
        end
      end
      
      defmodule ModuleB do
        use Cix.DSLModule
        
        def get_dsl_exports, do: [:func_b]
        
        def get_dsl_functions do
          import Cix.Macro
          
          [
            quote do
              defn func_b() :: int do
                return 20
              end
            end
          ]
        end
      end
      
      # Test combining multiple modules
      combined_ir = Cix.DSLModule.create_program([ModuleA, ModuleB])
      
      function_names = combined_ir.functions |> Enum.map(& &1.name)
      assert "func_a" in function_names
      assert "func_b" in function_names
      
      {:ok, result_a} = Cix.IR.execute(combined_ir, "func_a")
      assert result_a == 10
      
      {:ok, result_b} = Cix.IR.execute(combined_ir, "func_b")
      assert result_b == 20
    end

    test "validates DSL module imports" do
      defmodule ValidDSLModule do
        use Cix.DSLModule
        
        def get_dsl_exports, do: [:valid_func]
        
        def get_dsl_functions do
          import Cix.Macro
          
          [
            quote do
              defn valid_func() :: int do
                return 1
              end
            end
          ]
        end
      end
      
      defmodule ModuleWithValidImports do
        use Cix.DSLModule
        use ValidDSLModule
        
        def get_dsl_exports, do: [:main_func]
        
        def get_dsl_functions do
          import Cix.Macro
          
          [
            quote do
              defn main_func() :: int do
                return valid_func()
              end
            end
          ]
        end
      end
      
      # Test validation passes for valid imports
      assert Cix.DSLModule.validate_dsl_imports(ModuleWithValidImports) == :ok
      
      # Test validation fails for non-DSL module
      assert {:error, _} = Cix.DSLModule.validate_dsl_imports(String)
    end

    test "generates correct C code for DSL modules" do
      defmodule CCodeTestModule do
        use Cix.DSLModule
        
        def get_dsl_exports, do: [:test_function]
        
        def get_dsl_functions do
          import Cix.Macro
          
          [
            quote do
              let global_var :: int = 100
            end,
            quote do
              defn test_function(param :: int) :: int do
                result = param + global_var
                return result
              end
            end
          ]
        end
      end
      
      ir = CCodeTestModule.create_ir()
      c_code = Cix.IR.to_c_code(ir)
      
      # Verify C code contains expected elements
      assert c_code =~ "int global_var = 100;"
      assert c_code =~ "int test_function(int param) {"
      assert c_code =~ "result = param + global_var;"
      assert c_code =~ "return result;"
    end

    test "handles complex DSL module chains" do
      defmodule ChainModuleA do
        use Cix.DSLModule
        
        def get_dsl_exports, do: [:chain_a]
        
        def get_dsl_functions do
          import Cix.Macro
          
          [
            quote do
              defn chain_a(x :: int) :: int do
                return x + 1
              end
            end
          ]
        end
      end
      
      defmodule ChainModuleB do
        use Cix.DSLModule
        use ChainModuleA
        
        def get_dsl_exports, do: [:chain_b]
        
        def get_dsl_functions do
          import Cix.Macro
          
          [
            quote do
              defn chain_b(x :: int) :: int do
                temp = chain_a(x)
                return temp * 2
              end
            end
          ]
        end
      end
      
      defmodule ChainModuleC do
        use Cix.DSLModule
        use ChainModuleB
        
        def get_dsl_exports, do: [:chain_c]
        
        def get_dsl_functions do
          import Cix.Macro
          
          [
            quote do
              defn chain_c(x :: int) :: int do
                temp = chain_b(x)
                return temp + 10
              end
            end
          ]
        end
      end
      
      # Test the full chain
      ir = ChainModuleC.create_ir()
      
      # All functions should be available
      function_names = ir.functions |> Enum.map(& &1.name)
      assert "chain_a" in function_names
      assert "chain_b" in function_names  
      assert "chain_c" in function_names
      
      # Test execution: chain_c(5) = ((5 + 1) * 2) + 10 = 22
      {:ok, result} = Cix.IR.execute(ir, "chain_c", [5])
      assert result == 22
      
      # Test intermediate functions still work
      {:ok, result_a} = Cix.IR.execute(ir, "chain_a", [5])
      assert result_a == 6
      
      {:ok, result_b} = Cix.IR.execute(ir, "chain_b", [5])
      assert result_b == 12
    end
  end
end