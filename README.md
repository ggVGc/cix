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

