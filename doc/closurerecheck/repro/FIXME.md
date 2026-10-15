# No self-contained reproduction yet

The error needs a closure whose body the capture checker first reaches by
completing it on demand, and then again through its closure block. Everything
below was established on 2026-10-15 by differential compilation, against a
3.10.0 compiler built from this repository with every patch but this one
(the "minus" compiler) and the 1.0.1 release (the "patched" one).

## Where it reproduces

**Not on current Soundness.** At `ef3d1ecf46` (2026-10-15), apoplexy's tests
compile identically with and without the patch. The trigger was last present
at Soundness `4208b11e68^` (2026-10-12): check that commit out in a throwaway
worktree, run `./mill show apoplexy.test.compileClasspath` there, and compile
`lib/apoplexy/src/test/apoplexy.CorpusApiTests.scala` (with its `Recorder`
helper copied out of `apoplexy.ApiTests.scala`, and the `demilitarize` tests
cut, since they need the larceny plugin) with that classpath, the module's
options minus the plugins, and the 3.10.0 stdlib jars in place of the 3.9
ones the worktree's toolchain resolves. The minus compiler reports, at
`api.pet(42L).get.attempt[Swagger.Pet]()`, the `(Long is Json.Decodable)^{any}`
versus `^{any²}` mismatch quoted in the feature doc; the patched one compiles.

A one-test probe in that context fails the same way, and reduces to this
(two files, the first compiled first), which is the smallest form known:

```scala
// A_1.scala — against the 2026-10-12 jars of contingency, fulminate, vacuous,
// wisteria, denominative and prepositional
class Oops(using Diagnostics) extends Error(1, 0)(m"oops", null)

trait JD extends Typeclass:                  // a copy of jacinta's Json.Decodable
  def decoded(text: Text): Self
  def shape(): Text
object JD:
  def apply[value](shape0: => Text)(decoder: (value is Decoder)^): (value is JD)^{decoder} = …

object Derivation extends Derivable[JD]:     // wisteria's derivation, as jacinta uses it
  inline def disjunction[derivation: SumReflection]: (derivation is JD)^ = ???
  inline def conjunction[derivation <: Product: ProductReflection]: (derivation is JD)^ =
    JD({ val fields = contexts[derivation](): [field] => context => (label, context.shape())
         fields.length.toString.tt })(text => ???)

def attempt0[error <: Hazard, success](block: Tactic[error]^ ?=> success): success =
  block(using strategies.throwUnsafely[success])

transparent inline def attempted[value](): value =
  attempt0[Oops, value]:
    scala.compiletime.summonInline[value is JD]
    ???
```

```scala
// B_2.scala
given long0: (tactic: Tactic[Hazard]) => ((Long is JD)^{tactic}) = JD(t"whole")(text => ???)

given optional0: [inner <: value, value >: Unset.type: Mandatable to inner]
  => (decodable: => (inner is JD)^)
  => value is JD =
  JD(t"opt:" + decodable.shape())(text => ???)

case class P(id: Optional[Long])
inline given (P is JD) = Derivation.derived
def test = attempted[P]()
```

## What is known to be necessary

Each of these, removed, makes the minus compiler accept the probe:

- `attempted` **compiled separately** (the closure arrives from TASTy) and
  the `attempt0` block over a **concrete** error type, `Oops`: with
  `Tactic[Hazard]` as the block's tactic, or with `long0` asking for
  `Tactic[Oops]`, the field decoder is satisfied by the block's own tactic
  and nothing fresh is minted. As it is, `Tactic[Oops]` is not a
  `Tactic[Hazard]`, so `strategies.throwUnsafely[success]` is instantiated
  afresh inside the shape thunk — once per check of the closure, hence the
  two root capabilities the error names.
