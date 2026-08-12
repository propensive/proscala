package dotty.tools.backend.jvm

import dotty.DottyBytecodeTest
import dotty.tools.dotc.util.{SmapRegistry, SourceFile}

import org.junit.Assert.*
import org.junit.Test

/** Tests for the JSR-45 SourceDebugExtension emitted under -Xjsr45. */
class Jsr45Test extends DottyBytecodeTest:
  import dotty.AsmConverters.*

  override def initCtx =
    val ctx0 = super.initCtx
    ctx0.setSetting(ctx0.settings.Xjsr45, true)

  /** An `*L` entry: input line, file id, repeat count, output start line. */
  private case class LineEntry(inputLine: Int, fileId: Int, repeat: Int, outputLine: Int)

  private val LineEntryPattern = """(\d+)#(\d+)(?:,(\d+))?:(\d+)""".r

  /** Does `entry` (possibly a coalesced run) map input line `line` of file `fileId`? */
  private def covers(entry: LineEntry, line: Int, fileId: Int): Boolean =
    entry.fileId == fileId && line >= entry.inputLine && line < entry.inputLine + entry.repeat

  /** The `*L` entries of the given stratum of `smap`. */
  private def lineEntries(smap: String, stratum: String): List[LineEntry] =
    val start = smap.indexOf(s"*S $stratum")
    assertTrue(s"no $stratum stratum in SMAP:\n$smap", start >= 0)
    val section = smap.substring(start).linesIterator.drop(1).takeWhile(!_.startsWith("*S")).toList
    section.collect {
      case LineEntryPattern(in, fid, rep, out) =>
        LineEntry(in.nn.toInt, fid.nn.toInt, if rep == null then 1 else rep.toInt, out.nn.toInt)
    }

  @Test def inlineAcrossFiles(): Unit =
    val util =
      """|object Util:
         |  inline def twice(inline x: Int): Int =
         |    x + x
         |""".stripMargin
    val main =
      """|class Main:
         |  def run(): Int =
         |    Util.twice(21)
         |""".stripMargin

    checkBCode(List(util, main)) { dir =>
      val utilClass = loadClassNode(lookupClass(dir, "Util$.class"), skipDebugInfo = false)
      assertNull("unit without foreign inlining should carry no SMAP", utilClass.sourceDebug)

      val mainClass = loadClassNode(lookupClass(dir, "Main.class"), skipDebugInfo = false)
      val smap = mainClass.sourceDebug
      assertNotNull("Main should carry a SourceDebugExtension", smap)
      assertTrue(smap.startsWith("SMAP\n"))
      assertTrue(smap.endsWith("*E\n"))

      val scala = lineEntries(smap, "Scala")
      val identity = scala.head
      assertEquals("identity mapping for the primary file", LineEntry(1, 1, identity.repeat, 1), identity)
      val primaryLines = identity.repeat

      // `x + x` on line 3 of Util maps to a synthetic line past the end of Main's source
      val synthetic = scala.tail
      assertTrue(s"expected a synthetic entry in:\n$smap", synthetic.nonEmpty)
      assertTrue(synthetic.forall(_.outputLine > primaryLines))
      assertTrue(s"expected Util line 3 in:\n$smap",
        synthetic.exists(e => covers(e, 3, 2)))

      // ScalaDebug maps the same synthetic lines back to the call site, Main line 3
      val debug = lineEntries(smap, "ScalaDebug")
      assertTrue(s"expected call-site entry in:\n$smap",
        debug.exists(e => e.inputLine == 3 && e.fileId == 1 && e.outputLine > primaryLines))

      // ScalaClass names the top-level class each synthetic line was inlined from
      val classes = lineEntries(smap, "ScalaClass")
      assertTrue(s"expected a ScalaClass entry per synthetic line in:\n$smap",
        classes.map(_.outputLine).sorted == synthetic.flatMap(e =>
          e.outputLine until e.outputLine + e.repeat).sorted)
      assertTrue(classes.forall(_.inputLine == 1))
      assertTrue(s"expected class Util in:\n$smap",
        smap.linesIterator.exists(_.matches("\\d+ Util")))

      // and the method body actually uses a synthetic line
      val lines = instructionsFromMethod(getMethod(mainClass, "run")).collect { case ln: LineNumber => ln.line }
      assertTrue(s"expected a synthetic line number in $lines", lines.exists(_ > primaryLines))
    }

  @Test def nestedInlineAcrossThreeFiles(): Unit =
    // plain (non-inline) parameters, so the expansions are not constant-folded away
    val a =
      """|object A:
         |  inline def core(x: Int): Int =
         |    x * 2
         |""".stripMargin
    val b =
      """|object B:
         |  inline def outer(x: Int): Int =
         |    A.core(x) + 1
         |""".stripMargin
    val main =
      """|class Main:
         |  def run(x: Int): Int =
         |    B.outer(x)
         |""".stripMargin

    checkBCode(List(a, b, main)) { dir =>
      val mainClass = loadClassNode(lookupClass(dir, "Main.class"), skipDebugInfo = false)
      val smap = mainClass.sourceDebug
      assertNotNull("Main should carry a SourceDebugExtension", smap)

      val scala = lineEntries(smap, "Scala")
      val primaryLines = scala.head.repeat
      val synthetic = scala.tail
      // both A's and B's code appear, from two distinct foreign files
      assertTrue(s"expected two foreign files in:\n$smap", synthetic.map(_.fileId).distinct.size >= 2)

      // the ScalaDebug chain: some synthetic line's call site is itself synthetic
      // (B's call of A.core lies inside inlined code), and some call site is a real
      // line of the primary file (Main's call of B.outer)
      val debug = lineEntries(smap, "ScalaDebug")
      assertTrue(s"expected a synthetic-to-synthetic hop in:\n$smap",
        debug.exists(_.inputLine > primaryLines))
      assertTrue(s"expected a hop to the primary file in:\n$smap",
        debug.exists(e => e.inputLine <= primaryLines && e.fileId == 1))

      // ScalaClass names both defining classes
      assertTrue(s"expected classes A and B in:\n$smap",
        smap.linesIterator.exists(_.matches("\\d+ A"))
        && smap.linesIterator.exists(_.matches("\\d+ B")))
    }

  @Test def sameFileInlineNeedsNoSmap(): Unit =
    val main =
      """|object Main:
         |  inline def twice(inline x: Int): Int = x + x
         |  def run(): Int = twice(21)
         |""".stripMargin

    checkBCode(List(main)) { dir =>
      val mainClass = loadClassNode(lookupClass(dir, "Main$.class"), skipDebugInfo = false)
      assertNull("same-file inlining needs no SMAP", mainClass.sourceDebug)
    }

