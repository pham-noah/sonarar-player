#
# ytdlp_flutter — macOS backend.
#
# Embeds CPython in-process (BeeWare Python-Apple-support, a full
# Python.framework whose stdlib lives inside the framework) and runs a
# bundled yt-dlp zipapp via the same file-based worker protocol as iOS.
#
# Why in-process: sandboxed apps cannot run yt-dlp as a subprocess — the
# sandbox quarantines runtime downloads (exec EPERM), and even a bundled
# PyInstaller binary dies on SysV semaphores (semctl EPERM). Embedding
# avoids exec entirely.
#
Pod::Spec.new do |s|
  s.name             = 'ytdlp_flutter'
  s.version          = '0.1.0'
  s.summary          = 'Run yt-dlp on-device via an embedded CPython.'
  s.description      = <<-DESC
Runs a bundled yt-dlp inside an embedded CPython interpreter, serving jobs
from Dart over a file-based protocol.
                       DESC
  s.homepage         = 'https://github.com/statecs/ytdlp_flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'statecs' => 'cs.state@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'FlutterMacOS'
  s.platform = :osx, '11.0'

  s.prepare_command = 'sh scripts/fetch_deps.sh'

  s.vendored_frameworks = 'Python.xcframework'
  # Plain resources land in this pod's framework bundle.
  s.resources = [
    'Resources/worker.py',
    'Resources/yt-dlp.pyz',
    'Resources/cacert.pem',
  ]

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    # CocoaPods links vendored dynamic xcframeworks at the app target but
    # not at this pod's own link step, where PythonBridge.o needs the
    # CPython symbols.
    'OTHER_LDFLAGS' => '$(inherited) -framework Python',
  }
  s.swift_version = '5.0'
end
