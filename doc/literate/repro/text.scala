// The library side: an opaque Text with a Literate instance, as Soundness's
// anticipation defines it.
package repro

object textual:
  opaque type Text <: Matchable = String

  object Text:
    inline def make(inline string: String): Text = string

  extension (text: Text) def s: String = text

import textual.Text

final class TextLiterate[str <: String & Singleton] extends Literate[str]:
  type Result = Text { type Topic = str }
  inline def convert(inline value: str): Result = value.asInstanceOf[Result]

object prelude:
  given literate: [str <: String & Singleton] => TextLiterate[str] = TextLiterate[str]()
