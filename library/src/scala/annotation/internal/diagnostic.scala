package scala.annotation
package internal

/** Marks a `given` whose macro-implemented right-hand side may abort expansion with
 *  `report.errorAndAbort` while being tried as an implicit candidate. The candidate
 *  then fails the search normally, but its reported errors become the authoritative
 *  message if the overall search fails.
 */
final class diagnostic extends StaticAnnotation
