import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Arrays;

/** Points a classfile's TASTY attribute at a different TASTy file.
 *
 *      java mk/TastySync.java <classfile> <old.tasty> <new.tasty>
 *
 *  A Scala 3 classfile names its TASTy by the 16-byte UUID in the TASTy file's
 *  header, and the compiler warns that the two are "out of sync" if they differ.
 *  The scala-library step of the Makefile takes some classfiles from the
 *  reference stdlib while keeping the TASTy this build compiled (see
 *  `filesToKeep` there); this rewrites the UUID in such a classfile, from that of
 *  the reference's TASTy to that of ours. The UUID is replaced in place, so no
 *  offset in the classfile changes; it must occur exactly once.
 */
public class TastySync {
  public static void main(String[] args) throws Exception {
    if (args.length != 3) fail("usage: TastySync <classfile> <old.tasty> <new.tasty>");
    Path classfile = Path.of(args[0]);
    byte[] bytes = Files.readAllBytes(classfile);
    byte[] from = uuid(Path.of(args[1]));
    byte[] to = uuid(Path.of(args[2]));

    int found = -1;
    for (int i = 0; i + 16 <= bytes.length; i++)
      if (Arrays.equals(bytes, i, i + 16, from, 0, 16)) {
        if (found >= 0) fail(classfile + ": the TASTy UUID of " + args[1] + " occurs more than once");
        found = i;
      }
    if (found < 0) fail(classfile + ": does not name the TASTy file " + args[1]);

    System.arraycopy(to, 0, bytes, found, 16);
    Files.write(classfile, bytes);
  }

  /** The UUID in a TASTy file's header, which follows the magic number, three
   *  version numbers and the name of the tool that wrote it. */
  static byte[] uuid(Path tasty) throws Exception {
    byte[] bytes = Files.readAllBytes(tasty);
    int[] magic = {0x5C, 0xA1, 0xAB, 0x1F};
    for (int i = 0; i < 4; i++)
      if ((bytes[i] & 0xFF) != magic[i]) fail(tasty + ": not a TASTy file");

    int[] position = {4};
    for (int i = 0; i < 3; i++) nat(bytes, position);
    int tooling = nat(bytes, position);
    position[0] += tooling;
    return Arrays.copyOfRange(bytes, position[0], position[0] + 16);
  }

  /** A natural number in TASTy's encoding: base 128, big-endian, the last digit marked by its high bit. */
  static int nat(byte[] bytes, int[] position) {
    int value = 0;
    while (true) {
      int digit = bytes[position[0]++] & 0xFF;
      value = (value << 7) | (digit & 0x7F);
      if ((digit & 0x80) != 0) return value;
    }
  }

  static void fail(String message) {
    System.err.println("TastySync: " + message);
    System.exit(1);
  }
}
