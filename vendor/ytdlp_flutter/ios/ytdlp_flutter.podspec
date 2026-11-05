#
# ytdlp_flutter — iOS backend.
#
# Embeds CPython (BeeWare Python-Apple-support) and a bundled yt-dlp zipapp.
# `prepare_command` downloads Python.xcframework, the yt-dlp .pyz, and a CA
# bundle at `pod install` time (cached in ios/, gitignored).
#
# NOTE: two app-target Xcode build phases are still required (copying the
# per-SDK python stdlib and signing binary modules) — see the plugin README
# and ios/scripts/install_python_stdlib.sh.
#
Pod::Spec.new do |s|
  s.name             = 'ytdlp_flutter'
  s.version          = '0.1.0'
  s.summary          = 'Run yt-dlp on-device via an embedded CPython.'
  s.description      = <<-DESC
Runs a bundled yt-dlp inside an embedded CPython interpreter (BeeWare
Python-Apple-support), serving jobs from Dart over a file-based protocol.
                       DESC
  s.homepage         = 'https://github.com/statecs/ytdlp_flutter'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'statecs' => 'cs.state@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  s.prepare_command = 'sh scripts/fetch_deps.sh'

  s.vendored_frameworks = 'Python.xcframework'
  # worker.py / yt-dlp.pyz / cacert.pem are NOT pod resources on purpose:
  # iOS frameworks are shallow, so resources land at the framework root,
  # where App Store validation flags script-like files as unsigned code
  # (ITMS-90035). The install_python_stdlib.sh build phase copies them into
  # the app bundle root instead, where plain .py/.pyz files pass validation
  # (the python-stdlib does already).

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    # CocoaPods links vendored dynamic xcframeworks at the app target but
    # not at this pod's own link step, where PythonBridge.o needs the
    # CPython symbols — add the linkage explicitly. The matching slice is
    # copied to XCFrameworkIntermediates (already on FRAMEWORK_SEARCH_PATHS)
    # before compilation.
    'OTHER_LDFLAGS' => '$(inherited) -framework Python',
  }
  s.swift_version = '5.0'
  s.resource_bundles = { 'ytdlp_flutter_privacy' => ['Resources/PrivacyInfo.xcprivacy'] }
end
