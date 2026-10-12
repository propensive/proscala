package ethereal

import soundness.*

import classloaders.systemClassloader
import environments.javaBaseEnvironment
import systems.javaBaseSystem
import temporaryDirectories.systemTemporaryDirectory
import logging.silentLogging
import strategies.throwUnsafely

object Tests:
  def run(): Unit =
    val launcher = Enclave(t"e").dispatch('{ 42 })
