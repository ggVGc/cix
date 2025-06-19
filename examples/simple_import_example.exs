# Simple example demonstrating import validation in Cix macro DSL
# Run with: elixir -S mix run examples/simple_import_example.exs

import Cix.Macro

IO.puts "=== Simple Import Validation Demo ==="

# Example 1: Working imports
IO.puts "\n1. Testing valid imports..."
try do
  ir = c_program do
    c_module :utils, exports: [:helper_func] do
      defn helper_func(x :: int) :: int do
        return x * 2
      end
    end
    
    c_module :main, imports: [utils: [:helper_func]] do
      defn main() :: int do
        result = helper_func(21)
        printf("Result: %d\\n", result)
        return result
      end
    end
  end
  
  IO.puts "✓ Valid imports compiled successfully"
  {:ok, result} = Cix.IR.execute(ir, "main")
  IO.puts "Execution result: #{result}"
  
rescue
  e -> IO.puts "❌ Unexpected error: #{inspect(e)}"
end

# Example 2: Missing module
IO.puts "\n2. Testing import from missing module..."
try do
  c_program do
    c_module :main, imports: [missing_module: [:some_func]] do
      defn main() :: int do
        return 0
      end
    end
  end
  
  IO.puts "❌ Should have failed but didn't!"
rescue
  CompileError -> IO.puts "✓ Correctly caught missing module error"
  e -> IO.puts "❌ Unexpected error type: #{inspect(e)}"
end

# Example 3: Non-exported function
IO.puts "\n3. Testing import of non-exported function..."
try do
  c_program do
    c_module :secret, exports: [:public_func] do
      defn public_func() :: int do
        return 1
      end
      
      defn private_func() :: int do
        return 42
      end
    end
    
    c_module :main, imports: [secret: [:private_func]] do
      defn main() :: int do
        return 0
      end
    end
  end
  
  IO.puts "❌ Should have failed but didn't!"
rescue
  CompileError -> IO.puts "✓ Correctly caught non-exported function error"
  e -> IO.puts "❌ Unexpected error type: #{inspect(e)}"
end

# Example 4: Complex working example
IO.puts "\n4. Testing complex valid scenario..."
try do
  ir = c_program do
    c_module :math, exports: [:add, :multiply] do
      defn add(x :: int, y :: int) :: int do
        return x + y
      end
      
      defn multiply(x :: int, y :: int) :: int do
        return x * y
      end
      
      defn private_helper() :: int do
        return 100
      end
    end
    
    c_module :geometry, exports: [:area], imports: [math: [:multiply]] do
      defn area(w :: int, h :: int) :: int do
        return multiply(w, h)
      end
    end
    
    c_module :main, imports: [math: [:add], geometry: [:area]] do
      defn main() :: int do
        rect_area = area(5, 6)
        total = add(rect_area, 10)
        printf("Area + 10 = %d\\n", total)
        return total
      end
    end
  end
  
  IO.puts "✓ Complex imports validated successfully"
  {:ok, result} = Cix.IR.execute(ir, "main")
  IO.puts "Complex execution result: #{result}"
  
  # Show module statistics
  IO.puts "\nModule statistics:"
  Enum.each(ir.modules, fn module ->
    IO.puts "  #{module.name}: exports #{inspect(module.exports)}, imports #{length(module.imports)} modules"
  end)
  
rescue
  e -> IO.puts "❌ Unexpected error in complex example: #{inspect(e)}"
end

IO.puts "\n=== Import validation is working correctly! ==="