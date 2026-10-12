# Writes Many.scala: one capture-checked method that refers to another capability-
# taking method $1 times, each reference registering a dependent of `use`'s use set.
n="${1:-3000}"
{
  echo 'import language.experimental.captureChecking'
  echo 'def use(io: Object^): Unit = ()'
  echo 'def caller(io: Object^): Unit ='
  for ((i = 0; i < n; i++)); do echo '  use(io)'; done
} > Many.scala
