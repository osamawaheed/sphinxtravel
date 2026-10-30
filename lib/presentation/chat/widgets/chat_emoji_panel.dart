import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';
import '../chat_strings.dart';

class _EmojiCategory {
  final IconData icon;
  final String Function(ChatStrings) label;
  final List<String> emojis;
  const _EmojiCategory(this.icon, this.label, this.emojis);
}

/// Keyword index for emoji search (English + Arabic). Emojis without an
/// entry are still reachable by browsing categories.
const Map<String, String> _emojiKeywords = {
  '😀': 'smile grin happy face ابتسامة سعيد',
  '😃': 'smile happy joy سعيد',
  '😄': 'smile laugh happy ضحك',
  '😁': 'grin beam ابتسامة',
  '😂': 'laugh tears joy lol ضحك',
  '🤣': 'rofl laugh floor ضحك',
  '😊': 'blush smile happy سعيد',
  '😇': 'angel halo innocent ملاك',
  '🙂': 'smile slight ابتسامة',
  '😉': 'wink غمزة',
  '😍': 'love heart eyes حب',
  '🥰': 'love hearts adore حب',
  '😘': 'kiss love قبلة',
  '😎': 'cool sunglasses رائع',
  '🤩': 'star struck wow',
  '🤔': 'think thinking hmm تفكير',
  '😐': 'neutral face',
  '😴': 'sleep tired نوم',
  '😢': 'sad cry tear حزين بكاء',
  '😭': 'cry sob sad بكاء',
  '😡': 'angry mad غاضب',
  '😱': 'scream shock fear صدمة',
  '😅': 'sweat smile nervous',
  '🙄': 'eye roll',
  '😬': 'grimace awkward',
  '🥳': 'party celebrate حفلة',
  '🤗': 'hug thanks عناق',
  '😷': 'mask sick مريض',
  '🤒': 'sick fever مريض',
  '👍': 'thumbs up like ok good yes جيد موافق',
  '👎': 'thumbs down dislike no سيء',
  '👌': 'ok okay perfect تمام',
  '✌️': 'peace victory',
  '🤞': 'fingers crossed luck حظ',
  '👋': 'wave hello hi bye مرحبا',
  '🙏': 'pray thanks please شكرا من فضلك',
  '👏': 'clap applause تصفيق',
  '🙌': 'celebrate hands raise',
  '💪': 'strong muscle قوة',
  '🤝': 'handshake deal agree اتفاق',
  '👀': 'eyes look see عيون',
  '🧳': 'luggage suitcase bag travel حقيبة سفر',
  '🌱': 'plant seedling',
  '🌳': 'tree',
  '🌴': 'palm tree beach نخلة',
  '🌹': 'rose flower وردة',
  '🌸': 'blossom flower زهرة',
  '🌞': 'sun sunny شمس',
  '☀️': 'sun sunny hot شمس',
  '🌙': 'moon night قمر',
  '⭐': 'star نجمة',
  '🌧️': 'rain weather مطر',
  '❄️': 'snow cold ثلج',
  '🔥': 'fire hot نار',
  '🌊': 'wave sea ocean بحر',
  '🐶': 'dog puppy كلب',
  '🐱': 'cat kitten قطة',
  '🐴': 'horse حصان',
  '🐪': 'camel جمل',
  '🍎': 'apple fruit تفاحة',
  '🍌': 'banana fruit موز',
  '🍇': 'grapes fruit عنب',
  '🍕': 'pizza food',
  '🍔': 'burger hamburger food',
  '🍟': 'fries food',
  '🥗': 'salad food سلطة',
  '🍰': 'cake dessert كعكة',
  '☕': 'coffee tea hot قهوة',
  '🍵': 'tea شاي',
  '💧': 'water drop ماء',
  '🍷': 'wine drink',
  '🍺': 'beer drink',
  '🚗': 'car auto drive سيارة',
  '🚕': 'taxi cab سيارة أجرة',
  '🚙': 'suv car',
  '🚌': 'bus حافلة',
  '✈️': 'plane flight airplane airport طائرة مطار',
  '🛫': 'takeoff departure plane',
  '🛬': 'landing arrival plane',
  '🏨': 'hotel فندق',
  '🏠': 'house home بيت',
  '🏖️': 'beach holiday شاطئ',
  '⛰️': 'mountain جبل',
  '🗺️': 'map خريطة',
  '📍': 'pin location place موقع',
  '⏰': 'alarm clock time وقت',
  '🕐': 'clock time one',
  '📱': 'phone mobile هاتف',
  '📞': 'phone call هاتف',
  '📷': 'camera photo صورة',
  '📄': 'document page file مستند',
  '❤️': 'heart love red قلب حب',
  '💛': 'yellow heart',
  '💙': 'blue heart',
  '💚': 'green heart',
  '💔': 'broken heart',
  '✅': 'check done yes ok تم',
  '❌': 'cross no wrong x خطأ',
  '⚠️': 'warning caution تحذير',
  '❓': 'question سؤال',
  '❗': 'exclamation important مهم',
  '💯': 'hundred perfect',
  '🎉': 'party tada celebrate congratulations مبروك',
  '🎁': 'gift present هدية',
};

