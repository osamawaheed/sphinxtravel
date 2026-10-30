import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/chat/chat_audio_diagnostics.dart';

/// TEMPORARY "Audio Diagnostics" button shown at the top of Smart Chat
/// (TEST environment only). Toggles the diagnostics panel.
class ChatAudioDiagnosticsButton extends StatelessWidget {
  const ChatAudioDiagnosticsButton({super.key});

  @override
  Widget build(BuildContext context) {
    final d = ChatAudioDiagnostics.instance;
    return ListenableBuilder(
      listenable: d,
      builder: (context, _) {
        if (!d.enabled) return const SizedBox.shrink();
        final open = d.panelOpen;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
          child: SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton.icon(
              onPressed: () => d.setPanelOpen(!open),
              icon: Icon(
                open ? Icons.close_rounded : Icons.bug_report_rounded,
                size: 18,
              ),
              label: Text(
                open ? 'Hide Audio Diagnostics' : 'Audio Diagnostics',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade400,
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 0,
                ),
                minimumSize: const Size(0, 40),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                alignment: Alignment.center,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// TEMPORARY audio diagnostics panel. Rendered only when diagnostics are
/// enabled (TEST build flag) and opened from the "Audio Diagnostics" button.
/// Shows runtime values on screen, a "Copy Diagnostics" button and a
/// selectable report as a fallback when the clipboard is unavailable.
class ChatAudioDiagnosticsPanel extends StatefulWidget {
  const ChatAudioDiagnosticsPanel({super.key});

  @override
  State<ChatAudioDiagnosticsPanel> createState() =>
      _ChatAudioDiagnosticsPanelState();
}

class _ChatAudioDiagnosticsPanelState extends State<ChatAudioDiagnosticsPanel> {
  bool _copied = false;
  bool _copyFailed = false;

  ChatAudioDiagnostics get _d => ChatAudioDiagnostics.instance;

  Future<void> _copy() async {
    var ok = true;
    try {
      await Clipboard.setData(ClipboardData(text: _d.buildReport()));
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _copied = ok;
      _copyFailed = !ok;
    });
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _copied = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _d,
      builder: (context, _) {
        if (!_d.panelOpen) return const SizedBox.shrink();
        final mono = GoogleFonts.robotoMono(
          fontSize: 10.5,
          color: Colors.greenAccent.shade100,
          height: 1.3,
        );
        final head = GoogleFonts.inter(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        );

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          decoration: BoxDecoration(
            color: const Color(0xF2111111),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade400),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.bug_report_rounded,
                      size: 16,
                      color: Colors.amber.shade300,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('AUDIO DIAGNOSTICS (TEST ONLY)', style: head),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.34,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: SelectableText(_d.buildReport(), style: mono),
                  ),
                ),
              ),
              if (_copyFailed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                  child: Text(
                    'Copy blocked by the browser. Long-press the report above, '
                    'choose Select All, then Copy.',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.orange.shade200,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: ElevatedButton.icon(
                    onPressed: _copy,
                    icon: Icon(
                      _copied ? Icons.check_rounded : Icons.copy_rounded,
                      size: 16,
                    ),
                    label: Text(
                      _copied ? 'Copied' : 'Copy Diagnostics',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade400,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
