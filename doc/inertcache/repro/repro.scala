import language.experimental.captureChecking

object Aliases:
  type A0 = "a0x" | "a0y" | "a0z"
  type B0 = "b0x" | "b0y" | "b0z"
  type A1 = A0 | B0 | "a1"
  type B1 = A0 | B0 | "b1"
  type A2 = A1 | B1 | "a2"
  type B2 = A1 | B1 | "b2"
  type A3 = A2 | B2 | "a3"
  type B3 = A2 | B2 | "b3"
  type A4 = A3 | B3 | "a4"
  type B4 = A3 | B3 | "b4"
  type A5 = A4 | B4 | "a5"
  type B5 = A4 | B4 | "b5"
  type A6 = A5 | B5 | "a6"
  type B6 = A5 | B5 | "b6"
  type A7 = A6 | B6 | "a7"
  type B7 = A6 | B6 | "b7"
  type A8 = A7 | B7 | "a8"
  type B8 = A7 | B7 | "b8"
  type A9 = A8 | B8 | "a9"
  type B9 = A8 | B8 | "b9"
  type A10 = A9 | B9 | "a10"
  type B10 = A9 | B9 | "b10"
  type A11 = A10 | B10 | "a11"
  type B11 = A10 | B10 | "b11"
  type A12 = A11 | B11 | "a12"
  type B12 = A11 | B11 | "b12"

import Aliases.*
def f(x: A12): A12 = x
