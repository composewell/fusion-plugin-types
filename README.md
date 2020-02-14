# fusion-plugin-types

[![Hackage](https://img.shields.io/hackage/v/fusion-plugin-types.svg?style=flat)](https://hackage.haskell.org/package/fusion-plugin-types)
![](https://github.com/composewell/fusion-plugin-types/workflows/Haskell%20CI/badge.svg)

## Motivation

This package provides types used by the fusion-plugin package. By
depending on this module instead of
[fusion-plugin](https://github.com/composewell/fusion-plugin) you
won't be bringing in the ghc dependency there by not tying your
package to a ghc core library.

## Using the package

To enable support for using the fusion-plugin plugin, add this package to your `build-depends` and annotate your types with `Fuse` type from this package.

```haskell
import Fusin.Plugin.Types (Fuse (..))

{-# ANN type Step Fuse #-}
data Step s a = Yield a s | Skip s | Stop
```

## See Also

* [fusion-plugin](https://github.com/composewell/fusion-plugin)
