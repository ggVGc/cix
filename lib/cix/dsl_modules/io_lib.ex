defmodule Cix.DSLModules.IOLib do
  @moduledoc """
  A reusable DSL module providing I/O utility functions.
  
  Usage:
      use Cix.DSLModules.IOLib
  
  Exports: print_int, print_two_ints, print_calculation_result
  """
  
  use Cix.DSLModule
  
  def get_dsl_exports, do: [:print_int, :print_two_ints, :print_calculation_result]
  
  def get_dsl_functions do
    [
      dsl_function do
        defn print_int(value :: int) :: void do
          printf("Value: %d\\n", value)
        end
      end,
      dsl_function do
        defn print_two_ints(a :: int, b :: int) :: void do
          printf("A: %d, B: %d\\n", a, b)
        end
      end,
      dsl_function do
        defn print_calculation_result(operation :: int, a :: int, b :: int, result :: int) :: void do
          printf("Operation %d: %d and %d = %d\\n", operation, a, b, result)
        end
      end
    ]
  end
end