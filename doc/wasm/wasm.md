# WIT / WebAssembly Component Model support

Vendors scala-wasm's WIT (WebAssembly Interface Types) support into the Scala.js backend, so Scala code can be compiled into WASM components that import and export typed WIT interfaces.

## Context

WebAssembly on its own only understands numbers: a `.wasm` module's imports and exports are functions over `i32`/`i64`/`f32`/`f64`. The **Component Model** is the layer above that which makes WASM modules composable: a *component* declares its interface in **WIT** (WebAssembly Interface Types), a small IDL with records, variants, flags, resources (handles to host objects), strings, lists, results and so on. Tooling then generates the "canonical ABI" glue that lifts and lowers these rich types across the component boundary, so a component written in Scala can call one written in Rust, or implement a WASI interface such as `wasi:cli/run`, without either side knowing about the other's runtime.

Scala.js 1.17+ has an experimental WasmBackend that compiles Scala.js IR directly to WebAssembly (rather than JavaScript), but upstream it still targets the JS embedding. The **scala-wasm** project extends that backend to emit standalone WASM *components* — which requires the compiler to know which Scala definitions correspond to WIT imports, exports and data types. This branch (`feature/3.9/wasm`, based on `feature/3.9/make`) vendors that support onto the Proscala 3.9 compiler, in three commits: the WIT-extended Scala.js IR (v1.22.0-wasm.4) into `compiler/src-scalajs-ir`, the backend/codegen changes, and the `scala.scalajs.wit` user-facing library into `library-js` — plus a Makefile switch of the sjs stdlib to the `io.github.scala-wasm` runtime and a fix for a `ScopedVar` crash when generating WIT member defs at class scope.

## What the feature provides

A new `scala.scalajs.wit` package in the Scala.js standard library:

- **Annotations** (`scala.scalajs.wit.annotation`):
  - `@WitImport(module, name)` — a method whose body is `wit.native`, imported from another component (e.g. a WASI host function).
  - `@WitExport(module, name)` — a method exported from this component; declared on a `@WitExportInterface` trait and implemented in a `@WitImplementation` object.
  - `@WitRecord` — a final case class mapped to a WIT `record`.
  - `@WitVariant` — a sealed trait of case classes/objects mapped to a WIT `variant` (declaration order fixes the discriminant indices; each case carries at most one `value` field).
  - `@WitFlags(n)` — a final case class wrapping an `Int` bitset, mapped to WIT `flags`.
  - Resource annotations — `@WitResourceImport(module, name)` on a trait representing a host resource handle, with `@WitResourceConstructor`, `@WitResourceMethod`, `@WitResourceStaticMethod` and `@WitResourceDrop` on its members.
- **Types**: `Result[A, B]` with `Ok`/`Err` (WIT `result`), `Tuple2`–`TupleN` (WIT `tuple`), and `wit.unsigned.{UByte, UShort, UInt, ULong}` aliases for WIT's unsigned integer types.
- `wit.native`, the placeholder body for imported members (analogous to `js.native`).

## How it works

Conceptually, three layers:

1. **PrepJSInterop validation.** The Scala.js prep phase gains a `checkWitAnnotations` pass that validates every WIT-annotated definition early, with clear errors: `@WitRecord` must be a final class whose fields are Component-Model-compatible; `@WitVariant` must be a sealed trait/abstract class with at least one valid case; `@WitFlags` must wrap a single `Int value`; resource annotations must appear in the right context; and every parameter/result type of a `@WitImport`/`@WitExport` function is checked against a recursive `isComponentModelCompatible` predicate (primitives, `String`, unsigned aliases, `wit.Tuple*`, `wit.Result`, and WIT-annotated types).

2. **WitCodeGen.** A new `compiler/src/dotty/tools/backend/sjs/WitCodeGen.scala` (~470 lines), driven from `JSCodeGen`, detects WIT annotations during class generation and emits the WIT-specific IR: `WitNativeMemberDef` for imports and resource members (carrying module name, WIT function name and a `wit.FuncType` signature), `WitExportDef` wrapping the implementing `MethodDef` for exports, `WitFunctionApply` for calls to imported members, and `NativeWasmComponentResourceClass` class defs for `@WitResourceImport` traits. Its `toWIT` conversion maps Scala types to WIT `ValType`s (records, variants, flags, tuples, options, lists…) using pre-erasure type information.

3. **IR extensions.** The vendored Scala.js IR adds `WasmInterfaceTypes.scala` (the WIT type algebra) plus new tree nodes, tags, serializers and types, so the linker's WASM backend can later generate the component's canonical-ABI lifts/lowers and the `.wit` world from the emitted defs.

## Code

Exporting a WASI command entry point and importing a host function:

```scala
import scala.scalajs.wit
import scala.scalajs.wit.annotation.*
import scala.scalajs.wit.{Result, Ok}

object Host {
  @WitImport("example:host/utils@0.1.0", "log")
  def log(message: String): Unit = wit.native
}

@WitExportInterface
trait Run {
  @WitExport("wasi:cli/run@0.2.0", "run")
  def run(): Result[Unit, Unit]
}

@WitImplementation
object RunImpl extends Run {
  def run(): Result[Unit, Unit] = {
    Host.log("Hello from a Scala WASM component!")
    Ok(())
  }
}
```

Modelling WIT data types:

```scala
import scala.scalajs.wit.annotation.*

@WitRecord
final case class Point(x: Int, y: Int)

@WitVariant
sealed trait Status
object Status {
  case object Pending extends Status
  final case class Failed(value: String) extends Status
}
```
