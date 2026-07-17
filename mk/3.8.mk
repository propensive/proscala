# Per-stream build configuration for the 3.8 stream (tracks scala/scala3
# `release-3.8.4`). Included by the top-level Makefile once STREAM is known.
# $(JARS) is defined by the Makefile before this file is included.

VERSION            := 3.8.4-propensive
REF_VERSION        := 3.8.3
SCALAJS_VERSION    := 1.20.2
COMPILER_IFACE_VER := 1.10.7
UTIL_IFACE_VER     := 1.10.7
JLINE_VERSION      := 3.29.0
COURSIER_IFACE_VER := 1.0.28
LZ4_VERSION        := 1.8.0
LZ4_GROUP          := org/lz4
GUAVA_VERSION      := 33.2.1-jre
FAILUREACCESS_VER  := 1.0.2
# The 3.8.4 tree is not warning-clean under -Werror, so leave it empty.
WERROR_FLAGS       :=

# This tree has no scala3-directives-parser module, so the repl pulls pprint /
# fansi / sourcecode and the using_directives parser from Maven instead.
EXTRA_MAVEN_PATHS := \
  com/lihaoyi/pprint_3/0.9.3/pprint_3-0.9.3.jar \
  com/lihaoyi/fansi_3/0.5.1/fansi_3-0.5.1.jar \
  com/lihaoyi/sourcecode_3/0.4.4/sourcecode_3-0.4.4.jar \
  org/virtuslab/using_directives/1.1.4/using_directives-1.1.4.jar
REPL_EXTRA_JARS := \
  $(JARS)/pprint_3-0.9.3.jar $(JARS)/fansi_3-0.5.1.jar \
  $(JARS)/sourcecode_3-0.4.4.jar $(JARS)/using_directives-1.1.4.jar
