## 0.1.1

* Add `InspectTypes` annotations for inspecting types and allocations present
  within a binding.
* Add `InspectTypeClasses` annotations for type class dictionary inspection
  within a binding.
* Add `FuseTypes` annotation for making types locally fusible within a
  specific binding.
* Add `NoFuse` annotation for disabling any `Fuse` data type annotation
  inside a binding.
* Add `NoFuseTypes` annotation for disabling `Fuse` annotation for specific
  types within a binding.
* Add `MaxCoreSize` annotation to report if core size of a binding
  exceeds a certain threashold.
* Add `DumpCore` annotation to write the optimized core of a binding to a
  file.
* Add `DumpCorePasses` annotation to write the core of a binding to a file
  after every Core-to-core pass.

## 0.1.0

* Initial release
