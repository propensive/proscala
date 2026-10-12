# Writes Many.scala: one capture-checked method that refers to another capability-
# taking method $1 times, each reference registering a dependent of `use`'s use set.
# The references are grouped into blocks of 30 statements: the compiler walks a
# block's statements recursively, so 3,000 statements in one block would overflow
# a 1 MB thread stack (the default on x86-64 Linux, e.g. CI) for reasons that have
# nothing to do with this patch.
n="${1:-3000}"
{
  echo 'import language.experimental.captureChecking'
  echo 'def use(io: Object^): Unit = ()'
  echo 'def caller(io: Object^): Unit ='
  for ((i = 0; i < n; i += 30)); do
    echo '  locally:'
    for ((j = i; j < i + 30 && j < n; j++)); do echo '    use(io)'; done
  done
} > Many.scala
