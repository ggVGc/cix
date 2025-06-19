# Cix

**A Domain Specific Language (DSL) in Elixir for generating C code with natural syntax**

Mainly developed using LLM as a technology exploration.

Cix provides an Elixir-like syntax for writing C programs, with dual execution capabilities: compile to C or execute directly in Elixir.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `cix` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:cix, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/cix>.

## Quick Example

```elixir
import Cix.Macro

ir = c_program do
  let count :: int = 42
  
  defn add(x :: int, y :: int) :: int do
    return x + y
  end
  
  defn main() :: int do
    result = add(count, 8)
    printf("Result: %d\\n", result)
    return 0
  end
end

# Generate C code
c_code = Cix.IR.to_c_code(ir)

# Or execute directly in Elixir
{:ok, result} = Cix.IR.execute(ir)
```

## Development Log

### DSL Module Top-Level Functions (Previous)

**Request**: In modules using Cix.DSLModule, the functions should be defined at top-level inside the module, instead of being inside `get_dsl_functions`.

**Summary**: Attempted to implement automatic `get_dsl_functions` generation but encountered issues because the `defn` macro from `Cix.Macro` expects a `var!(ir)` variable to exist in the runtime context, which isn't available when accumulating function ASTs at compile time.

**Result**: Reverted changes. The current design requiring functions to be defined within `get_dsl_functions` is necessary due to the macro expansion context requirements.

### dsl_function Helper Macro Implementation (Current)

**Request**: Implement the helper macro `dsl_function` to reduce boilerplate in DSL module definitions.

**Summary**: Successfully implemented the `dsl_function` helper macro that:
1. Wraps DSL function definitions in the required `quote` block automatically
2. Handles the `import Cix.Macro` statement internally
3. Reduces boilerplate code in DSL modules
4. Fixed `create_ir/0` to properly evaluate function ASTs at runtime

**Implementation**:
- Added `dsl_function/1` macro to `Cix.DSLModule`
- Updated all existing DSL modules (MathLib, IOLib, GeometryLib) to use the new syntax
- Enhanced `create_ir/0` method to use `Code.eval_quoted` for proper AST evaluation

**Before**:
```elixir
def get_dsl_functions do
  import Cix.Macro
  
  [
    quote do
      defn add(x :: int, y :: int) :: int do
        return x + y
      end
    end
  ]
end
```

**After**:
```elixir
def get_dsl_functions do
  [
    dsl_function do
      defn add(x :: int, y :: int) :: int do
        return x + y
      end
    end
  ]
end
```

**Result**: The helper macro successfully reduces boilerplate and makes DSL module definitions cleaner and more readable. All DSL modules now use the improved syntax, and most tests are passing.

### Automatic Export Detection Implementation (Current)

**Request**: Implement automatic export detection described in improvements suggestion.

**Summary**: Successfully implemented automatic export detection that:
1. Automatically extracts function names from `dsl_function` definitions
2. Generates `get_dsl_exports` list without manual specification
3. Provides option to disable auto-export (`auto_export: false`)
4. Combines auto-detected exports with manually defined ones
5. Works seamlessly with module composition and imports

**Implementation**:
- Enhanced `__using__` macro to accept `auto_export` option (defaults to `true`)
- Added AST analysis functions to extract function names from quoted DSL functions
- Modified `__before_compile__` hook to auto-generate `get_dsl_exports` when enabled
- Updated all existing DSL modules to use auto-export

**Before**:
```elixir
defmodule MyMathLib do
  use Cix.DSLModule
  
  def get_dsl_exports, do: [:add, :multiply]  # Manual specification
  
  def get_dsl_functions do
    [
      dsl_function do
        defn add(x :: int, y :: int) :: int do
          return x + y
        end
      end,
      dsl_function do
        defn multiply(x :: int, y :: int) :: int do
          return x * y
        end
      end
    ]
  end
end
```

**After**:
```elixir
defmodule MyMathLib do
  use Cix.DSLModule, auto_export: true  # Auto-detects [:add, :multiply]
  
  def get_dsl_functions do
    [
      dsl_function do
        defn add(x :: int, y :: int) :: int do
          return x + y
        end
      end,
      dsl_function do
        defn multiply(x :: int, y :: int) :: int do
          return x * y
        end
      end
    ]
  end
end
```

**Benefits**:
- **Zero boilerplate**: No need to manually maintain export lists
- **Automatic synchronization**: Exports always match actual function definitions
- **Error prevention**: Eliminates mismatches between defined and exported functions
- **Backward compatible**: Existing modules work unchanged with `auto_export: false`

**Result**: Automatic export detection significantly improves DSL module usability by eliminating manual export list maintenance while preserving all existing functionality.