/** Direct tests of SMAP allocation and serialization. */
class SmapRegistryTest:
  private def source(name: String, lines: Int): SourceFile =
    SourceFile.virtual(name, (1 to lines).map(i => s"// line $i").mkString("\n"))

  import SmapRegistry.Frame

  @Test def lockstepRunsCoalesce(): Unit =
    val primary = source("Main.scala", 10)
    val util = source("Util.scala", 5)
    val registry = SmapRegistry(primary)
    val first = registry.outputLineFor(List(Frame(util, 2, "Util"), Frame(primary, 7, "")))
    val second = registry.outputLineFor(List(Frame(util, 3, "Util"), Frame(primary, 7, "")))
    assertEquals(first + 1, second)
    // identical chains share their output line
    assertEquals(first, registry.outputLineFor(List(Frame(util, 2, "Util"), Frame(primary, 7, ""))))

    val smap = registry.serialize("Main.scala", Set(first, second))
    assertTrue(s"expected coalesced run in:\n$smap", smap.contains(s"2#2,2:$first\n"))
    assertTrue(s"expected call-site entries in:\n$smap",
      smap.contains(s"7#1:$first\n") && smap.contains(s"7#1:$second\n"))
    assertTrue(s"expected ScalaClass entries in:\n$smap",
      smap.contains("*S ScalaClass\n*F\n1 Util\n")
      && smap.contains(s"1#1:$first\n") && smap.contains(s"1#1:$second\n"))

  @Test def nestedChainsAllocateCallSites(): Unit =
    val primary = source("Main.scala", 10)
    val a = source("A.scala", 5)
    val b = source("B.scala", 5)
    val registry = SmapRegistry(primary)
    val inner = registry.outputLineFor(
      List(Frame(a, 3, "A"), Frame(b, 2, "B"), Frame(primary, 4, "")))
    val smap = registry.serialize("Main.scala", Set(inner))
    // the chain allocated a line for B's call site too, and the ScalaDebug entry
    // for A's code points at it (a synthetic line, not a primary line)
    val hop = s"#\\d+:$inner\n".r.findAllIn(smap).toList
    assertTrue(s"expected entries for line $inner in:\n$smap", hop.nonEmpty)
    assertTrue(s"expected synthetic call site in:\n$smap",
      smap.linesIterator.exists(l => l.endsWith(s":$inner") && l.takeWhile(_.isDigit).toInt > 10))
    // the suffix chain's entry names B's class; the full chain's names A's
    assertTrue(s"expected classes A and B in ScalaClass of:\n$smap",
      smap.linesIterator.exists(_.matches("\\d+ A"))
      && smap.linesIterator.exists(_.matches("\\d+ B")))

  @Test def onlyUsedLinesAreEmitted(): Unit =
    val primary = source("Main.scala", 10)
    val util = source("Util.scala", 5)
    val other = source("Other.scala", 5)
    val registry = SmapRegistry(primary)
    val used = registry.outputLineFor(List(Frame(util, 2, "Util"), Frame(primary, 7, "")))
    val unused = registry.outputLineFor(List(Frame(other, 3, "Other"), Frame(primary, 8, "")))

    val smap = registry.serialize("Main.scala", Set(used))
    assertTrue(s"expected the used line in:\n$smap", smap.contains(s":$used\n"))
    assertTrue(s"unused line $unused should be absent from:\n$smap", !smap.contains(s":$unused\n"))
    assertTrue(s"unused file should be absent from:\n$smap", !smap.contains("Other.scala"))
    assertTrue(s"unused class should be absent from:\n$smap",
      !smap.linesIterator.exists(_.matches("\\d+ Other")))

    // a class which emitted no synthetic line at all needs no SMAP
    assertEquals("", registry.serialize("Main.scala", Set(3)))

  @Test def callSiteChainIsClosedOver(): Unit =
    val primary = source("Main.scala", 10)
    val a = source("A.scala", 5)
    val b = source("B.scala", 5)
    val registry = SmapRegistry(primary)
    val inner = registry.outputLineFor(
      List(Frame(a, 3, "A"), Frame(b, 2, "B"), Frame(primary, 4, "")))

    // only the innermost line was emitted, but its call site is itself synthetic, so the
    // entry describing that call site must come along or the chain would dead-end
    val smap = registry.serialize("Main.scala", Set(inner))
    val debugSection = smap.substring(smap.indexOf("*S ScalaDebug"))
    val hop = "(\\d+)#\\d+:%d".format(inner).r.findFirstMatchIn(debugSection).map(_.group(1).nn.toInt)
    assertTrue(s"expected a synthetic call site for $inner in:\n$smap", hop.exists(_ > 10))
    assertTrue(s"expected that call site's own entry in:\n$smap",
      hop.exists(line => smap.contains(s":$line\n")))
