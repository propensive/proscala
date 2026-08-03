//> using options -language:experimental.spreadable
import scala.language.experimental.spreadable
import lib.*

@main def Test =
  def sum(xs: Int*): Int = xs.sum
  def count[T](xs: T*): Int = xs.length
  def bytes(bs: Byte*): Int = bs.length
  println(sum(Series(1,2,3)*))            // 1. cast, zero cost
  println(bytes(Data(1,2,3)*))            // 2. IArray-flavoured alias
  println(sum(Trie(List(4,5))*))          // 3. real conversion
  println(count(Series(1,2,3)*))          // inference: T := Int
