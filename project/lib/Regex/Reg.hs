module Regex.Reg where

import Data.Semiring
import Optics
import Optics.Core.Extras

data Reg c where
  Eps ∷ Reg c
  Sym ∷ c → Reg c
  Alt ∷ Reg c → Reg c → Reg c
  Seq ∷ Reg c → Reg c → Reg c
  Rep ∷ Reg c → Reg c
  deriving (Show)

split' ∷ [a] → [([a], [a])]
split' [] = [([], [])]
split' (a : as) = ([], a : as) : fmap (over _1 (a :)) (split' as)

parts' ∷ [a] → [[[a]]]
parts' [] = [[]]
parts' [a] = [[[a]]]
parts' (a : as) = parts' as & foldMapOf folded \(p : ps) → [(a : p) : ps, [a] : p : ps]

nocs = Rep (Alt (Sym 'a') (Sym 'b'))
onec = Seq nocs (Sym 'c')
evencs = Seq (Rep (Seq onec onec)) nocs

-- >>> parts' "acc"
-- >>> accept evencs "acc"

accept ∷ (Eq c) ⇒ Reg c → [c] → Bool
accept = \case
  Eps → is _Empty
  Sym c → ([c] ==)
  Alt a b → \string → accept a string || accept b string
  Seq a b → \string → split' string <&> (\(h, t) → accept a h && accept b t) & anyOf folded id
  Rep r → \string → parts' string <&> (allOf folded id . fmap (accept r)) & anyOf folded id

-- | Weighted regexp
data Reg₀ c s where
  Eps₀ ∷ Reg₀ c s
  Sym₀ ∷ (c → s) → Reg₀ c s
  Alt₀ ∷ Reg₀ c s → Reg₀ c s → Reg₀ c s
  Seq₀ ∷ Reg₀ c s → Reg₀ c s → Reg₀ c s
  Rep₀ ∷ Reg₀ c s → Reg₀ c s

weight₀ ∷ (Eq c, Semiring s) ⇒ Reg c → Reg₀ c s
weight₀ = \case
  Eps → Eps₀
  Sym c → Sym₀ \c' → if c == c' then one else zero
  Alt a b → Alt₀ (weight₀ a) (weight₀ b)
  Seq a b → Seq₀ (weight₀ a) (weight₀ b)
  Rep r → Rep₀ (weight₀ r)

accept₀ ∷ (Semiring s) ⇒ Reg₀ c s → [c] → s
accept₀ = \case
  Eps₀ → \string → if is _Empty string then one else zero
  Sym₀ f → \case
    [c] → f c
    _ → zero
  Alt₀ a b → \string → plus (accept₀ a string) (accept₀ b string)
  Seq₀ a b → \string → split' string <&> (\(h, t) → accept₀ a h `times` accept₀ b t) & sum
  Rep₀ r → \string → parts' string <&> (prod . fmap (accept₀ r)) & sum
  where
    sum = foldrOf folded plus zero
    prod = foldrOf folded times one
