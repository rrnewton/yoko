{-# LANGUAGE DataKinds, TypeOperators, TypeFamilies, UndecidableInstances,
  DefaultSignatures, ViewPatterns, FlexibleContexts, FlexibleInstances,
  PolyKinds, MultiParamTypeClasses, Rank2Types, DataKinds #-}

module Data.Yoko.MinCtors (MinCtors(..), gen_minCtors, nCtors) where

import Data.Yoko

import Data.Semigroup (Min(..))
import qualified Data.Yoko.MinCtors.MMap as MMap
import Data.Yoko.MinCtors.Minima

import Data.Monoid (mappend)

import qualified GHC.Real

--------------------
-- miscellaneous

pDisband0 :: Proxy (t :: *) -> Proxy (DCs t ('KProxy :: KProxy () ()))
pDisband0 _ = Proxy

pDisband1 :: Proxy (t :: k0 -> *) -> Proxy (DCs t ('KProxy :: KProxy () k0))
pDisband1 _ = Proxy

pDisband2 :: Proxy (t :: k1 -> k0 -> *) -> Proxy (DCs t ('KProxy :: KProxy k1 k0))
pDisband2 _ = Proxy

pRepN :: Proxy (N dc :: k1 -> k0 -> *) -> Proxy (Rep dc ('KProxy :: KProxy k1 k0))
pRepN _ = Proxy














--------------------
-- the internal classes

class MinInfoRec (t :: k) (ts :: [k1]) where
  minInfoRec :: Proxy t -> Proxy ts -> SiblingInT ts

class MinInfoNonRec (t :: k) where minInfoNonRec :: Proxy t -> Minima2

minima1ToSiblingInT :: VRepeat ts => Minima2 -> SiblingInT ts
minima1ToSiblingInT =
  MMap.mapWithMonoKeys (\(np1, np0) -> (cvRepeat 0, np1, np0)) id

void :: Minima2
void = MMap.singleton (0, 0) $ Min 0

nCtors :: MinCtorsTrim t => Int -> Proxy t -> MinCtorsT t
nCtors n p = minCtorsTrim p $ nCtors' n p

nCtors' :: Int -> Proxy t -> Minima2
nCtors' n _ = MMap.singleton (0, 0) $ Min n







deDep1 :: Proxy (T1 (Dep f) r) -> (Proxy f, Proxy r)
deDep1 _ = (Proxy, Proxy)

instance (Ord (CVec ts NRec), MinCtors f, MinInfoRec r ts) => MinInfoRec (T1 (Dep f) r) ts where
  minInfoRec (deDep1 -> (pf, pr)) pts = minCtors pf `plug0` minInfoRec pr pts

instance (MinCtors f, MinInfoNonRec r) => MinInfoNonRec (T1 (Dep f) r) where
  minInfoNonRec (deDep1 -> (pf, pr)) = minCtors pf `plug0'` minInfoNonRec pr

deDep2 :: Proxy (T2 (Dep ff) r1 r0) -> (Proxy ff, Proxy r1, Proxy r0)
deDep2 _ = (Proxy, Proxy, Proxy)

instance (Ord (CVec ts NRec), MinCtors ff, MinInfoRec rB ts, MinInfoRec rA ts) => MinInfoRec (T2 (Dep ff) rB rA) ts where
  minInfoRec (deDep2 -> (ff, rB, rA)) pts =
    plug10 (minCtors ff) (minInfoRec rB pts) (minInfoRec rA pts)

instance (MinCtors ff, MinInfoNonRec rB, MinInfoNonRec rA) => MinInfoNonRec (T2 (Dep ff) rB rA) where
  minInfoNonRec (deDep2 -> (ff, rB, rA)) = plug10' (minCtors ff) (minInfoNonRec rB) (minInfoNonRec rA)



instance (VRepeat ts) => MinInfoRec (Void t) ts where minInfoRec _ _ = minima1ToSiblingInT void
instance MinInfoNonRec (Void t) where minInfoNonRec = nCtors' 0



instance MinInfoRec (Rep dc ('KProxy :: KProxy k1 k0)) ts => MinInfoRec (N dc :: k1 -> k0 -> *) ts where
  minInfoRec = minInfoRec . pRepN

instance MinInfoNonRec (Rep dc ('KProxy :: KProxy k1 k0)) => MinInfoNonRec (N dc :: k1 -> k0 -> *) where
  minInfoNonRec = minInfoNonRec . pRepN





deC :: Proxy (C t r) -> Proxy r
deC _ = Proxy

instance MinInfoRec r ts => MinInfoRec (C dc r) ts where
  minInfoRec = (MMap.map (fmap succ) .) . minInfoRec . deC
instance MinInfoNonRec r => MinInfoNonRec (C dc r) where
  minInfoNonRec = MMap.map (fmap succ) . minInfoNonRec . deC



dePlus :: Proxy (l :+: r) -> (Proxy l, Proxy r)
dePlus _ = (Proxy, Proxy)

instance (Ord (CVec ts NRec), MinInfoRec l ts, MinInfoRec r ts) => MinInfoRec (l :+: r) ts where
  minInfoRec (dePlus -> (l, r)) pts = minInfoRec l pts `mappend` minInfoRec r pts
instance (MinInfoNonRec l, MinInfoNonRec r) => MinInfoNonRec (l :+: r) where
  minInfoNonRec (dePlus -> (l, r)) = minInfoNonRec l `mappend` minInfoNonRec r



instance MinInfoNonRec U where minInfoNonRec = nCtors' 0
instance (VRepeat ts) => MinInfoRec U ts where minInfoRec _ _ = minima1ToSiblingInT void

deTimes :: Proxy (l :*: r) -> (Proxy l, Proxy r)
deTimes _ = (Proxy, Proxy)

instance (Ord (CVec ts NRec), VRepeat ts, MinInfoRec l ts, MinInfoRec r ts) => MinInfoRec (l :*: r) ts where
  minInfoRec (deTimes -> (l, r)) pts =
    addSiblingInTs (minInfoRec l pts) (minInfoRec r pts)
instance (MinInfoNonRec l, MinInfoNonRec r) => MinInfoNonRec (l :*: r) where
  minInfoNonRec (deTimes -> (l, r)) = addMinima2 (minInfoNonRec l) (minInfoNonRec r)



instance MinInfoNonRec (T0 Par1) where minInfoNonRec _ = MMap.singleton (1, 0) $ Min 0
instance MinInfoNonRec (T0 Par0) where minInfoNonRec _ = MMap.singleton (0, 1) $ Min 0
instance (VRepeat ts, MinInfoNonRec (T0 Par1)) => MinInfoRec (T0 Par1) ts where
  minInfoRec p _ = minima1ToSiblingInT $ minInfoNonRec p
instance (VRepeat ts, MinInfoNonRec (T0 Par0)) => MinInfoRec (T0 Par0) ts where
  minInfoRec p _ = minima1ToSiblingInT $ minInfoNonRec p



deRec0 :: Proxy (T0 (Rec lbl t)) -> Proxy lbl
deRec0 _ = Proxy

instance (IndexInto lbl ts, VRepeat ts) => MinInfoRec (T0 (Rec lbl t)) ts where
  minInfoRec (deRec0 -> plbl) pts =
    MMap.singleton (cvUpd (cvRepeat 0) (indexInto plbl pts) $ \_ -> 1, 0, 0) $ Min 0

deRec1 :: Proxy (T1 (Rec lbl t) r) -> Proxy lbl
deRec1 _ = Proxy

-- TODO: how to support non-regular data types?

-- NB only supports regular data types for now
instance (IndexInto lbl ts, VRepeat ts) => MinInfoRec (T1 (Rec lbl t) (T0 Par0)) ts where
  minInfoRec (deRec1 -> plbl) pts =
    MMap.singleton (cvUpd (cvRepeat 0) (indexInto plbl pts) $ \_ -> 1, 0, 0) $ Min 0

deRec2 :: Proxy (T2 (Rec lbl t) r s) -> Proxy lbl
deRec2 _ = Proxy

class Regularish r s where
  regularish :: ((r ~ (T0 Par1), s ~ (T0 Par0)) => a) -> ((r ~ (T0 Par0), s ~ (T0 Par1)) => a) -> a
instance Regularish (T0 Par1) (T0 Par0) where regularish x _ = x
instance Regularish (T0 Par0) (T0 Par1) where regularish _ y = y
-- NB no other instances!

-- NB only supports regularish data types for now
instance (Regularish r s, IndexInto lbl ts, VRepeat ts) => MinInfoRec (T2 (Rec lbl t) r s) ts where
  minInfoRec (deRec2 -> plbl) pts =
    MMap.singleton (cvUpd (cvRepeat 0) (indexInto plbl pts) $ \_ -> 1, 0, 0) $ Min 0



deDep0 :: Proxy (T0 (Dep t)) -> Proxy t
deDep0 _ = Proxy

instance (VRepeat ts, MinCtors t, MinInfoNonRec (T0 (Dep t))) => MinInfoRec (T0 (Dep t)) ts where
  minInfoRec p _ = minima1ToSiblingInT $ minInfoNonRec p

instance MinCtors t => MinInfoNonRec (T0 (Dep t)) where
  minInfoNonRec = maybe MMap.empty (MMap.singleton (0, 0) . Min) . minCtors . deDep0






pDTs :: Proxy t -> Proxy (DTs t)
pDTs _ = Proxy

class MinCtorsTrim t where minCtorsTrim :: Proxy t -> Minima2 -> MinCtorsT t
instance MinCtorsTrim (t :: *) where
  minCtorsTrim _ m = getMin `fmap` MMap.lookup (0, 0) m
instance MinCtorsTrim (t :: k0 -> *) where
  minCtorsTrim _ = MMap.mapWithMonoKeys (\(_, nP0) -> nP0) id
instance MinCtorsTrim (t :: k1 -> k0 -> *) where minCtorsTrim _ = id

gen_minCtors :: (MinCtorsTrim t, MinCtorsWorker t (DTs t)) => Proxy t -> MinCtorsT t
gen_minCtors p = minCtorsTrim p $ method p (pDTs p)

type family MinCtorsT (t :: k) :: *
type instance MinCtorsT (t :: *) = Maybe Int
type instance MinCtorsT (t :: k0 -> *) = Minima1
type instance MinCtorsT (t :: k1 -> k0 -> *) = Minima2

class MinCtors t where
  minCtors :: Proxy t -> MinCtorsT t
  default minCtors :: (MinCtorsTrim t, MinCtorsWorker t (DTs t)) => Proxy t -> MinCtorsT t
  minCtors = gen_minCtors

class MinCtorsWorker t dpos where method :: Proxy t -> Proxy dpos -> Minima2

pSiblingDTs :: Proxy t -> Proxy (SiblingDTs t)
pSiblingDTs _ = Proxy

instance MinInfoNonRec (DCs t ('KProxy :: KProxy () ())) => MinCtorsWorker (t :: *) NonRecDT where method pt _ = minInfoNonRec (pDisband0 pt)
instance MinInfoNonRec (DCs t ('KProxy :: KProxy () k0)) => MinCtorsWorker (t :: k0 -> *) NonRecDT where method pt _ = minInfoNonRec (pDisband1 pt)
instance MinInfoNonRec (DCs t ('KProxy :: KProxy k1 k0)) => MinCtorsWorker (t :: k1 -> k0 -> *) NonRecDT where method pt _ = minInfoNonRec (pDisband2 pt)

pIndex :: Proxy (RecDT l r) -> Proxy (Length l)
pIndex _ = Proxy

instance (IndexInto (Length l) (SiblingDTs t),
          VInitialize (MinInfo__ (SiblingDTs t)) (SiblingDTs t),
          VFunctor (SiblingInC (SiblingDTs t)) (SiblingDTs t),
          VRepeat (SiblingDTs t),
          VEnum (SiblingDTs t),
          Eq (CVec (SiblingDTs t) Minima2),
          MinInfoRec (DCs t ('KProxy :: KProxy k1 k0)) (SiblingDTs t)) => MinCtorsWorker (t :: *) (RecDT l r) where
  method pt pdpos = (`cvAt` indexInto (pIndex pdpos) psibs) $ solve_sibling_set' $
                    cvInitialize (pcon psibs) minInfo__
    where psibs = pSiblingDTs pt
          pcon :: Proxy ts -> Proxy (MinInfo__ ts)
          pcon _ = Proxy

instance (IndexInto (Length l) (SiblingDTs t),
          VInitialize (MinInfo__ (SiblingDTs t)) (SiblingDTs t),
          VFunctor (SiblingInC (SiblingDTs t)) (SiblingDTs t),
          VRepeat (SiblingDTs t),
          VEnum (SiblingDTs t),
          Eq (CVec (SiblingDTs t) Minima2),
          MinInfoRec (DCs t ('KProxy :: KProxy k1 k0)) (SiblingDTs t)) => MinCtorsWorker (t :: k0 -> *) (RecDT l r) where
  method pt pdpos = (`cvAt` indexInto (pIndex pdpos) psibs) $ solve_sibling_set' $
                    cvInitialize (pcon psibs) minInfo__
    where psibs = pSiblingDTs pt
          pcon :: Proxy ts -> Proxy (MinInfo__ ts)
          pcon _ = Proxy

instance (IndexInto (Length l) (SiblingDTs t),
          VInitialize (MinInfo__ (SiblingDTs t)) (SiblingDTs t),
          VFunctor (SiblingInC (SiblingDTs t)) (SiblingDTs t),
          VRepeat (SiblingDTs t),
          VEnum (SiblingDTs t),
          Eq (CVec (SiblingDTs t) Minima2),
          MinInfoRec (DCs t ('KProxy :: KProxy k1 k0)) (SiblingDTs t)) => MinCtorsWorker (t :: k1 -> k0 -> *) (RecDT l r) where
  method pt pdpos = (`cvAt` indexInto (pIndex pdpos) psibs) $ solve_sibling_set' $
                    cvInitialize (pcon psibs) minInfo__
    where psibs = pSiblingDTs pt
          pcon :: Proxy ts -> Proxy (MinInfo__ ts)
          pcon _ = Proxy

class    (ts ~ SiblingDTs t) => MinInfo__ ts t where
  minInfo__ :: Proxy t -> SiblingInT ts

instance (MinInfoRec (DCs t ('KProxy :: KProxy () ())) ts, ts ~ SiblingDTs t) => MinInfo__ ts (t :: *) where
  minInfo__ p = minInfoRec (pDisband0 p) (pSiblingDTs p)

instance (MinInfoRec (DCs t ('KProxy :: KProxy () k0)) ts, ts ~ SiblingDTs t) => MinInfo__ ts (t :: k0 -> *) where
  minInfo__ p = minInfoRec (pDisband1 p) (pSiblingDTs p)

instance (MinInfoRec (DCs t ('KProxy :: KProxy k1 k0)) ts, ts ~ SiblingDTs t) => MinInfo__ ts (t :: k1 -> k0 -> *) where
  minInfo__ p = minInfoRec (pDisband2 p) (pSiblingDTs p)









{-

-- T tests support for interesting structures as well as avoiding the recursive
-- branch
data T a = One a | Branch (T a, [T a]) Int

yokoTH ''T





-- S tests one interesting way that the final answer depends on the parameter
data S a = OneS a | BranchS Int Int

yokoTH ''S



-- M1 and M2 exercise the erroneous definition for Recs
data M1 = M1C Int Int Int Int | M1D M2
data M2 = M2C M1

yokoTH ''M1
yokoTH ''M2




yokoTH ''Nat



data Inf = Inf Inf

yokoTH ''Inf





data X a = X a a a a

yokoTH ''X

data Y a = Y (X (X a))

yokoTH ''Y



data Stream a = SCons a (Stream a)
type instance DTs Stream = RecDT '[] '[]

yokoTH ''Stream

data Even a = ENil | ECons a (Odd  a)
data Odd  a =        OCons a (Even a)

yokoTH ''Even
yokoTH ''Odd




instance MinCtors X
instance MinCtors a => MinCtors (X a)

instance MinCtors Y
instance MinCtors a => MinCtors (Y a)

instance MinCtors Stream
instance MinCtors a => MinCtors (Stream a)

instance MinCtors T
instance MinCtors a => MinCtors (T a)
instance MinCtors S
instance MinCtors a => MinCtors (S a)
instance MinCtors M1
instance MinCtors M2
instance MinCtors Inf

instance MinCtors Nat


instance MinCtors Even
instance MinCtors Odd
instance MinCtors a => MinCtors (Even a)
instance MinCtors a => MinCtors (Odd  a)

-}





--------------------
-- usages
instance MinCtors Bool
instance MinCtors ()

-- NB the (yokoTH ''Proxy) splice fails
instance MinCtors Proxy where minCtors = nCtors 1

instance MinCtors (,)
instance MinCtors a => MinCtors ((,) a)
instance (MinCtors a, MinCtors b) => MinCtors ((,) a b)

instance MinCtors a => MinCtors ((,,) a)
instance (MinCtors a, MinCtors b) => MinCtors ((,,) a b)
instance (MinCtors a, MinCtors b, MinCtors c) => MinCtors ((,,) a b c)

instance MinCtors Maybe
instance MinCtors a => MinCtors (Maybe a)

instance MinCtors []
instance MinCtors a => MinCtors [a]

instance MinCtors Either
instance MinCtors a => MinCtors (Either a)
instance (MinCtors a, MinCtors b) => MinCtors (Either a b)

instance MinCtors GHC.Real.Ratio
instance MinCtors a => MinCtors (GHC.Real.Ratio a)
