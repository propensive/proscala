/* NSC -- new Scala compiler
 * Copyright 2005-2012 LAMP/EPFL
 * @author Paul Phillips
 */

package dotty.tools

package object io {
  type JManifest = java.util.jar.Manifest
  type JFile = java.io.File
  type JPath = java.nio.file.Path

  // Backported from the 3.10 stream ("Improve IO package encapsulation",
  // upstream da99eb87b0), where the VirtualDirectory constructor became
  // private[io] and this factory is the sanctioned way to obtain an in-memory
  // directory. Providing it here lets tooling compile against the same API on
  // both streams.
  def virtualDirectory(name: String): AbstractFile =
    new VirtualDirectory(name)
}
