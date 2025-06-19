# Example demonstrating import functionality between modules using the Cix macro DSL
# Run with: elixir -S mix run examples/import_example.exs

defmodule ImportExample do
  import Cix.Macro
  
  def run do

    IO.puts "=== Import Validation Example ==="
    
    # Example 1: Basic successful imports
    IO.puts "\n--- Example 1: Basic Imports ---"
    
    basic_ir = c_program do
      c_module :math_utils, exports: [:add, :multiply, :subtract] do
        defn add(x :: int, y :: int) :: int do
          return x + y
        end
        
        defn multiply(x :: int, y :: int) :: int do
          return x * y
        end
        
        defn subtract(x :: int, y :: int) :: int do
          return x - y
        end
      end
      
      c_module :calculator, imports: [math_utils: [:add, :multiply]] do
        defn square(x :: int) :: int do
          return multiply(x, x)
        end
        
        defn sum_of_squares(x :: int, y :: int) :: int do
          x_sq = square(x)
          y_sq = square(y)
          return add(x_sq, y_sq)
        end
      end
      
      c_module :main, imports: [calculator: [:sum_of_squares], math_utils: [:add]] do
        defn main() :: int do
          result = sum_of_squares(3, 4)  # 3^2 + 4^2 = 9 + 16 = 25
          final = add(result, 5)         # 25 + 5 = 30
          printf("Sum of squares of 3 and 4, plus 5 = %d\\n", final)
          return final
        end
      end
    end
    
    IO.puts "✓ Basic imports validated successfully"
    c_code = Cix.IR.to_c_code(basic_ir)
    IO.puts "Generated C code has #{length(String.split(c_code, "\n"))} lines"
    
    {:ok, result} = Cix.IR.execute(basic_ir, "main")
    IO.puts "Execution result: #{result}"
    
    # Example 2: Complex import chains
    IO.puts "\n--- Example 2: Import Chains ---"
    
    chain_ir = c_program do
      # Base layer - fundamental operations
      c_module :primitives, exports: [:basic_add, :basic_multiply] do
        defn basic_add(x :: int, y :: int) :: int do
          return x + y
        end
        
        defn basic_multiply(x :: int, y :: int) :: int do
          return x * y
        end
      end
      
      # Middle layer - builds on primitives
      c_module :arithmetic, exports: [:power, :factorial_partial], imports: [primitives: [:basic_add, :basic_multiply]] do
        defn power(base :: int, exp :: int) :: int do
          # Simple power for exp=2
          return basic_multiply(base, base)
        end
        
        defn factorial_partial(n :: int) :: int do
          # Simplified factorial for small n (just n * (n-1))
          prev = basic_add(n, -1)
          return basic_multiply(n, prev)
        end
      end
      
      # Top layer - advanced operations
      c_module :advanced, exports: [:complex_calc], imports: [arithmetic: [:power, :factorial_partial], primitives: [:basic_add]] do
        defn complex_calc(x :: int) :: int do
          pow_result = power(x, 2)        # x^2
          fact_result = factorial_partial(x)  # x * (x-1)
          return basic_add(pow_result, fact_result)  # x^2 + x*(x-1)
        end
      end
      
      c_module :main, imports: [advanced: [:complex_calc]] do
        defn main() :: int do
          result = complex_calc(5)  # 5^2 + 5*4 = 25 + 20 = 45
          printf("Complex calculation for 5: %d\\n", result)
          return result
        end
      end
    end
    
    IO.puts "✓ Import chains validated successfully"
    {:ok, chain_result} = Cix.IR.execute(chain_ir, "main")
    IO.puts "Chain execution result: #{chain_result}"
    
    # Example 3: Demonstrate validation failures
    IO.puts "\n--- Example 3: Import Validation Failures ---"
    
    # Test missing module
    IO.puts "Testing import from non-existent module..."
    try do
      c_program do
        c_module :main, imports: [nonexistent: [:some_func]] do
          defn main() :: int do
            return 0
          end
        end
      end
      IO.puts "❌ Should have failed but didn't!"
    rescue
      CompileError -> IO.puts "✓ Correctly caught missing module import"
    end
    
    # Test missing function
    IO.puts "Testing import of non-exported function..."
    try do
      c_program do
        c_module :utils, exports: [:public_only] do
          defn public_only() :: int do
            return 1
          end
          
          defn private_func() :: int do
            return 2
          end
        end
        
        c_module :main, imports: [utils: [:private_func]] do
          defn main() :: int do
            return 0
          end
        end
      end
      IO.puts "❌ Should have failed but didn't!"
    rescue
      CompileError -> IO.puts "✓ Correctly caught non-exported function import"
    end
    
    # Example 4: Statistics and analysis
    IO.puts "\n--- Example 4: Import Analysis ---"
    
    analyze_modules(basic_ir)
    
    IO.puts "\n=== Import functionality is working correctly! ==="
  end
  
  defp analyze_modules(ir) do
    IO.puts "\nModule Analysis:"
    IO.puts "Total modules: #{length(ir.modules)}"
    
    Enum.each(ir.modules, fn module ->
      IO.puts "\nModule: #{module.name}"
      IO.puts "  Exports: #{inspect(module.exports)}"
      IO.puts "  Imports: #{inspect(module.imports)}"
      IO.puts "  Functions: #{module.functions |> Enum.map(& &1.name) |> inspect()}"
      
      if length(module.imports) > 0 do
        import_summary = module.imports
        |> Enum.map(fn %{module_name: mod, functions: funcs} ->
          "#{mod}(#{Enum.join(funcs, ", ")})"
        end)
        |> Enum.join(", ")
        IO.puts "  Import summary: #{import_summary}"
      end
    end)
  end
end

ImportExample.run()