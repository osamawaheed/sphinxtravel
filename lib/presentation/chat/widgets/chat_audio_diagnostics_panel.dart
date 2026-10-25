import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/chat/chat_audio_diagnostics.dart';

/// TEMPORARY audio diagnostics panel. Rendered only when diagnostics are
/// enabled (TEST booking, non-release build). Shows runtime values on screen
/// and offers a "Copy Diagnostics" button.
class ChatAudioDiagnosticsPanel extends StatefulWidget {
  const ChatAudioDiagnosticsPanel({super.key});

  @override
  State<ChatAudioDiagnosticsPanel> createState() =>
      _ChatAudioDiagnosticsPanelState();
}

class _ChatAudioDiagnosticsPanelState extends State<ChatAudioDiagnosticsPanel> {
  bool _expanded = true;
  bool _copied = false;

  ChatAudioDiagnostics get _d => ChatAudioDiagnostics.instance;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _d.buildReport()));
    if (!mounted) return;
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: _d,
      builder: (context, _) {
        if (!_d.enabled) return const SizedBox.shrink();
        final mono = GoogleFonts.robotoMono(
          fontSize: 10.5,
          color: Colors.greenAccent.shade100,
          height: 1.25,
        );
        final head = GoogleFonts.inter(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        );

        Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$k ',
                  style: mono.copyWith(
                    color: Colors.amber.shade200,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(text: v, style: mono),
              ],
            ),
          ),
        );

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
          decoration: BoxDecoration(
            color: const Color(0xEE111111),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade400),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
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
                        child: Text(
                          'AUDIO DIAGNOSTICS (TEST ONLY)',
                          style: head,
                        ),
                      ),
                      Icon(
                        _expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              if (_expanded)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.34,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        row('1 Browser/OS:', _d.environment),
                        row('2 MediaRecorder:', ''),
                        for (final e in _d.recordingSupport.entries)
                          row('   ${e.key}', e.value ? 'YES' : 'NO'),
                        row('3 Recording MIME:', _d.recordingMime),
                        row('  Encoder:', _d.recordingEncoder),
                        row('4 Extension:', _d.recordingExtension),
                        row('5 HTTP status:', _d.httpStatus),
                        row('6 Content-Type:', _d.contentType),
                        row('  Probe:', _d.probeNote),
                        row('7 Player init:', _d.playerInit),
                        row('8 Duration:', _d.duration),
                        row('9 Position:', _d.position),
                        row(
                          '10 State:',
                          '${_d.processingState} playing=${_d.playing}',
                        ),
                        row('11 Error:', _d.lastError),
                        row('12 Started:', _d.playbackStarted),
                        row('  Message:', _d.lastMessageId),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: SizedBox(
                  width: double.infinity,
                  height: 34,
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
