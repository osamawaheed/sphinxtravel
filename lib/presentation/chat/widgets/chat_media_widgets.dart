import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfx/pdfx.dart';
import 'package:video_player/video_player.dart';

import '../../../models/chat_models.dart';
import '../../../theme/app_theme.dart';
import '../chat_strings.dart';

/// Resolves a (cached) short-lived signed URL for a message attachment.
typedef ChatUrlResolver = Future<String?> Function({bool forceRefresh});

enum ChatMediaKind { image, video, pdf, document }

ChatMediaKind chatMediaKindOf(ChatMessage m) {
  final mime = (m.fileMime ?? '').toLowerCase();
  final name = (m.fileName ?? '').toLowerCase();
  if (mime.startsWith('image/') ||
      RegExp(r'\.(jpe?g|png|webp|gif)$').hasMatch(name)) {
    return ChatMediaKind.image;
  }
  if (mime == 'video/mp4' ||
      mime == 'video/webm' ||
      RegExp(r'\.(mp4|webm)$').hasMatch(name)) {
    return ChatMediaKind.video;
  }
  if (mime == 'application/pdf' || name.endsWith('.pdf')) {
    return ChatMediaKind.pdf;
  }
  return ChatMediaKind.document;
}

// ---------------------------------------------------------------- image

/// Tile sizing shared by image / video / PDF previews. The tile width is fixed
/// to the bubble width; the height follows the media aspect ratio (clamped so
/// extreme panoramas / tall screenshots stay reasonable).
const double kChatMediaMinAspect = 0.6; // tallest: 5:3 portrait
const double kChatMediaMaxAspect = 1.8; // widest landscape

double chatClampAspect(double? a) => (a == null || a.isNaN || a <= 0)
    ? 1.0
    : a.clamp(kChatMediaMinAspect, kChatMediaMaxAspect).toDouble();

Widget _mediaPlaceholder({Widget? child}) => Container(
  color: const Color(0xFFE9E4DA),
  alignment: Alignment.center,
  child:
      child ??
      const SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(strokeWidth: 2.4),
      ),
);

/// Instant optimistic preview of an image that is still uploading: decoded
/// from the local (already compressed) bytes at a bounded size, with a
/// spinner overlay. Never touches the network.
class ChatLocalUploadingImage extends StatefulWidget {
  final Uint8List bytes;
  const ChatLocalUploadingImage({super.key, required this.bytes});

  @override
  State<ChatLocalUploadingImage> createState() =>
      _ChatLocalUploadingImageState();
}

