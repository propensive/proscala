object Use:
  // Calling a macro defined in the same compilation suspends this unit: it
  // is compiled again in a second run, where boxing an Int looks at
  // java.lang.Integer's annotations.
  val s: String = Macro.greeting
  val boxed: Any = 2
