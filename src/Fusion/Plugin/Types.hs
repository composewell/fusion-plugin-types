-- |
-- Module      : Fusion.Plugin.Types
-- Copyright   : (c) 2020 Composewell Technologies
--
-- License     : BSD-3-Clause
-- Maintainer  : pranaysashank@composewell.com
-- Stability   : experimental
-- Portability : GHC

{-# LANGUAGE DeriveDataTypeable #-}

module Fusion.Plugin.Types
  ( Fuse(..)
  , Inspect(..)
  , FuseSpec
  , checkFusion
  , forbid
  , allow
  , forbidTypes
  , allowOnlyTypes
  )
where

import Data.Data (Data)
import Language.Haskell.TH.Syntax (Name)

-- | A GHC annotation to inform the plugin to aggressively inline join points
-- that perform a case match on the constructors of the annotated type.
-- Inlining enables case-of-case transformations that would potentially
-- eliminate the constructors.
--
-- This annotation is to be used on types whose constructors are known to be
-- involved in case-of-case transformations enabling stream fusion via
-- elimination of those constructors.
--
-- It is advised to use unique types for intermediate stream state that is to
-- be annotated with 'Fuse'. If the annotated type is also used for some
-- other purpose this annotation may inline code that is not involved in stream
-- fusion and should otherwise not be inlined.
--
-- @
-- {-\# ANN type Step Fuse #-}
-- data Step s a = Yield a s | Skip s | Stop
-- @
data Fuse = Fuse
    deriving (Eq, Data)

-- | A GHC annotation attached to a specific top level binding (via an
-- @ANN@ pragma on the binding, not on a type) that requests a focused
-- fusion report for just that binding, independent of the module-wide
-- @-fplugin-opt=Fusion.Plugin:verbose=N@ flag.
--
-- Build values of this type via 'checkFusion', 'forbidTypes', or
-- 'allowOnlyTypes' rather than the raw constructors.
--
-- Type references are Template Haskell 'Name's (e.g. @''Step@), not plain
-- strings. This means a typo, or a later rename of the referenced type in
-- source, is caught by GHC's ordinary renamer when the @ANN@ pragma itself
-- is compiled -- a "not in scope" compile error, not a silently-stale
-- check. Using @''Foo@ requires @{-\# LANGUAGE TemplateHaskellQuotes \#-}@
-- (or the heavier @TemplateHaskell@) in the annotated module.
data Inspect
    = ForbidTypes [Name]
    -- ^ Built via 'forbidTypes'.
    | CheckFusion [Name] [Name]
    -- ^ Built via 'checkFusion'.
    | AllowOnlyTypes [Name]
    -- ^ Built via 'allowOnlyTypes'.
    deriving (Eq, Data)

-- | A composable specification of extra types to forbid, and types to
-- allow, on top of the baseline set of 'Fuse'-annotated types checked by
-- 'checkFusion'. Build one with 'forbid' and/or 'allow' and combine them
-- with @('<>')@; 'mempty' means "just the baseline".
data FuseSpec = FuseSpec
    { fuseSpecForbid :: [Name]
    , fuseSpecAllow :: [Name]
    }

instance Semigroup FuseSpec where
    FuseSpec f1 a1 <> FuseSpec f2 a2 = FuseSpec (f1 <> f2) (a1 <> a2)

instance Monoid FuseSpec where
    mempty = FuseSpec [] []

-- | Also forbid the named types, even though they carry no 'Fuse'
-- annotation. Used with 'checkFusion'.
forbid :: [Name] -> FuseSpec
forbid names = mempty { fuseSpecForbid = names }

-- | Allow the named types even if they are 'Fuse'-annotated or otherwise
-- forbidden -- an overriding allow-list. Used with 'checkFusion'.
allow :: [Name] -> FuseSpec
allow names = mempty { fuseSpecAllow = names }

-- | Report occurrences of every 'Fuse'-annotated type found in the binding
-- -- the same base set the module-wide report uses -- plus any types named
-- via 'forbid', minus any types named via 'allow'. A name present in both
-- is allowed (the allow-list wins). @checkFusion mempty@ enforces just the
-- baseline: nothing 'Fuse'-annotated may survive to core.
--
-- @
-- {-\# ANN function1 (checkFusion mempty) #-}
-- {-\# ANN function1a (checkFusion (forbid [''Text])) #-}
-- {-\# ANN function1b (checkFusion (forbid [''Text] <> allow [''ByteString])) #-}
-- @
checkFusion :: FuseSpec -> Inspect
checkFusion (FuseSpec f a) = CheckFusion f a

-- | Blocklist: report occurrences of exactly the named types/constructors
-- found anywhere in the binding, regardless of whether they carry a 'Fuse'
-- annotation. Everything else in core is fine.
--
-- @
-- {-\# ANN function2 (forbidTypes [''SomeType]) #-}
-- @
forbidTypes :: [Name] -> Inspect
forbidTypes = ForbidTypes

-- | Allowlist: report occurrences of literally every type/constructor found
-- in the binding -- a general "boxing detector", not limited to
-- 'Fuse'-annotated types -- except the named types, which may appear
-- freely.
--
-- @
-- {-\# ANN function3 (allowOnlyTypes [''Int, ''IO]) #-}
-- @
allowOnlyTypes :: [Name] -> Inspect
allowOnlyTypes = AllowOnlyTypes
