defmodule Cix.DSLModules.GeometryLib do
  @moduledoc """
  A reusable DSL module providing geometric calculations.
  
  This module depends on MathLib for basic arithmetic operations.
  
  Usage:
      use Cix.DSLModules.GeometryLib
  
  Exports: rectangle_area, rectangle_perimeter, circle_area_approx, cube_volume
  """
  
  use Cix.DSLModule
  use Cix.DSLModules.MathLib
  
  def get_dsl_exports, do: [:rectangle_area, :rectangle_perimeter, :circle_area_approx, :cube_volume]
  
  def get_dsl_functions do
    import Cix.Macro
    
    [
      quote do
        defn rectangle_area(width :: int, height :: int) :: int do
          return multiply(width, height)
        end
      end,
      quote do
        defn rectangle_perimeter(width :: int, height :: int) :: int do
          width_times_two = multiply(width, 2)
          height_times_two = multiply(height, 2)
          return add(width_times_two, height_times_two)
        end
      end,
      quote do
        defn circle_area_approx(radius :: int) :: int do
          radius_squared = power(radius, 2)
          return multiply(3, radius_squared)
        end
      end,
      quote do
        defn cube_volume(side :: int) :: int do
          area = rectangle_area(side, side)
          return multiply(area, side)
        end
      end
    ]
  end
end