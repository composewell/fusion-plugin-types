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
  , InspectTypes(..)
  , InspectTypeClasses(..)
  , MaxCoreSize(..)
  , DumpCore(..)
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
-- At most one 'FuseTypes' annotation is allowed per binding (attaching more
-- than one is a compile error); list all the types in the single annotation.
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
-- At most one 'NoFuseTypes' annotation is allowed per binding (attaching more
-- than one is a compile error); list all the types in the single annotation.
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
-- The names must be /type/ names (double quote, e.g. @''Int@), not data
-- constructor names (single quote, e.g. @'I#@). Occurrences are matched by
-- their type constructor, so to exclude boxed @Int@s from a report write
-- @''Int@, not @'I#@. Passing a data constructor such as @'I#@ silently
-- matches nothing (its type constructor @Int@ is what appears in core), even
-- though the report may /display/ the constructor name.
--
-- At most one 'InspectTypes' annotation is allowed per binding (attaching
-- more than one is a compile error); combine everything you need to check
-- into a single directive. Each example below annotates a /different/
-- binding:
--
-- @
-- {-\# ANN function1 (ForbidFused [] []) #-}
-- {-\# ANN function1a (ForbidFused [''Maybe] []) #-}
-- {-\# ANN function1b (ForbidFused [''Maybe] [''Step]) #-}
-- {-\# ANN function2 (ForbidTypes [''Maybe]) #-}
-- {-\# ANN function3 (PermitTypes [''Int, ''IO]) #-}
-- @
data InspectTypes
    = ForbidFused [Name] [Name]
    -- ^ Report occurrences of every 'Fuse'-annotated type found in the
    -- binding -- the same base set the module-wide report uses -- plus any
    -- types named in the first (forbid) list, minus any types named in the
    -- second (allow) list. A name present in both is allowed (the allow-list
    -- wins). @ForbidFused [] []@ enforces just the baseline: nothing
    -- 'Fuse'-annotated may survive to core.
    | ForbidTypes [Name]
    -- ^ Blocklist: report occurrences of exactly the named
    -- types/constructors found anywhere in the binding, regardless of
    -- whether they carry a 'Fuse' annotation. Everything else in core is
    -- fine.
    | PermitTypes [Name]
    -- ^ Allowlist: report occurrences of literally every type/constructor
    -- found in the binding -- a general "boxing detector", not limited to
    -- 'Fuse'-annotated types -- except the named types, which may appear
    -- freely.
    deriving (Eq, Data)

-- | A GHC annotation attached to a specific top level binding (via an @ANN@
-- pragma on the binding) that checks for the presence or absence of type
-- classes in the optimized Core of that binding. A type class appears in Core
-- as a dictionary argument; a class that survives to Core is usually a symptom
-- of a dictionary that failed to specialize away.
--
-- Like 'InspectTypes', the check works regardless of the module-wide
-- @-fplugin-opt=Fusion.Plugin:verbose=N@ flag: an annotated binding is always
-- reported. The names must be /class/ names (double quote, e.g. @''Num@).
--
-- At most one 'InspectTypeClasses' annotation is allowed per binding
-- (attaching more than one is a compile error). Each example below annotates
-- a /different/ binding:
--
-- @
-- {-\# ANN function1 (ForbidTypeClasses [''Num]) #-}
-- {-\# ANN function2 (PermitTypeClasses [''Ord, ''Eq]) #-}
-- @
data InspectTypeClasses
    = ForbidTypeClasses [Name]
    -- ^ Blocklist: report occurrences of exactly the named classes found
    -- anywhere in the Core of the binding. Any other class is fine.
    | PermitTypeClasses [Name]
    -- ^ Allowlist: report every class found in the Core of the binding except
    -- the named classes, which may appear freely.
    deriving (Eq, Data)

-- | A GHC annotation attached to a specific top level binding (via an @ANN@
-- pragma on the binding) that sets a maximum on the number of terms in the
-- optimized Core of that binding, measured after all fusion-plugin passes
-- have run. If the binding exceeds the given size the plugin reports a
-- violation.
--
-- This is useful for tracking the Core size of a hot binding: an unexpected
-- blow-up in size is often a symptom of failed fusion, runaway inlining, or
-- SpecConstr optimization blowing up.
--
-- By default (or at @-fplugin-opt=Fusion.Plugin:verbose=1@) the plugin prints
-- a message only when the size is exceeded. At @verbose=2@ and above it also
-- prints the detailed Core size of the binding regardless of whether the
-- limit is exceeded.
--
-- At most one 'MaxCoreSize' annotation is allowed per binding (attaching more
-- than one is a compile error).
--
-- @
-- {-\# ANN myFunction (MaxCoreSize 1000) #-}
-- @
data MaxCoreSize = MaxCoreSize Int
    deriving (Eq, Data)

-- | A GHC annotation attached to a specific top level binding (via an @ANN@
-- pragma on the binding) that makes the plugin dump the optimized Core of that
-- binding, after all fusion-plugin passes have run, to a file.
--
-- The Core is written to a file under the @fusion-plugin-output@ directory, in
-- a subdirectory named after the package being compiled, in a file whose name
-- is the full module name and the binding name joined with a @.@, with a
-- @.dump-simpl@ suffix. For example, a binding @myFunction@ in module
-- @Data.Stream@ of package @my-pkg@ is written to
-- @fusion-plugin-output\/my-pkg\/Data.Stream.myFunction.dump-simpl@.
--
-- This is useful for inspecting the final Core of a hot binding without having
-- to wade through the Core of the entire module.
--
-- At most one 'DumpCore' annotation is allowed per binding (attaching more
-- than one is a compile error).
--
-- @
-- {-\# ANN myFunction DumpCore #-}
-- @
data DumpCore = DumpCore
    deriving (Eq, Data)
