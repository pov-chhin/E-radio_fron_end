import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../../../data/models/embed_source.dart';
import '../../../data/models/now_playing_item.dart';
import '../../../l10n/gen/app_localizations.dart';
import '../../../providers/audio_player_controller.dart';

/// Facebook's own video player for a Facebook link ([item] must have an
/// [NowPlayingItem.embed]), in a web view, with an "Open in Facebook" link
/// under it for a video that can't be embedded. It starts playing as soon as
/// it is on screen and tells the audio controller so; closing the page stops it.
class EmbeddedVideo extends ConsumerStatefulWidget {
  const EmbeddedVideo({super.key, required this.item});

  final NowPlayingItem item;

  @override
  ConsumerState<EmbeddedVideo> createState() => _EmbeddedVideoState();
}

class _EmbeddedVideoState extends ConsumerState<EmbeddedVideo> {
  late final AudioPlayerController _playback;
  late final WebViewController _web;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _playback = ref.read(audioPlayerControllerProvider.notifier);
    final EmbedSource embed = widget.item.embed!;
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigation,
          onWebResourceError: (error) {
            if ((error.isForMainFrame ?? true) && mounted) {
              setState(() => _failed = true);
            }
          },
        ),
      )
      ..loadRequest(embed.facebookPlayerUri);
    final platform = _web.platform;
    if (platform is AndroidWebViewController) {
      // Let the video start by itself.
      platform.setMediaPlaybackRequiresUserGesture(false);
    }
    // Facebook's player can't be asked how it is doing, so it counts as playing
    // from the moment it is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _report(true));
  }

  /// The player page and what it loads stay in the web view; a tap on anything
  /// else (the page's title, a link) opens in the browser or the Facebook app
  /// instead of turning this into a browser.
  NavigationDecision _onNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    final inPlayer =
        uri != null &&
        uri.host.endsWith('facebook.com') &&
        uri.path.startsWith('/plugins/');
    if (!request.isMainFrame || inPlayer || request.url == 'about:blank') {
      return NavigationDecision.navigate;
    }
    _openOutside(request.url);
    return NavigationDecision.prevent;
  }

  void _report(bool playing) {
    if (mounted) _playback.reportEmbedPlaying(widget.item.id, playing);
  }

  Future<void> _openOutside(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (error) {
      debugPrint('Opening $url failed: $error');
    }
  }

  @override
  void dispose() {
    // The video stops with the page; say so once the tree is done unmounting
    // (a provider can't change in the middle of that).
    final playback = _playback;
    final id = widget.item.id;
    Future.microtask(() => playback.reportEmbedPlaying(id, false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: WebViewWidget(controller: _web),
        ),
        if (_failed)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              l10n.videoCantPlayHere,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        TextButton.icon(
          onPressed: () => _openOutside(widget.item.streamUrl),
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: Text(l10n.openInFacebook),
        ),
      ],
    );
  }
}
