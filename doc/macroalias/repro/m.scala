package repro
import scala.quoted.*

trait Day

object internal:
  opaque type Timestamp = Long
  type Date = Timestamp { type Form = Day }
  type Monthstamp = Timestamp { type Form = Unit }

  object Date:
    def julianDay(day: Int): Date = day.toLong.asInstanceOf[Date]

object Monthstamp:
  def apply(): internal.Monthstamp = 0L.asInstanceOf[internal.Monthstamp]

inline def opNoArg(): internal.Date = ${dateMacro0}
inline def opArg(left: internal.Monthstamp): internal.Date = ${dateMacro1('left)}

def dateMacro0(using Quotes): Expr[internal.Date] = '{internal.Date.julianDay(0)}
def dateMacro1(left: Expr[internal.Monthstamp])(using Quotes): Expr[internal.Date] =
  '{internal.Date.julianDay(0)}
