module Lib.Top where

import Data.Vector
import Optics

fp ∷ (a → a → Bool) → (a → a) → a → a
fp stopfn stepfn a0 = if stopfn a0 a1 then a0 else fp stopfn stepfn a1
  where
    a1 = stepfn a0

ls = [0, 10 .. 180] ∷ [Float]

diff = 0.005

split' ∷ [a] → [([a], [a])]
split' Empty = [(Empty, Empty)]
split' xs@(a :< as) = (Empty, xs) :< (over _1 (a :<) <$> split' as)

parts0 ∷ ∀ a. [a] → [[[a]]]
parts0 [] = [[[]]]
parts0 (a : as) = parts0 as & foldMapOf folded \(p : ps) → [(a : p) : ps, [a] : p : ps]

parts1 ∷ ∀ a. [a] → [[[a]]]
parts1 [] = [[]]
parts1 [a] = [[[a]]]
parts1 (a : as) = parts1 as & foldMapOf folded \(p : ps) → [(a : p) : ps, [a] : p : ps]

main ∷ IO ()
main = do
  print "All your Haskell code belongs to us!"
  print $ fmap sin ls

  print $ fp (\a b → abs (a - b) < diff) sin 2011
  print $ fp (\a b → abs (a - b) < diff) sin 1982
  print $ fp (\a b → abs (a - b) < diff) sin 3452

  print $ split' [1, 2, 3]

  print $ parts1 "k"
  print $ parts1 "ka"
  print $ parts1 "kay"
  print $ parts1 "kayl"

  print $ parts0 [1]
  print $ parts1 [1]
  print $ parts0 [1 .. 2]
  print $ parts1 [1 .. 2]
  print $ parts0 [1 .. 3]
  print $ parts1 [1 .. 3]
  print $ parts0 [1 .. 4]
  print $ parts1 [1 .. 4]

-- print $ fp (\a b -> b > 8564756876343654897541564634465468468469687897896786786987986798687976897686835967436837465348698639688784357488578524843674568) (\a -> a + 2) 45
