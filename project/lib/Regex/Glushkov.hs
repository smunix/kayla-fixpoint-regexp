-- | A Play On Regular Expression
module Regex.Glushkov where

import Data.Semiring
import Optics

-- | Weighted regular expressions
data Reg₀ c s where
  Reg₀
    ∷ { _empties ∷ s
      , _finals ∷ s
      , _reg₀ ∷ Re₀ c s
      }
    → Reg₀ c s

data Re₀ c s where
  Eps₀ ∷ Re₀ c s
  Sym₀ ∷ (c → s) → Re₀ c s
  Alt₀ ∷ Reg₀ c s → Reg₀ c s → Re₀ c s
  Seq₀ ∷ Reg₀ c s → Reg₀ c s → Re₀ c s
  Rep₀ ∷ Reg₀ c s → Re₀ c s

makeLenses ''Reg₀

instance (Semiring s) ⇒ AsEmpty (Reg₀ c s) where
  _Empty = nearly (Reg₀ one zero Empty) undefined

instance AsEmpty (Re₀ c s) where
  _Empty = nearly Eps₀ undefined

eps₀ ∷ (Semiring s) ⇒ Reg₀ c s
eps₀ = Empty

sym₀ ∷ (Semiring s) ⇒ (c → s) → Reg₀ c s
sym₀ f =
  Empty
    & empties
    .~ zero
    & finals
    .~ zero
    & reg₀
    .~ Sym₀ f

alt₀ ∷ (Semiring s) ⇒ Reg₀ c s → Reg₀ c s → Reg₀ c s
alt₀ a b =
  Empty
    & empties
    .~ (a ^. empties)
    `plus` (b ^. empties)
      & finals
      .~ (a ^. finals)
    `plus` (b ^. finals)
      & reg₀
      .~ Alt₀ a b

seq₀ ∷ (Semiring s) ⇒ Reg₀ c s → Reg₀ c s → Reg₀ c s
seq₀ a b =
  Empty
    & empties
    .~ (a ^. empties)
    `times` (b ^. empties)
      & finals
      .~ (a ^. finals)
    `times` (b ^. empties)
    `plus` (b ^. finals)
      & reg₀
      .~ Seq₀ a b

rep₀ ∷ (Semiring s) ⇒ Reg₀ c s → Reg₀ c s
rep₀ r =
  Empty
    & empties
    .~ one
    & finals
    .~ r
    ^. finals
    & reg₀
    .~ Rep₀ r

shift₀ ∷ (Semiring s) ⇒ s → Re₀ c s → c → Reg₀ c s
shift₀ s₀ = \case
  Eps₀ → (const eps₀)
  Sym₀ f → \c → sym₀ f & finals .~ s₀ `times` f c
  Alt₀ a b → \c → shift₀ s₀ (a ^. reg₀) c `alt₀` shift₀ s₀ (b ^. reg₀) c
  Seq₀ a b → \c → shift₀ s₀ (a ^. reg₀) c `seq₀` shift₀ (s₀ `times` (b ^. empties) `plus` (b ^. finals)) (b ^. reg₀) c
  Rep₀ r → rep₀ . shift₀ (s₀ `plus` (r ^. finals)) (r ^. reg₀)

-- | Efficient matching of weighted regular expressions
match₀ ∷ (Semiring s) ⇒ Reg₀ c s → [c] → s
match₀ r₀ = \case
  [] → r₀ ^. empties
  (c : cs) → foldlOf' folded (shift₀ zero . view reg₀) (shift₀ one (r₀ ^. reg₀) c) cs ^. finals
