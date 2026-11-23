// The inner layer of a method's context-function result chain may capture the outer
// layer's parameter: erasure flattens both layers into the method's own parameters.
// Here the layers are not dependent function types, so they are matched by shape.

trait Tactic[-E] extends caps.SharedCapability:
  def abort(e: E): Nothing
infix type raises[R, E] = Tactic[E]^ ?=> R

object lib:
  def query(n: Int): List[Int] raises String raises Int =
    if n < 0 then summon[Tactic[Int]].abort(n)
    if n > 9 then summon[Tactic[String]].abort("big")
    List(n)

object umbrella:
  export lib.query

// Three layers: the middle one captures the outer one's parameter, and the inner one
// captures both, in a chain none of whose layers is a dependent function type.
object lib3:
  def query(n: Int): List[Int] raises String raises Int raises Boolean =
    if n < 0 then summon[Tactic[Int]].abort(n)
    if n > 9 then summon[Tactic[String]].abort("big")
    if n == 5 then summon[Tactic[Boolean]].abort(true)
    List(n)

object umbrella3:
  export lib3.query
