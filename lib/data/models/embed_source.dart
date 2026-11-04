enum EmbedProvider { facebook }

/// A stream address that is a web page rather than an audio file — a Facebook
/// video link an admin pasted as the song's "External" URL. just_audio can't
/// load it as it is, so it plays in Facebook's own embedded player instead
/// (nothing is downloaded or pulled out of the page).
///
/// YouTube links are not handled here: the server fetches their audio and the
/// API hands out the converted file, which plays like any other song.
class EmbedSource {
  const EmbedSource._(this.provider, this.url);

  final EmbedProvider provider;

  /// The link as the admin pasted it.
  final String url;

  static const _facebookVideoPaths = [
    'watch',
    'videos',
    'reel',
    'reels',
    'video.php',
  ];

  /// The embedded player [url] needs, or null when it is an ordinary stream
  /// address (an mp3, an HLS playlist, a YouTube link whose audio the server
  /// converts, …) or a link to something that isn't a single video (a profile,
  /// a post).
  static EmbedSource? tryParse(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
    final host = uri.host.toLowerCase();
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

    if (host == 'fb.watch') {
      return segments.isEmpty
          ? null
          : EmbedSource._(EmbedProvider.facebook, url);
    }
    if (_isHost(host, 'facebook.com') || _isHost(host, 'fb.com')) {
      // /share/v/<id> and /share/r/<id> are video and reel share links; the
      // other /share/ links are posts and profiles.
      final isShareVideo =
          segments.length >= 2 &&
          segments[0] == 'share' &&
          (segments[1] == 'v' || segments[1] == 'r');
      final isVideo =
          isShareVideo || segments.any(_facebookVideoPaths.contains);
      return isVideo ? EmbedSource._(EmbedProvider.facebook, url) : null;
    }
    return null;
  }

  /// [host] is [domain] itself or any subdomain of it (www., m., web., …).
  static bool _isHost(String host, String domain) =>
      host == domain || host.endsWith('.$domain');

  /// The URL of Facebook's own video player for [url], which is what gets
  /// loaded into the web view.
  Uri get facebookPlayerUri => Uri.https(
    'www.facebook.com',
    '/plugins/video.php',
    {'href': url, 'show_text': 'false', 'autoplay': 'true'},
  );
}
