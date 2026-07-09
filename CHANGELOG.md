## 0.1.1

* Add `InspectTypes` for per-binding fusion inspection via `ANN` pragmas.
* Add `FuseTypes` to mark types as fusible for inlining within a single
  binding only, via an `ANN` pragma on that binding.
* Add `NoFuseTypes` annotation to locally override `Fuse` for a binding.
* Add `ShowCoreSize` annotation to report the Core size of a binding.

## 0.1.0

* Initial release