- The field decoder reached through a **by-name** `decodable` parameter,
  and the given's **`Mandatable to inner` context bound**: `[inner <: value,
  value >: Unset.type]` with the bound dropped, or an own plain `given` in its
  place, is accepted; so is `Tactic[Oops]` in the given's own clause instead
  of the bound. The absence/nullity/fault/tactic parameters are not needed.
- **wisteria's `contexts`** passing the user's lambda at least one extra
  `aka`-tagged context argument (`Text aka "label"` or `Int & FieldIndex[field]
  aka "index"` suffice; `Default[Optional[field]]` alone, or the label as a
  plain `Text`, do not). Bisecting wisteria's own source, by recompiling it
  in the worktree, removed as *unnecessary*: the derivation graph and its
  lazy given vals (`deriveGraph` can return `derivedOne` directly), the
  shared `wisteria$field$N` val, `aka` on the contextual argument (a cast
  does), beta-reduction in `applyLambda`, the nested `default` macro, and
  `fieldInstance`'s `Implicits.search` (a `summonInline` does).
- jacinta's `Json.Decodable` is **not** needed: a local copy of the trait and
  its `apply` (`JD` above) serves; nor are `Json` as the form, `Morphology`,
  `distillate.Decodable` as a parent, or `Diagnostics` on `attempted`.
- Soundness's `Tactic`/`ThrowTactic` are not needed either: an own
  `trait Tac[-error <: Hazard] extends caps.Unscoped` with an own
  `ThrowTac` works (`caps.SharedCapability` alone leaves a genuine error on
  the patched compiler, since the fresh capability then may not escape the
  thunk; the fork's `caps.SharedUnscoped`, which Soundness uses, does not
  exist in stock 3.10.0).

## What did not reproduce standalone

With no Soundness jars, against stock 3.10.0 and the 1.0.1 release, every
shape below compiles on both. They are kept under `/tmp/red/cr` for now and
are easy to recreate from this list:

- the probe with hand-written derivations: an `inline given` building the
  instance with `summonInline` for the field inside nested lambdas, with or
  without a macro that creates the field instance as a `Symbol.newVal` owned
  by the splice owner and splices it inside the by-name shape thunk;
- the same with jacinta's exact shape-thunk laundering
  (`unsafeAssumePure { () => shape0 }`), with the decoder as a SAM typeclass
  value, with `contexts` yielding tuples, with a frozen `Array[result]^{}`
  cast, with the `& Product` match cast of `derivedOne`, with the derived
  instance bound in a splice-owned `lazy given val`, with wisteria's trait
  layout (`derived`/`derivedOne`/`conjunction`/`contexts` on `this`,
  generic in the typeclass as a type lambda), with a nested `field` macro
  resolving the instance by `Implicits.search` and casting it, with an own
  `Mand` typeclass whose given is a transparent inline macro (needed, so that
  its `Result <: Self` is instantiated to the candidate's abstract member and
  refined afterwards, as `Mandatable` is), and with the lambda application
  beta-reduced in the macro so the bindings carry skolem-typed `aka` tags;
- hand-written transcriptions of the inlined tree (`-Vprint:inlining`) of
  the failing probe as the body of the `inline given`;
- an own macro that places the generated vals under the *closure's*
  anonymous function rather than the enclosing definition: that reports the
  error without the patch, but the patched compiler then crashes in the
  backend (`key not found: val fields`), and `-Ycheck:all` shows wisteria's
  own generated owners are regular, so it is a different route.

What distinguishes wisteria's expansion from these ports is still unknown.
Comparing `-Vprint:inlining` output of the failing probe with that of the
closest port (`v28`) showed one structural difference: wisteria's lambda
application ends up as flat `val contextual$N` bindings whose types carry a
singleton or skolem (`Tagged[wisteria$field$0.type, "contextual"]`,
`Tagged[(?1 : Text), "label"]`), where the port's inliner left an applied
closure literal with the declared parameter types; adding beta-reduction to
the port's macro could not be checked against the old jars, which the 3.10.0
compilers now reject inside macro expansion (cross-version TASTy). The next
attempt should start there, and from the fact that the error needs a fresh
instantiation of a polymorphic capability given inside the thunk.
