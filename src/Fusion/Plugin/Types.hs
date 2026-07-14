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
  (
  -- * Annotations
  -- | This module contains annotations to be used with the GHC @ANN@ pragma on
  -- a type or a binding.
  --
  -- Type references are Template Haskell 'Name's (e.g. @''Step@), not plain
  -- strings, to allow compile time checking of the names.
  --
  -- At most one annotation is allowed per binding (attaching more than one is
  -- a compile error).

  -- ** Fusion Annotations
  -- | Annotations to force inlining for fusion.
    Fuse(..)
  , FuseTypes(..)
  , NoFuseTypes(..)
  , NoFuse(..)

  -- ** Inspection Annotations
  -- | Annotations to find fusion violations.
  , InspectTypes(..)
  , InspectTypeClasses(..)
  , MaxCoreSize(..)

  -- ** Debugging Annotations
  , DumpCore(..)
  , DumpCorePasses(..)
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
-- @
-- {-\# ANN myFunc (FuseTypes [''Step, ''Maybe]) #-}
-- @
newtype FuseTypes = FuseTypes [Name]
    deriving (Eq, Data)

-- | A GHC annotation attached to a specific top level binding (via an @ANN@
-- pragma on the binding, not on a type) that makes each of the listed types
-- behave as if it were /not/ annotated with 'Fuse', but /only/ for the purpose
-- of inlining within that one binding -- not anywhere else in the module. This
-- is applicable for any nested bindings within the scope of that binding.
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
-- @
-- {-\# ANN myFunc (NoFuseTypes [''Step]) #-}
-- @
newtype NoFuseTypes = NoFuseTypes [Name]
    deriving (Eq, Data)

-- | A GHC annotation attached to a specific top level binding (via an @ANN@
-- pragma on the binding, not on a type) that disables forced inlining of that
-- binding and any nested bindings within the scope of that binding altogether,
-- regardless of which types are involved.
--
-- @
-- {-\# ANN myFunc NoFuse #-}
-- @
data NoFuse = NoFuse
    deriving (Eq, Data)

-- | A GHC annotation attached to a specific top level binding (via an @ANN@
-- pragma on the binding, not on a type) that requests a fusion report for just
-- that binding.
--
-- The names must be /type/ names (double quote, e.g. @''Int@), not data
-- constructor names (single quote, e.g. @'I#@). Occurrences are matched by
-- their type constructor, so to exclude boxed @Int@s from a report write
-- @''Int@, not @'I#@. Passing a data constructor such as @'I#@ silently
-- matches nothing, even though the report may /display/ the constructor name.
--
-- @
-- {-\# ANN function1 (ForbidFused [] []) #-}
-- {-\# ANN function1a (ForbidFused [''Maybe] []) #-}
-- {-\# ANN function1b (ForbidFused [''Maybe] [''Step]) #-}
-- {-\# ANN function2 (ForbidBoxedUse [''Maybe]) #-}
-- {-\# ANN function3 (PermitBoxedUse [''Int, ''IO]) #-}
-- {-\# ANN function4 (PermitPatternMatches [''Int, ''IO]) #-}
-- {-\# ANN function5 (PermitAllocations [''Int, ''IO]) #-}
-- @
data InspectTypes
    = ForbidFused [Name] [Name]
    -- ^ Report occurrences of every 'Fuse'-annotated type found in the binding
    -- -- plus any types named in the first (forbid) list, minus any types
    -- named in the second (allow) list. A name present in both lists is
    -- allowed.
    | ForbidBoxedUse [Name]
    -- ^ Blocklist: report occurrences of exactly the named types/constructors
    -- found anywhere in the binding, regardless of whether they carry a 'Fuse'
    -- annotation. Everything else in core is fine.
    | PermitBoxedUse [Name]
    -- ^ Allowlist: report occurrences of literally every type/constructor
    -- found in the binding -- a general "boxing detector", not limited to
    -- 'Fuse'-annotated types -- except the named types, which may appear
    -- freely.
    | PermitPatternMatches [Name]
    -- ^ Like 'PermitBoxedUse' but only reports occurrences in a scrutinizing
    -- (pattern-match, i.e. @case@) position -- a value being deconstructed --
    -- ignoring constructing positions. Reports every type pattern-matched in
    -- the binding except the named types, which may appear freely.
    | PermitAllocations [Name]
    -- ^ Like 'PermitBoxedUse' but only reports occurrences in a constructing
    -- (allocating) position -- a value being built -- ignoring scrutinizing
    -- positions. Reports every type constructed in the binding except the
    -- named types, which may appear freely.
    deriving (Eq, Data)

-- | A GHC annotation attached to a specific top level binding (via an @ANN@
-- pragma on the binding) that checks for the presence or absence of type
-- classes in the optimized Core of that binding. A type class appears in Core
-- as a dictionary argument; a class that makes it to the Core is usually a
-- symptom of a dictionary that failed to specialize.
--
-- The names must be /class/ names (double quote, e.g. @''Num@).
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
-- @
-- {-\# ANN myFunction (MaxCoreSize 1000) #-}
-- @
newtype MaxCoreSize = MaxCoreSize Int
    deriving (Eq, Data)

-- | A GHC annotation attached to a specific top level binding (via an @ANN@
-- pragma on the binding) that makes the plugin dump the optimized Core of that
-- binding, after all fusion-plugin passes have run, to a file.
--
-- The Core is written to GHC's dump directory (as set by @-dumpdir@) if one is
-- set, otherwise to a per-package subdirectory of @fusion-plugin-output@. For
-- example, a binding @myFunction@ in module @Data.Stream@ of package @my-pkg@
-- is written to @\<dump-dir\>\/Data.Stream.myFunction.dump-simpl@, or to
-- @fusion-plugin-output\/my-pkg\/Data.Stream.myFunction.dump-simpl@ when no
-- dump directory is set.
--
-- Note that the @fusion-plugin-output@ fallback directory is created in the
-- current directory from where GHC is invoked; when building with cabal that is
-- usually the directory in which the cabal file of the package resides.
--
-- This is useful for inspecting the final Core of a hot binding without having
-- to wade through the Core of the entire module.
--
-- @
-- {-\# ANN myFunction DumpCore #-}
-- @
data DumpCore = DumpCore
    deriving (Eq, Data)

-- | A GHC annotation attached to a specific top level binding (via an @ANN@
-- pragma on the binding) that makes the plugin dump the Core of that binding
-- /after every Core-to-core pass/, each to its own file. This is the
-- per-binding counterpart of the @dump-core@ plugin option: whereas
-- @dump-core@ dumps the Core of the /whole module/ after each pass,
-- 'DumpCorePasses' dumps only the annotated binding (and the closure of top
-- level bindings it reaches).
--
-- The files are written to the same directory and with the same
-- @\<module\>.@ prefix as the 'DumpCore' annotation output -- GHC's dump
-- directory (as set by @-dumpdir@) if one is set, otherwise a per-package
-- subdirectory of @fusion-plugin-output@ -- so all of a module's fusion-plugin
-- dumps cluster together under one prefix. Each file is named
-- @\<module\>.\<binder\>.\<NN-pass\>.dump-simpl@, where the per-pass suffix (a
-- two digit pass counter and the pass name) is the same one the @dump-core@
-- option uses for its per-pass files. For example, a binding @myFunction@ in
-- module @Data.Stream@ of package @my-pkg@ produces one file per pass:
--
-- @
-- -- with @-dumpdir dir@:
-- dir\/Data.Stream.myFunction.00-Initial.dump-simpl
-- dir\/Data.Stream.myFunction.01-After-...\.dump-simpl
-- ...
-- -- otherwise:
-- fusion-plugin-output\/my-pkg\/Data.Stream.myFunction.00-Initial.dump-simpl
-- ...
-- @
--
-- This is useful for understanding how the Core of a single binding evolves
-- across the optimizer pipeline, without wading through the Core of the entire
-- module at every pass.
--
-- @
-- {-\# ANN myFunction DumpCorePasses #-}
-- @
data DumpCorePasses = DumpCorePasses
    deriving (Eq, Data)
