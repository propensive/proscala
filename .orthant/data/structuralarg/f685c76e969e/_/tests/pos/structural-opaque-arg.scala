import scala.reflect.Selectable.reflectiveSelectable

object types:
  opaque type Text <: Matchable & Serializable = String
  def text(string: String): Text = string

class Crypto

def test(crypto: Crypto { def ecdsa(digest: types.Text): Int }, digest: types.Text): Int =
  crypto.ecdsa(digest)
