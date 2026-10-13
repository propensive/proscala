import language.experimental.captureChecking

// `file` escapes `usingFile`, inside a closure returned from it
def test = withFile(file => () => file)
