import 'package:flutter/material.dart';

import '../services/api_client.dart';

/// Loads an image from a backend-relative `photo_url`: prefixes the API base
/// URL and sends the Authorization header. Shows [fallback] when the URL is
/// empty or the image fails to load.
class AuthNetworkImage extends StatefulWidget {
  final String? photoUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final Widget fallback;

  const AuthNetworkImage({
    super.key,
    required this.photoUrl,
    required this.width,
    required this.height,
    required this.fallback,
    this.fit = BoxFit.cover,
  });

  @override
  State<AuthNetworkImage> createState() => _AuthNetworkImageState();
}

class _AuthNetworkImageState extends State<AuthNetworkImage> {
  Map<String, String>? _headers;

  @override
  void initState() {
    super.initState();
    _loadHeaders();
  }

  Future<void> _loadHeaders() async {
    final headers = await ApiClient.authHeaders();
    if (mounted) setState(() => _headers = headers);
  }

  @override
  Widget build(BuildContext context) {
    final url = ApiClient.resolveUrl(widget.photoUrl);
    if (url.isEmpty) return widget.fallback;
    if (_headers == null) return widget.fallback;
    return Image.network(
      url,
      headers: _headers,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: (_, __, ___) => widget.fallback,
    );
  }
}
