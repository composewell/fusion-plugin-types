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
  , FuseTypes(..)
  , NoFuseTypes(..)
  , Inspect(..)
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

-- | A GHC annotation attached to a specific top level binding (via an @ANN@
-- pragma on the binding, not on a type) that makes each of the listed types
-- behave as if it were annotated with 'Fuse', but /only/ for the purpose of
-- inlining within that one binding -- not anywhere else in the module.
--
-- This is the per-binding counterpart of 'Fuse'. Whereas @{-\# ANN type Step
-- Fuse #-}@ marks @Step@ as fusible everywhere it is used, @{-\# ANN myFunc
-- (FuseTypes [''Step]) #-}@ marks @Step@ (and any other listed types) as
-- fusible only while inlining inside @myFunc@. This is useful when a type
-- should drive fusion in one function but should not force inlining wherever
-- else it happens to be used.
--
-- Type references are Template Haskell 'Name's (e.g. @''Step@), not plain
-- strings, so a typo or a later rename of the referenced type is caught by
-- GHC's ordinary renamer when the @ANN@ pragma is compiled -- a "not in scope"
-- compile error, not a silently-stale annotation. Using @''Foo@ requires
-- @{-\# LANGUAGE TemplateHaskellQuotes \#-}@ (or the heavier @TemplateHaskell@)
-- in the annotated module.
--
-- @
-- {-\# ANN myFunc (FuseTypes [''Step, ''MyMaybe]) #-}
-- @
newtype FuseTypes = FuseTypes [Name]
    deriving (Eq, Data)

-- | A GHC annotation attached to a specific top level binding (via an @ANN@
-- pragma on the binding, not on a type) that makes each of the listed types
-- behave as if it were /not/ annotated with 'Fuse', but /only/ for the purpose
-- of inlining within that one binding -- not anywhere else in the module.
--
-- This is the local override of 'Fuse' (and of 'FuseTypes'). Whereas @{-\# ANN
-- type Step Fuse #-}@ marks @Step@ as fusible everywhere it is used, @{-\# ANN
-- myFunc (NoFuseTypes [''Step]) #-}@ suppresses that fusion for @Step@ (and any
-- other listed types) while inlining inside @myFunc@, disabling the forced
-- inlining those types would otherwise drive there. Fusion of those types
-- everywhere else in the module is unaffected. This is useful when a type
-- should drive fusion in general but should not force inlining inside one
-- particular function.
--
-- Type references are Template Haskell 'Name's (e.g. @''Step@), not plain
-- strings, to keep it typed, Using @''Foo@ requires @{-\# LANGUAGE
-- TemplateHaskellQuotes \#-}@ (or the heavier @TemplateHaskell@) in the
-- annotated module.
--
-- @
-- {-\# ANN myFunc (NoFuseTypes [''Step, ''MyMaybe]) #-}
-- @
newtype NoFuseTypes = NoFuseTypes [Name]
    deriving (Eq, Data)

-- | A GHC annotation attached to a specific top level binding (via an
-- @ANN@ pragma on the binding, not on a type) that requests a focused
-- fusion report for just that binding, independent of the module-wide
-- @-fplugin-opt=Fusion.Plugin:verbose=N@ flag.
--
-- Type references are Template Haskell 'Name's (e.g. @''Step@), not plain
-- strings. This means a typo, or a later rename of the referenced type in
-- source, is caught by GHC's ordinary renamer when the @ANN@ pragma itself
-- is compiled -- a "not in scope" compile error, not a silently-stale
-- check. Using @''Foo@ requires @{-\# LANGUAGE TemplateHaskellQuotes \#-}@
-- (or the heavier @TemplateHaskell@) in the annotated module.
--
-- @
-- {-\# ANN function1 (FusionForbidAllow [] []) #-}
-- {-\# ANN function1a (FusionForbidAllow [''Text] []) #-}
-- {-\# ANN function1b (FusionForbidAllow [''Text] [''ByteString]) #-}
-- {-\# ANN function2 (AllowAllExcept [''SomeType]) #-}
-- {-\# ANN function3 (ForbidAllExcept [''Int, ''IO]) #-}
-- @
data Inspect
    = FusionForbidAllow [Name] [Name]
    -- ^ Report occurrences of every 'Fuse'-annotated type found in the
    -- binding -- the same base set the module-wide report uses -- plus any
    -- types named in the first (forbid) list, minus any types named in the
    -- second (allow) list. A name present in both is allowed (the allow-list
    -- wins). @FusionForbidAllow [] []@ enforces just the baseline: nothing
    -- 'Fuse'-annotated may survive to core.
    | AllowAllExcept [Name]
    -- ^ Blocklist: report occurrences of exactly the named
    -- types/constructors found anywhere in the binding, regardless of
    -- whether they carry a 'Fuse' annotation. Everything else in core is
    -- fine.
    | ForbidAllExcept [Name]
    -- ^ Allowlist: report occurrences of literally every type/constructor
    -- found in the binding -- a general "boxing detector", not limited to
    -- 'Fuse'-annotated types -- except the named types, which may appear
    -- freely.
    deriving (Eq, Data)
