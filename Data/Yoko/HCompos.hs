{-# LANGUAGE TypeFamilies, TypeOperators, MultiParamTypeClasses,
  FlexibleContexts, FlexibleInstances, UndecidableInstances,
  ScopedTypeVariables  #-}

{-# OPTIONS_GHC -fcontext-stack=250 #-}

module Data.Yoko.HCompos (Idiom, HCompos(..)) where

import Data.Yoko.TypeBasics
import Data.Yoko



import Control.Applicative





instance HCompos cnv sum t => HCompos cnv (DCsOf a sum) t where
  hcompos cnv = hcompos cnv . unDCsOf





type family Idiom cnv :: * -> *
class Applicative (Idiom cnv) => HCompos cnv a t where
  hcompos :: cnv -> a -> Idiom cnv t





instance (HCompos cnv a t, HCompos cnv b t
         ) => HCompos cnv (a :+: b) t where
  hcompos cnv = foldPlus (hcompos cnv) (hcompos cnv)

-- NB only works if there's exactly one matching constructor
instance (Generic dc, Just (N dc') ~ FindDCs (Tag dc) (DCs t),
          HComposRs cnv (Rep dc) (Rep dc'),
          DC dc', Range dc' ~ t, DT t
         ) => HCompos cnv (N dc) t where
  hcompos cnv = 
    foldN $ liftA (rejoin . (id :: dc' -> dc') . obj) . mapRs cnv . rep



type family FindDCs s sum
type instance FindDCs s (N dc) =
  If (Equal s (Tag dc)) (Just (N dc)) Nothing
type instance FindDCs s (a :+: b) = DistMaybePlus (FindDCs s a) (FindDCs s b)



-- applies cnv to every Rec in a product; identity on other factors
class Applicative (Idiom cnv) => HComposRs cnv prod prod' where
  mapRs :: cnv -> prod -> Idiom cnv prod'

instance HCompos cnv a b => HComposRs cnv (Rec a) (Rec b) where
  mapRs cnv (Rec x) = Rec <$> hcompos cnv x

instance Applicative (Idiom cnv) => HComposRs cnv (Dep a) (Dep a) where
  mapRs _ = pure
instance Applicative (Idiom cnv) => HComposRs cnv U       U       where
  mapRs _ = pure

instance (HComposRs cnv a a', HComposRs cnv b b'
         ) => HComposRs cnv (a :*: b) (a' :*: b') where
  mapRs cnv (a :*: b) = (:*:) <$> mapRs cnv a <*> mapRs cnv b
