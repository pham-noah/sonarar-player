library;

const String kBundledManifest = 'assets/library/library_manifest.json';

const String kBundledPlaylists = 'assets/config/playlists.json';

const String kAppName = 'Sonarar';

const String kAndroidLibraryRoot = '/storage/emulated/0/Music/Sonarar';

const String kManifestFileName = 'library_manifest.json';

String kCoverHeroTag(String trackId) => 'personar/cover/$trackId';

const double kTargetLufs = -16.0;

const Duration kDefaultCrossfade = Duration(milliseconds: 0);

const Duration kSleepFadeOut = Duration(seconds: 20);

const double kHomeLatitude = 10.8231;
const double kHomeLongitude = 106.6297;

const Duration kWeatherRefreshInterval = Duration(minutes: 30);

const Duration kWeatherTimeout = Duration(seconds: 10);