class _ChatLocalUploadingImageState extends State<ChatLocalUploadingImage> {
  double? _aspect;
  late final MemoryImage _provider = MemoryImage(widget.bytes);
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    final stream = ResizeImage(
      _provider,
      width: 600,
    ).resolve(const ImageConfiguration());
    final listener = ImageStreamListener((info, _) {
      final w = info.image.width.toDouble();
      final h = info.image.height.toDouble();
      if (mounted && h > 0) setState(() => _aspect = w / h);
    });
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  @override
  void dispose() {
    final l = _listener;
    if (l != null) _stream?.removeListener(l);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: chatClampAspect(_aspect),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: ResizeImage(_provider, width: 600),
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
          Container(
            color: Colors.black.withValues(alpha: 0.28),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2.6,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Static image thumbnail used inside the long-press overlay. Shows the real
/// image (local bytes while uploading, otherwise the signed URL) and never a
/// filename or attachment icon.
class ChatOverlayImage extends StatefulWidget {
  final ChatMessage message;
  final ChatUrlResolver resolveUrl;
  final Uint8List? localBytes;
  final double width;

  const ChatOverlayImage({
    super.key,
    required this.message,
    required this.resolveUrl,
    required this.width,
    this.localBytes,
  });

  @override
  State<ChatOverlayImage> createState() => _ChatOverlayImageState();
}

class _ChatOverlayImageState extends State<ChatOverlayImage> {
  String? _url;
  bool _failed = false;
  double? _aspect;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    if (widget.localBytes == null) {
      _load();
    } else {
      _watch(MemoryImage(widget.localBytes!));
    }
  }

  @override
  void dispose() {
    final l = _listener;
    if (l != null) _stream?.removeListener(l);
    super.dispose();
  }

  Future<void> _load() async {
    final url = await widget.resolveUrl(forceRefresh: false);
    if (!mounted) return;
    setState(() {
      _url = url;
      _failed = url == null;
    });
    if (url != null) _watch(NetworkImage(url));
  }

  void _watch(ImageProvider base) {
    final stream = ResizeImage(
      base,
      width: 720,
    ).resolve(const ImageConfiguration());
    final listener = ImageStreamListener(
      (info, _) {
        final h = info.image.height.toDouble();
        if (mounted && h > 0) {
          setState(() => _aspect = info.image.width.toDouble() / h);
        }
      },
      onError: (_, __) {
        if (mounted) setState(() => _failed = true);
      },
    );
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  Widget _placeholder({bool broken = false}) => Container(
    color: AppTheme.softGoldBg,
    alignment: Alignment.center,
    child: broken
        ? Icon(
            Icons.broken_image_outlined,
            color: AppTheme.secondaryText,
            size: 36,
          )
        : const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
  );

  Widget _image() {
    final local = widget.localBytes;
    final ImageProvider? base = local != null
        ? MemoryImage(local)
        : (_url != null ? NetworkImage(_url!) : null);
    if (base == null) return _placeholder(broken: _failed);
    return Image(
      image: ResizeImage(base, width: 720),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (context, error, stack) => _placeholder(broken: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: AspectRatio(
          aspectRatio: chatClampAspect(_aspect),
          child: _image(),
        ),
      ),
    );
  }
}

/// Inline image inside a chat bubble. Fills the bubble edge-to-edge (the
/// bubble clips the rounded corners), keeps the aspect ratio of the decoded
/// image (portrait stays vertical, landscape horizontal) and uses BoxFit.cover.
/// A failed load refreshes the signed URL once before showing a retry fallback.
class ChatInlineImage extends StatefulWidget {
  final ChatMessage message;
  final ChatStrings strings;
  final ChatUrlResolver resolveUrl;
  final VoidCallback onOpenViewer;

  const ChatInlineImage({
    super.key,
    required this.message,
    required this.strings,
    required this.resolveUrl,
    required this.onOpenViewer,
  });

  @override
  State<ChatInlineImage> createState() => _ChatInlineImageState();
}

class _ChatInlineImageState extends State<ChatInlineImage> {
  /// Last resolved signed URL per message id. A freshly built tile (e.g. the
  /// long-press overlay snapshot) starts from this so the thumbnail is visible
  /// immediately instead of a placeholder.
  static final Map<String, String> _urlMemo = <String, String>{};

  String? _url;
  bool _failed = false;
  bool _refreshed = false;
  double? _aspect;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  /// Decode width (logical px * dpr) so large originals are never decoded at
  /// full resolution for a ~300 px wide chat tile.
  static const int _decodeWidth = 720;

  @override
  void initState() {
    super.initState();
    final memo = _urlMemo[widget.message.id];
    if (memo != null) {
      _url = memo;
      _resolveAspect(memo);
    }
    _load();
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _detach() {
    final l = _listener;
    if (l != null) _stream?.removeListener(l);
    _listener = null;
    _stream = null;
  }

  Future<void> _load({bool force = false}) async {
    final url = await widget.resolveUrl(forceRefresh: force);
    if (!mounted) return;
    if (url != null) _urlMemo[widget.message.id] = url;
    final changed = url != _url;
    setState(() {
      _url = url;
      _failed = url == null;
    });
    if (url != null && (changed || _stream == null)) _resolveAspect(url);
  }

  /// Learns the real image size from the (cached) decoded image so the tile
  /// can match portrait / landscape without distortion.
  void _resolveAspect(String url) {
    _detach();
    // Same provider (and cache key) as the Image widget below, so the bytes
    // are downloaded and decoded ONCE and shared via the image cache.
    final stream = ResizeImage(
      NetworkImage(url),
      width: _decodeWidth,
    ).resolve(const ImageConfiguration());
    final listener = ImageStreamListener(
      (info, _) {
        final w = info.image.width.toDouble();
        final h = info.image.height.toDouble();
        if (mounted && h > 0) setState(() => _aspect = w / h);
      },
      onError: (_, __) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _onImageError());
      },
    );
    _stream = stream;
    _listener = listener;
    stream.addListener(listener);
  }

  Future<void> _onImageError() async {
    if (!mounted) return;
    if (!_refreshed) {
      _refreshed = true;
      await _load(force: true);
    } else {
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final aspect = chatClampAspect(_aspect);
    Widget body;
    if (_failed) {
      body = InkWell(
        onTap: () {
          setState(() {
            _failed = false;
            _url = null;
            _refreshed = false;
          });
          _load(force: true);
        },
        child: _mediaPlaceholder(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.broken_image_outlined,
                color: AppTheme.secondaryText,
                size: 32,
              ),
              const SizedBox(height: 6),
              Text(
                '${s.mediaLoadFailed} · ${s.retry}',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppTheme.secondaryText,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      );
    } else if (_url == null) {
      body = _mediaPlaceholder();
    } else {
      body = GestureDetector(
        onTap: widget.onOpenViewer,
        child: Image(
          image: ResizeImage(NetworkImage(_url!), width: _decodeWidth),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          excludeFromSemantics: true,
          frameBuilder: (context, child, frame, wasSync) {
            if (wasSync) return child;
            return Stack(
              fit: StackFit.expand,
              children: [
                if (frame == null) _mediaPlaceholder(),
                AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 180),
                  child: child,
                ),
              ],
            );
          },
          errorBuilder: (context, error, stack) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _onImageError(),
            );
            return _mediaPlaceholder();
          },
        ),
      );
    }
    return AspectRatio(
      aspectRatio: _failed || _url == null ? 4 / 3 : aspect,
      child: body,
    );
  }
}

