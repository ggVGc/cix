defmodule Cix.DSLModules.MathLib do
  @moduledoc """
  A reusable DSL module providing basic mathematical operations.
  
  This module can be imported into other DSL modules using:
  
      use Cix.DSLModules.MathLib
  
  Exports: add, subtract, multiply, divide, power
  """
  
  use Cix.DSLModule, auto_export: true
  
  def get_dsl_functions do
    [
      dsl_function do
        defn add(x :: int, y :: int) :: int do
          return x + y
        end
      end,
      dsl_function do
        defn subtract(x :: int, y :: int) :: int do
          return x - y
        end
      end,
      dsl_function do
        defn multiply(x :: int, y :: int) :: int do
          return x * y
        end
      end,
      dsl_function do
        defn divide(x :: int, y :: int) :: int do
          return x / y
        end
      end,
      dsl_function do
        defn power(base :: int, exp :: int) :: int do
          result = multiply(base, base)
          return result
        end
      end
    ]
  end
end