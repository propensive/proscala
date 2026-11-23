def closure(): () => Boolean = 1.lendInline(h ?=> () => h.alive) // error