/// Fullscreen image viewer: pinch-to-zoom, mouse-wheel zoom, +/- controls.
class ChatImageViewerPage extends StatefulWidget {
  final String url;
  final String title;
  final ChatStrings strings;

  const ChatImageViewerPage({
    super.key,
    required this.url,
    required this.title,
    required this.strings,
  });

  @override
  State<ChatImageViewerPage> createState() => _ChatImageViewerPageState();
}

class _ChatImageViewerPageState extends State<ChatImageViewerPage> {
  final TransformationController _tc = TransformationController();

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  void _zoom(double factor) {
    final current = _tc.value.getMaxScaleOnAxis();
    final target = (current * factor).clamp(1.0, 6.0);
    final f = target / current;
    // ignore: deprecated_member_use
    _tc.value = _tc.value.clone()..scale(f, f, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
        ),
        leading: IconButton(
          tooltip: s.close,
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          IconButton(
            tooltip: s.zoomOut,
            icon: const Icon(Icons.zoom_out_rounded),
            onPressed: () => _zoom(1 / 1.5),
          ),
          IconButton(
            tooltip: s.zoomIn,
            icon: const Icon(Icons.zoom_in_rounded),
            onPressed: () => _zoom(1.5),
          ),
        ],
      ),
      body: InteractiveViewer(
        transformationController: _tc,
        minScale: 1,
        maxScale: 6,
        child: Center(
          child: Image.network(
            widget.url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, p) => p == null
                ? child
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
            errorBuilder: (context, e, st) => Center(
              child: Text(
                s.mediaLoadFailed,
                style: GoogleFonts.inter(color: Colors.white70),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- video

String chatFormatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  final mm = m.toString().padLeft(h > 0 ? 2 : 1, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// Video tile in the chat: first-frame poster edge-to-edge with a centered Play
/// button and the duration badge. The controller is created lazily when the
/// tile is built (the chat list is lazy), only loads metadata + the first
/// frame (never plays) and is disposed with the tile. The full player opens
/// only when the user taps. If the poster cannot be loaded, a dark poster with
/// the Play button is shown.
class ChatVideoCard extends StatefulWidget {
  final ChatMessage message;
  final ChatStrings strings;
  final ChatUrlResolver resolveUrl;
  final VoidCallback onPlay;

  const ChatVideoCard({
    super.key,
    required this.message,
    required this.strings,
    required this.resolveUrl,
    required this.onPlay,
  });

  @override
  State<ChatVideoCard> createState() => _ChatVideoCardState();
}

class _ChatVideoCardState extends State<ChatVideoCard> {
  VideoPlayerController? _c;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _initPoster();
  }

  Future<void> _initPoster() async {
    try {
      final url = await widget.resolveUrl(forceRefresh: false);
      if (url == null) throw StateError('no url');
      final c = VideoPlayerController.networkUrl(
        Uri.parse(url),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _c = c;
      await c.initialize();
      await c.setVolume(0);
      await c.seekTo(const Duration(milliseconds: 100));
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final ready = _ready && c != null && c.value.isInitialized && !_failed;
    final aspect = ready ? chatClampAspect(c.value.aspectRatio) : 16 / 9;
    return GestureDetector(
      onTap: widget.onPlay,
      child: AspectRatio(
        aspectRatio: aspect,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: const Color(0xFF14181F)),
            if (ready)
              FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: c.value.size.width,
                  height: c.value.size.height,
                  child: VideoPlayer(c),
                ),
              ),
            Center(
              child: Semantics(
                button: true,
                label: widget.strings.playVideo,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Color(0x99000000),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    size: 38,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            if (ready && c.value.duration > Duration.zero)
              PositionedDirectional(
                start: 8,
                bottom: 6,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.videocam_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      chatFormatDuration(c.value.duration),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        shadows: const [
                          Shadow(color: Color(0x99000000), blurRadius: 4),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Fullscreen player: play/pause, seek bar, duration, error + retry.
class ChatVideoPlayerPage extends StatefulWidget {
  final ChatUrlResolver resolveUrl;
  final String title;
  final ChatStrings strings;

  const ChatVideoPlayerPage({
    super.key,
    required this.resolveUrl,
    required this.title,
    required this.strings,
  });

  @override
  State<ChatVideoPlayerPage> createState() => _ChatVideoPlayerPageState();
}

class _ChatVideoPlayerPageState extends State<ChatVideoPlayerPage> {
  VideoPlayerController? _c;
  bool _failed = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init({bool force = false}) async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final url = await widget.resolveUrl(forceRefresh: force);
      if (url == null) throw StateError('no url');
      final old = _c;
      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      await c.initialize();
      c.addListener(() {
        if (mounted) setState(() {});
      });
      if (!mounted) {
        await c.dispose();
        return;
      }
      await old?.dispose();
      setState(() {
        _c = c;
        _loading = false;
      });
      await c.play();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final c = _c;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: s.close,
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : (_failed || c == null || c.value.hasError)
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.white70,
                    size: 40,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    s.mediaLoadFailed,
                    style: GoogleFonts.inter(color: Colors.white70),
                  ),
                  TextButton(
                    onPressed: () => _init(force: true),
                    child: Text(s.retry),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: c.value.aspectRatio == 0
                          ? 16 / 9
                          : c.value.aspectRatio,
                      child: VideoPlayer(c),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  child: Row(
                    children: [
                      IconButton(
                        color: Colors.white,
                        iconSize: 32,
                        icon: Icon(
                          c.value.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        onPressed: () =>
                            c.value.isPlaying ? c.pause() : c.play(),
                      ),
                      Text(
                        _fmt(c.value.position),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12.5,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          min: 0,
                          max: c.value.duration.inMilliseconds.toDouble().clamp(
                            1.0,
                            double.infinity,
                          ),
                          value: c.value.position.inMilliseconds
                              .toDouble()
                              .clamp(
                                0.0,
                                c.value.duration.inMilliseconds
                                    .toDouble()
                                    .clamp(1.0, double.infinity),
                              ),
                          onChanged: (v) =>
                              c.seekTo(Duration(milliseconds: v.round())),
                        ),
                      ),
                      Text(
                        _fmt(c.value.duration),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ------------------------------------------------------------------ pdf

Future<Uint8List> _downloadBytes(String url) async {
  final res = await Dio().get<List<int>>(
    url,
    options: Options(responseType: ResponseType.bytes),
  );
  return Uint8List.fromList(res.data ?? const <int>[]);
}

/// PDF card: first-page preview, filename, page count. Bytes are fetched once
/// per card (State) from the cached signed URL, never on rebuild.
class ChatPdfCard extends StatefulWidget {
  final ChatMessage message;
  final ChatStrings strings;
  final ChatUrlResolver resolveUrl;
  final VoidCallback onOpenViewer;
  final VoidCallback onDownload;

  const ChatPdfCard({
    super.key,
    required this.message,
    required this.strings,
    required this.resolveUrl,
    required this.onOpenViewer,
    required this.onDownload,
  });

  @override
  State<ChatPdfCard> createState() => _ChatPdfCardState();
}

class _ChatPdfCardState extends State<ChatPdfCard> {
  Uint8List? _preview;
  int? _pages;
  double? _aspect;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _render();
  }

  Future<void> _render({bool force = false}) async {
    if (mounted && _failed) setState(() => _failed = false);
    try {
      final url = await widget.resolveUrl(forceRefresh: force);
      if (url == null) throw StateError('no url');
      final bytes = await _downloadBytes(url);
      final doc = await PdfDocument.openData(bytes);
      final page = await doc.getPage(1);
      final img = await page.render(
        width: page.width * 1.5,
        height: page.height * 1.5,
        format: PdfPageImageFormat.jpeg,
        backgroundColor: '#FFFFFF',
      );
      final count = doc.pagesCount;
      final ratio = page.height > 0 ? page.width / page.height : null;
      await page.close();
      await doc.close();
      if (!mounted) return;
      setState(() {
        _preview = img?.bytes;
        _pages = count;
        _aspect = ratio;
        _failed = img == null;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    // Pages are portrait most of the time; clamp so the tile stays sensible.
    final aspect = chatClampAspect(_aspect ?? 0.75);
    Widget body;
    if (_preview != null) {
      body = GestureDetector(
        onTap: widget.onOpenViewer,
        child: Image.memory(
          _preview!,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
        ),
      );
    } else if (_failed) {
      body = InkWell(
        onTap: () => _render(force: true),
        child: _mediaPlaceholder(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.picture_as_pdf_outlined,
                size: 40,
                color: AppTheme.luxuryAccent,
              ),
              const SizedBox(height: 6),
              Text(
                '${s.mediaLoadFailed} · ${s.retry}',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppTheme.secondaryText,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      body = _mediaPlaceholder();
    }
    return AspectRatio(
      aspectRatio: aspect,
      child: Stack(
        fit: StackFit.expand,
        children: [
          body,
          // Small PDF badge so users know it is a document.
          PositionedDirectional(
            start: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFD93025),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _pages != null ? 'PDF · ${_pages!}' : 'PDF',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fullscreen PDF viewer: swipe/scroll pages, pinch zoom, page counter, and
/// an Open/Download action.
class ChatPdfViewerPage extends StatefulWidget {
  final ChatUrlResolver resolveUrl;
  final String title;
  final ChatStrings strings;
  final VoidCallback onDownload;

  const ChatPdfViewerPage({
    super.key,
    required this.resolveUrl,
    required this.title,
    required this.strings,
    required this.onDownload,
  });

  @override
  State<ChatPdfViewerPage> createState() => _ChatPdfViewerPageState();
}

class _ChatPdfViewerPageState extends State<ChatPdfViewerPage> {
  PdfControllerPinch? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open({bool force = false}) async {
    setState(() => _failed = false);
    try {
      final url = await widget.resolveUrl(forceRefresh: force);
      if (url == null) throw StateError('no url');
      final bytes = await _downloadBytes(url);
      if (!mounted) return;
      setState(() {
        _controller = PdfControllerPinch(document: PdfDocument.openData(bytes));
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final c = _controller;
    return Scaffold(
      backgroundColor: const Color(0xFF2B2F36),
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          tooltip: s.close,
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          widget.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
        ),
        actions: [
          if (c != null)
            PdfPageNumber(
              controller: c,
              builder: (context, state, page, pages) => Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '${s.pageWord} $page/${pages ?? '-'}',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
            ),
          if (c != null)
            IconButton(
              tooltip: s.pageWord,
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: () => c.previousPage(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              ),
            ),
          if (c != null)
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: () => c.nextPage(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              ),
            ),
          IconButton(
            tooltip: s.openDownload,
            icon: const Icon(Icons.download_rounded),
            onPressed: widget.onDownload,
          ),
        ],
      ),
      body: _failed
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.mediaLoadFailed,
                    style: GoogleFonts.inter(color: Colors.white70),
                  ),
                  TextButton(
                    onPressed: () => _open(force: true),
                    child: Text(s.retry),
                  ),
                ],
              ),
            )
          : c == null
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : PdfViewPinch(controller: c),
    );
  }
}

// ------------------------------------------------------------- documents

/// Polished card for DOC, DOCX, XLS, XLSX, TXT and other files. It only shows
/// metadata - the file contents are NOT rendered.
class ChatDocumentCard extends StatelessWidget {
  final ChatMessage message;
  final ChatStrings strings;
  final VoidCallback onOpen;

  const ChatDocumentCard({
    super.key,
    required this.message,
    required this.strings,
    required this.onOpen,
  });

  String _ext() {
    final n = message.fileName ?? '';
    final i = n.lastIndexOf('.');
    return i < 0 ? '' : n.substring(i + 1).toUpperCase();
  }

  IconData _icon() {
    switch (_ext()) {
      case 'DOC':
      case 'DOCX':
        return Icons.description_outlined;
      case 'XLS':
      case 'XLSX':
        return Icons.table_chart_outlined;
      case 'TXT':
        return Icons.notes_rounded;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  String _type() {
    switch (_ext()) {
      case 'DOC':
      case 'DOCX':
        return strings.docTypeWord;
      case 'XLS':
      case 'XLSX':
        return strings.docTypeExcel;
      case 'TXT':
        return strings.docTypeText;
      default:
        return strings.docTypeOther;
    }
  }

  String _size(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final size = _size(message.fileSizeBytes);
    final ext = _ext();
    final meta = [
      _type(),
      if (ext.isNotEmpty) ext,
      if (size.isNotEmpty) size,
    ].join(' · ');
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.softGoldBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon(), color: AppTheme.luxuryAccent, size: 24),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.fileName ?? strings.attachment,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppTheme.primaryText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppTheme.secondaryText,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: strings.openDownload,
            visualDensity: VisualDensity.compact,
            onPressed: onOpen,
            icon: Icon(
              Icons.download_rounded,
              color: AppTheme.navyText,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}