const List<_EmojiCategory> _categories = [
  _EmojiCategory(Icons.emoji_emotions_outlined, _lblSmileys, [
    '😀',
    '😃',
    '😄',
    '😁',
    '😂',
    '🤣',
    '😊',
    '😇',
    '🙂',
    '😉',
    '😍',
    '🥰',
    '😘',
    '😎',
    '🤩',
    '🤔',
    '😐',
    '😴',
    '😢',
    '😭',
    '😡',
    '😱',
    '😅',
    '🙄',
    '😬',
    '🥳',
    '🤗',
    '😷',
    '🤒',
    '😋',
    '😌',
    '😏',
    '😒',
    '😔',
    '😞',
    '😤',
  ]),
  _EmojiCategory(Icons.waving_hand_outlined, _lblGestures, [
    '👍',
    '👎',
    '👌',
    '✌️',
    '🤞',
    '👋',
    '🙏',
    '👏',
    '🙌',
    '💪',
    '🤝',
    '👀',
    '🤙',
    '👊',
    '✋',
    '🤚',
    '🖐️',
    '☝️',
    '👆',
    '👇',
    '👈',
    '👉',
    '🫶',
    '🧑',
  ]),
  _EmojiCategory(Icons.eco_outlined, _lblNature, [
    '🌱',
    '🌳',
    '🌴',
    '🌹',
    '🌸',
    '🌞',
    '☀️',
    '🌙',
    '⭐',
    '🌧️',
    '❄️',
    '🔥',
    '🌊',
    '🐶',
    '🐱',
    '🐴',
    '🐪',
    '🦅',
    '🐬',
    '🌈',
    '⛅',
    '🍀',
    '🌻',
    '🌵',
  ]),
  _EmojiCategory(Icons.restaurant_outlined, _lblFood, [
    '🍎',
    '🍌',
    '🍇',
    '🍕',
    '🍔',
    '🍟',
    '🥗',
    '🍰',
    '☕',
    '🍵',
    '💧',
    '🍷',
    '🍺',
    '🍉',
    '🍓',
    '🥐',
    '🍞',
    '🧀',
    '🍗',
    '🍝',
    '🍣',
    '🍫',
    '🍪',
    '🥤',
  ]),
  _EmojiCategory(Icons.directions_car_outlined, _lblTravel, [
    '🚗',
    '🚕',
    '🚙',
    '🚌',
    '✈️',
    '🛫',
    '🛬',
    '🏨',
    '🏠',
    '🏖️',
    '⛰️',
    '🗺️',
    '📍',
    '⏰',
    '🧳',
    '📱',
    '📞',
    '📷',
    '📄',
    '🚦',
    '⛽',
    '🅿️',
    '🚏',
    '🛂',
  ]),
  _EmojiCategory(Icons.favorite_border_rounded, _lblSymbols, [
    '❤️',
    '💛',
    '💙',
    '💚',
    '💔',
    '✅',
    '❌',
    '⚠️',
    '❓',
    '❗',
    '💯',
    '🎉',
    '🎁',
    '✨',
    '💬',
    '🔔',
    '🔒',
    '➕',
    '➖',
    '➡️',
    '⬅️',
    '⬆️',
    '⬇️',
    '🆗',
  ]),
];

String _lblSmileys(ChatStrings s) => s.emojiSmileys;
String _lblGestures(ChatStrings s) => s.emojiGestures;
String _lblNature(ChatStrings s) => s.emojiNature;
String _lblFood(ChatStrings s) => s.emojiFood;
String _lblTravel(ChatStrings s) => s.emojiTravel;
String _lblSymbols(ChatStrings s) => s.emojiSymbols;

/// Compact emoji panel shown under the composer. Selecting an emoji calls
/// [onSelected]; the panel stays open so several emojis can be inserted.
class ChatEmojiPanel extends StatefulWidget {
  final ChatStrings strings;
  final ValueChanged<String> onSelected;
  final VoidCallback onClose;

  const ChatEmojiPanel({
    super.key,
    required this.strings,
    required this.onSelected,
    required this.onClose,
  });

  @override
  State<ChatEmojiPanel> createState() => _ChatEmojiPanelState();
}

class _ChatEmojiPanelState extends State<ChatEmojiPanel> {
  final TextEditingController _search = TextEditingController();
  int _tab = 0;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<String> get _visible {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _categories[_tab].emojis;
    final out = <String>[];
    final seen = <String>{};
    for (final c in _categories) {
      for (final e in c.emojis) {
        final kw = _emojiKeywords[e] ?? '';
        if (kw.toLowerCase().contains(q) && seen.add(e)) out.add(e);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final items = _visible;
    final searching = _query.trim().isNotEmpty;
    return Container(
      height: 290,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 4),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.softGoldBg,
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: AppTheme.secondaryText,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _search,
                            onChanged: (v) => setState(() => _query = v),
                            style: GoogleFonts.inter(
                              color: AppTheme.primaryText,
                              fontSize: 14,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              isCollapsed: true,
                              hintText: s.emojiSearchHint,
                              hintStyle: GoogleFonts.inter(
                                color: AppTheme.secondaryText,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: s.close,
                  onPressed: widget.onClose,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          if (!searching)
            SizedBox(
              height: 40,
              child: Row(
                children: [
                  for (var i = 0; i < _categories.length; i++)
                    Expanded(
                      child: Tooltip(
                        message: _categories[i].label(s),
                        child: InkWell(
                          onTap: () => setState(() => _tab = i),
                          child: Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  width: 2,
                                  color: i == _tab
                                      ? AppTheme.luxuryAccent
                                      : Colors.transparent,
                                ),
                              ),
                            ),
                            child: Icon(
                              _categories[i].icon,
                              size: 21,
                              color: i == _tab
                                  ? AppTheme.luxuryAccent
                                  : AppTheme.secondaryText,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Text(
                      s.emojiNoResults,
                      style: GoogleFonts.inter(
                        color: AppTheme.secondaryText,
                        fontSize: 14,
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(8),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 46,
                          mainAxisSpacing: 2,
                          crossAxisSpacing: 2,
                        ),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final e = items[i];
                      return Listener(
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: (_) => widget.onSelected(e),
                        child: Center(
                          child: Text(
                            e,
                            style: GoogleFonts.notoColorEmoji(fontSize: 26),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
