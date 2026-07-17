# Per-stream build configuration for the 3.10 stream (tracks scala/scala3 `main`).
# Included by the top-level Makefile once STREAM is known. Only the settings that
# genuinely differ between streams live here; everything else is shared and
# tree-detected. $(JARS) is defined by the Makefile before this file is included.

VERSION            := 3.10.0-dev-propensive
REF_VERSION        := 3.9.0-RC1
BASE_SCALAJS_VERSION    := 1.22.0
COMPILER_IFACE_VER := 1.12.0
UTIL_IFACE_VER     := 1.11.5
JLINE_VERSION      := 4.0.14
COURSIER_IFACE_VER := 1.0.29-M4
LZ4_VERSION        := 1.8.1
LZ4_GROUP          := at/yawk/lz4
GUAVA_VERSION      := 33.6.0-jre
FAILUREACCESS_VER  := 1.0.3
# -Werror is enabled on warning-clean trees (main / 3.9.0-RC1).
WERROR_FLAGS       := -Werror

# This tree carries the scala3-directives-parser module and a leaner repl, so it
# needs no extra Maven artifacts beyond the common set.
EXTRA_MAVEN_PATHS  :=
REPL_EXTRA_JARS    :=
