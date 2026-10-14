import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../data/mock_api_data_source.dart';
import '../../services/api_client.dart';
import '../../services/customer_auth_service.dart';
import '../../l10n/app_localizations.dart';

// Country code data
class CountryCode {
  final String name;
  final String code;
  final String dialCode;
  final String flag;

  const CountryCode({
    required this.name,
    required this.code,
    required this.dialCode,
    required this.flag,
  });
}

const List<CountryCode> _countryCodes = [
  CountryCode(name: 'Afghanistan', code: 'AF', dialCode: '+93', flag: '🇦🇫'),
  CountryCode(name: 'Albania', code: 'AL', dialCode: '+355', flag: '🇦🇱'),
  CountryCode(name: 'Algeria', code: 'DZ', dialCode: '+213', flag: '🇩🇿'),
  CountryCode(name: 'Andorra', code: 'AD', dialCode: '+376', flag: '🇦🇩'),
  CountryCode(name: 'Angola', code: 'AO', dialCode: '+244', flag: '🇦🇴'),
  CountryCode(
    name: 'Antigua and Barbuda',
    code: 'AG',
    dialCode: '+1268',
    flag: '🇦🇬',
  ),
  CountryCode(name: 'Argentina', code: 'AR', dialCode: '+54', flag: '🇦🇷'),
  CountryCode(name: 'Armenia', code: 'AM', dialCode: '+374', flag: '🇦🇲'),
  CountryCode(name: 'Australia', code: 'AU', dialCode: '+61', flag: '🇦🇺'),
  CountryCode(name: 'Austria', code: 'AT', dialCode: '+43', flag: '🇦🇹'),
  CountryCode(name: 'Azerbaijan', code: 'AZ', dialCode: '+994', flag: '🇦🇿'),
  CountryCode(name: 'Bahamas', code: 'BS', dialCode: '+1242', flag: '🇧🇸'),
  CountryCode(name: 'Bahrain', code: 'BH', dialCode: '+973', flag: '🇧🇭'),
  CountryCode(name: 'Bangladesh', code: 'BD', dialCode: '+880', flag: '🇧🇩'),
  CountryCode(name: 'Barbados', code: 'BB', dialCode: '+1246', flag: '🇧🇧'),
  CountryCode(name: 'Belarus', code: 'BY', dialCode: '+375', flag: '🇧🇾'),
  CountryCode(name: 'Belgium', code: 'BE', dialCode: '+32', flag: '🇧🇪'),
  CountryCode(name: 'Belize', code: 'BZ', dialCode: '+501', flag: '🇧🇿'),
  CountryCode(name: 'Benin', code: 'BJ', dialCode: '+229', flag: '🇧🇯'),
  CountryCode(name: 'Bhutan', code: 'BT', dialCode: '+975', flag: '🇧🇹'),
  CountryCode(name: 'Bolivia', code: 'BO', dialCode: '+591', flag: '🇧🇴'),
  CountryCode(
    name: 'Bosnia and Herzegovina',
    code: 'BA',
    dialCode: '+387',
    flag: '🇧🇦',
  ),
  CountryCode(name: 'Botswana', code: 'BW', dialCode: '+267', flag: '🇧🇼'),
  CountryCode(name: 'Brazil', code: 'BR', dialCode: '+55', flag: '🇧🇷'),
  CountryCode(name: 'Brunei', code: 'BN', dialCode: '+673', flag: '🇧🇳'),
  CountryCode(name: 'Bulgaria', code: 'BG', dialCode: '+359', flag: '🇧🇬'),
  CountryCode(name: 'Burkina Faso', code: 'BF', dialCode: '+226', flag: '🇧🇫'),
  CountryCode(name: 'Burundi', code: 'BI', dialCode: '+257', flag: '🇧🇮'),
  CountryCode(name: 'Cabo Verde', code: 'CV', dialCode: '+238', flag: '🇨🇻'),
  CountryCode(name: 'Cambodia', code: 'KH', dialCode: '+855', flag: '🇰🇭'),
  CountryCode(name: 'Cameroon', code: 'CM', dialCode: '+237', flag: '🇨🇲'),
  CountryCode(name: 'Canada', code: 'CA', dialCode: '+1', flag: '🇨🇦'),
  CountryCode(
    name: 'Central African Republic',
    code: 'CF',
    dialCode: '+236',
    flag: '🇨🇫',
  ),
  CountryCode(name: 'Chad', code: 'TD', dialCode: '+235', flag: '🇹🇩'),
  CountryCode(name: 'Chile', code: 'CL', dialCode: '+56', flag: '🇨🇱'),
  CountryCode(name: 'China', code: 'CN', dialCode: '+86', flag: '🇨🇳'),
  CountryCode(name: 'Colombia', code: 'CO', dialCode: '+57', flag: '🇨🇴'),
  CountryCode(name: 'Comoros', code: 'KM', dialCode: '+269', flag: '🇰🇲'),
  CountryCode(
    name: 'Congo (Brazzaville)',
    code: 'CG',
    dialCode: '+242',
    flag: '🇨🇬',
  ),
  CountryCode(
    name: 'Congo (Kinshasa)',
    code: 'CD',
    dialCode: '+243',
    flag: '🇨🇩',
  ),
  CountryCode(name: 'Costa Rica', code: 'CR', dialCode: '+506', flag: '🇨🇷'),
  CountryCode(name: 'Croatia', code: 'HR', dialCode: '+385', flag: '🇭🇷'),
  CountryCode(name: 'Cuba', code: 'CU', dialCode: '+53', flag: '🇨🇺'),
  CountryCode(name: 'Cyprus', code: 'CY', dialCode: '+357', flag: '🇨🇾'),
  CountryCode(
    name: 'Czech Republic',
    code: 'CZ',
    dialCode: '+420',
    flag: '🇨🇿',
  ),
  CountryCode(name: 'Denmark', code: 'DK', dialCode: '+45', flag: '🇩🇰'),
  CountryCode(name: 'Djibouti', code: 'DJ', dialCode: '+253', flag: '🇩🇯'),
  CountryCode(name: 'Dominica', code: 'DM', dialCode: '+1767', flag: '🇩🇲'),
  CountryCode(
    name: 'Dominican Republic',
    code: 'DO',
    dialCode: '+1849',
    flag: '🇩🇴',
  ),
  CountryCode(name: 'Ecuador', code: 'EC', dialCode: '+593', flag: '🇪🇨'),
  CountryCode(name: 'Egypt', code: 'EG', dialCode: '+20', flag: '🇪🇬'),
  CountryCode(name: 'El Salvador', code: 'SV', dialCode: '+503', flag: '🇸🇻'),
  CountryCode(
    name: 'Equatorial Guinea',
    code: 'GQ',
    dialCode: '+240',
    flag: '🇬🇶',
  ),
  CountryCode(name: 'Eritrea', code: 'ER', dialCode: '+291', flag: '🇪🇷'),
  CountryCode(name: 'Estonia', code: 'EE', dialCode: '+372', flag: '🇪🇪'),
  CountryCode(name: 'Eswatini', code: 'SZ', dialCode: '+268', flag: '🇸🇿'),
  CountryCode(name: 'Ethiopia', code: 'ET', dialCode: '+251', flag: '🇪🇹'),
  CountryCode(name: 'Fiji', code: 'FJ', dialCode: '+679', flag: '🇫🇯'),
  CountryCode(name: 'Finland', code: 'FI', dialCode: '+358', flag: '🇫🇮'),
  CountryCode(name: 'France', code: 'FR', dialCode: '+33', flag: '🇫🇷'),
  CountryCode(name: 'Gabon', code: 'GA', dialCode: '+241', flag: '🇬🇦'),
  CountryCode(name: 'Gambia', code: 'GM', dialCode: '+220', flag: '🇬🇲'),
  CountryCode(name: 'Georgia', code: 'GE', dialCode: '+995', flag: '🇬🇪'),
  CountryCode(name: 'Germany', code: 'DE', dialCode: '+49', flag: '🇩🇪'),
  CountryCode(name: 'Ghana', code: 'GH', dialCode: '+233', flag: '🇬🇭'),
  CountryCode(name: 'Greece', code: 'GR', dialCode: '+30', flag: '🇬🇷'),
  CountryCode(name: 'Grenada', code: 'GD', dialCode: '+1473', flag: '🇬🇩'),
  CountryCode(name: 'Guatemala', code: 'GT', dialCode: '+502', flag: '🇬🇹'),
  CountryCode(name: 'Guinea', code: 'GN', dialCode: '+224', flag: '🇬🇳'),
  CountryCode(
    name: 'Guinea-Bissau',
    code: 'GW',
    dialCode: '+245',
    flag: '🇬🇼',
  ),
  CountryCode(name: 'Guyana', code: 'GY', dialCode: '+592', flag: '🇬🇾'),
  CountryCode(name: 'Haiti', code: 'HT', dialCode: '+509', flag: '🇭🇹'),
  CountryCode(name: 'Honduras', code: 'HN', dialCode: '+504', flag: '🇭🇳'),
  CountryCode(name: 'Hungary', code: 'HU', dialCode: '+36', flag: '🇭🇺'),
  CountryCode(name: 'Iceland', code: 'IS', dialCode: '+354', flag: '🇮🇸'),
  CountryCode(name: 'India', code: 'IN', dialCode: '+91', flag: '🇮🇳'),
  CountryCode(name: 'Indonesia', code: 'ID', dialCode: '+62', flag: '🇮🇩'),
  CountryCode(name: 'Iran', code: 'IR', dialCode: '+98', flag: '🇮🇷'),
  CountryCode(name: 'Iraq', code: 'IQ', dialCode: '+964', flag: '🇮🇶'),
  CountryCode(name: 'Ireland', code: 'IE', dialCode: '+353', flag: '🇮🇪'),
  CountryCode(name: 'Israel', code: 'IL', dialCode: '+972', flag: '🇮🇱'),
  CountryCode(name: 'Italy', code: 'IT', dialCode: '+39', flag: '🇮🇹'),
  CountryCode(name: 'Ivory Coast', code: 'CI', dialCode: '+225', flag: '🇨🇮'),
  CountryCode(name: 'Jamaica', code: 'JM', dialCode: '+1876', flag: '🇯🇲'),
  CountryCode(name: 'Japan', code: 'JP', dialCode: '+81', flag: '🇯🇵'),
  CountryCode(name: 'Jordan', code: 'JO', dialCode: '+962', flag: '🇯🇴'),
  CountryCode(name: 'Kazakhstan', code: 'KZ', dialCode: '+7', flag: '🇰🇿'),
  CountryCode(name: 'Kenya', code: 'KE', dialCode: '+254', flag: '🇰🇪'),
  CountryCode(name: 'Kiribati', code: 'KI', dialCode: '+686', flag: '🇰🇮'),
  CountryCode(name: 'Kosovo', code: 'XK', dialCode: '+383', flag: '🇽🇰'),
  CountryCode(name: 'Kuwait', code: 'KW', dialCode: '+965', flag: '🇰🇼'),
  CountryCode(name: 'Kyrgyzstan', code: 'KG', dialCode: '+996', flag: '🇰🇬'),
  CountryCode(name: 'Laos', code: 'LA', dialCode: '+856', flag: '🇱🇦'),
  CountryCode(name: 'Latvia', code: 'LV', dialCode: '+371', flag: '🇱🇻'),
  CountryCode(name: 'Lebanon', code: 'LB', dialCode: '+961', flag: '🇱🇧'),
  CountryCode(name: 'Lesotho', code: 'LS', dialCode: '+266', flag: '🇱🇸'),
  CountryCode(name: 'Liberia', code: 'LR', dialCode: '+231', flag: '🇱🇷'),
  CountryCode(name: 'Libya', code: 'LY', dialCode: '+218', flag: '🇱🇾'),
  CountryCode(
    name: 'Liechtenstein',
    code: 'LI',
    dialCode: '+423',
    flag: '🇱🇮',
  ),
  CountryCode(name: 'Lithuania', code: 'LT', dialCode: '+370', flag: '🇱🇹'),
  CountryCode(name: 'Luxembourg', code: 'LU', dialCode: '+352', flag: '🇱🇺'),
  CountryCode(name: 'Madagascar', code: 'MG', dialCode: '+261', flag: '🇲🇬'),
  CountryCode(name: 'Malawi', code: 'MW', dialCode: '+265', flag: '🇲🇼'),
  CountryCode(name: 'Malaysia', code: 'MY', dialCode: '+60', flag: '🇲🇾'),
  CountryCode(name: 'Maldives', code: 'MV', dialCode: '+960', flag: '🇲🇻'),
  CountryCode(name: 'Mali', code: 'ML', dialCode: '+223', flag: '🇲🇱'),
  CountryCode(name: 'Malta', code: 'MT', dialCode: '+356', flag: '🇲🇹'),
  CountryCode(
    name: 'Marshall Islands',
    code: 'MH',
    dialCode: '+692',
    flag: '🇲🇭',
  ),
  CountryCode(name: 'Mauritania', code: 'MR', dialCode: '+222', flag: '🇲🇷'),
  CountryCode(name: 'Mauritius', code: 'MU', dialCode: '+230', flag: '🇲🇺'),
  CountryCode(name: 'Mexico', code: 'MX', dialCode: '+52', flag: '🇲🇽'),
  CountryCode(name: 'Micronesia', code: 'FM', dialCode: '+691', flag: '🇫🇲'),
  CountryCode(name: 'Moldova', code: 'MD', dialCode: '+373', flag: '🇲🇩'),
  CountryCode(name: 'Monaco', code: 'MC', dialCode: '+377', flag: '🇲🇨'),
  CountryCode(name: 'Mongolia', code: 'MN', dialCode: '+976', flag: '🇲🇳'),
  CountryCode(name: 'Montenegro', code: 'ME', dialCode: '+382', flag: '🇲🇪'),
  CountryCode(name: 'Morocco', code: 'MA', dialCode: '+212', flag: '🇲🇦'),
  CountryCode(name: 'Mozambique', code: 'MZ', dialCode: '+258', flag: '🇲🇿'),
  CountryCode(name: 'Myanmar', code: 'MM', dialCode: '+95', flag: '🇲🇲'),
  CountryCode(name: 'Namibia', code: 'NA', dialCode: '+264', flag: '🇳🇦'),
  CountryCode(name: 'Nauru', code: 'NR', dialCode: '+674', flag: '🇳🇷'),
  CountryCode(name: 'Nepal', code: 'NP', dialCode: '+977', flag: '🇳🇵'),
  CountryCode(name: 'Netherlands', code: 'NL', dialCode: '+31', flag: '🇳🇱'),
  CountryCode(name: 'New Zealand', code: 'NZ', dialCode: '+64', flag: '🇳🇿'),
  CountryCode(name: 'Nicaragua', code: 'NI', dialCode: '+505', flag: '🇳🇮'),
  CountryCode(name: 'Niger', code: 'NE', dialCode: '+227', flag: '🇳🇪'),
  CountryCode(name: 'Nigeria', code: 'NG', dialCode: '+234', flag: '🇳🇬'),
  CountryCode(name: 'North Korea', code: 'KP', dialCode: '+850', flag: '🇰🇵'),
  CountryCode(
    name: 'North Macedonia',
    code: 'MK',
    dialCode: '+389',
    flag: '🇲🇰',
  ),
  CountryCode(name: 'Norway', code: 'NO', dialCode: '+47', flag: '🇳🇴'),
  CountryCode(name: 'Oman', code: 'OM', dialCode: '+968', flag: '🇴🇲'),
  CountryCode(name: 'Pakistan', code: 'PK', dialCode: '+92', flag: '🇵🇰'),
  CountryCode(name: 'Palau', code: 'PW', dialCode: '+680', flag: '🇵🇼'),
  CountryCode(name: 'Palestine', code: 'PS', dialCode: '+970', flag: '🇵🇸'),
  CountryCode(name: 'Panama', code: 'PA', dialCode: '+507', flag: '🇵🇦'),
  CountryCode(
    name: 'Papua New Guinea',
    code: 'PG',
    dialCode: '+675',
    flag: '🇵🇬',
  ),
  CountryCode(name: 'Paraguay', code: 'PY', dialCode: '+595', flag: '🇵🇾'),
  CountryCode(name: 'Peru', code: 'PE', dialCode: '+51', flag: '🇵🇪'),
  CountryCode(name: 'Philippines', code: 'PH', dialCode: '+63', flag: '🇵🇭'),
  CountryCode(name: 'Poland', code: 'PL', dialCode: '+48', flag: '🇵🇱'),
  CountryCode(name: 'Portugal', code: 'PT', dialCode: '+351', flag: '🇵🇹'),
  CountryCode(name: 'Qatar', code: 'QA', dialCode: '+974', flag: '🇶🇦'),
  CountryCode(name: 'Romania', code: 'RO', dialCode: '+40', flag: '🇷🇴'),
  CountryCode(name: 'Russia', code: 'RU', dialCode: '+7', flag: '🇷🇺'),
  CountryCode(name: 'Rwanda', code: 'RW', dialCode: '+250', flag: '🇷🇼'),
  CountryCode(
    name: 'Saint Kitts and Nevis',
    code: 'KN',
    dialCode: '+1869',
    flag: '🇰🇳',
  ),
  CountryCode(name: 'Saint Lucia', code: 'LC', dialCode: '+1758', flag: '🇱🇨'),
  CountryCode(
    name: 'Saint Vincent and the Grenadines',
    code: 'VC',
    dialCode: '+1784',
    flag: '🇻🇨',
  ),
  CountryCode(name: 'Samoa', code: 'WS', dialCode: '+685', flag: '🇼🇸'),
  CountryCode(name: 'San Marino', code: 'SM', dialCode: '+378', flag: '🇸🇲'),
  CountryCode(
    name: 'Sao Tome and Principe',
    code: 'ST',
    dialCode: '+239',
    flag: '🇸🇹',
  ),
  CountryCode(name: 'Saudi Arabia', code: 'SA', dialCode: '+966', flag: '🇸🇦'),
  CountryCode(name: 'Senegal', code: 'SN', dialCode: '+221', flag: '🇸🇳'),
  CountryCode(name: 'Serbia', code: 'RS', dialCode: '+381', flag: '🇷🇸'),
  CountryCode(name: 'Seychelles', code: 'SC', dialCode: '+248', flag: '🇸🇨'),
  CountryCode(name: 'Sierra Leone', code: 'SL', dialCode: '+232', flag: '🇸🇱'),
  CountryCode(name: 'Singapore', code: 'SG', dialCode: '+65', flag: '🇸🇬'),
  CountryCode(name: 'Slovakia', code: 'SK', dialCode: '+421', flag: '🇸🇰'),
  CountryCode(name: 'Slovenia', code: 'SI', dialCode: '+386', flag: '🇸🇮'),
  CountryCode(
    name: 'Solomon Islands',
    code: 'SB',
    dialCode: '+677',
    flag: '🇸🇧',
  ),
  CountryCode(name: 'Somalia', code: 'SO', dialCode: '+252', flag: '🇸🇴'),
  CountryCode(name: 'South Africa', code: 'ZA', dialCode: '+27', flag: '🇿🇦'),
  CountryCode(name: 'South Korea', code: 'KR', dialCode: '+82', flag: '🇰🇷'),
  CountryCode(name: 'South Sudan', code: 'SS', dialCode: '+211', flag: '🇸🇸'),
  CountryCode(name: 'Spain', code: 'ES', dialCode: '+34', flag: '🇪🇸'),
  CountryCode(name: 'Sri Lanka', code: 'LK', dialCode: '+94', flag: '🇱🇰'),
  CountryCode(name: 'Sudan', code: 'SD', dialCode: '+249', flag: '🇸🇩'),
  CountryCode(name: 'Suriname', code: 'SR', dialCode: '+597', flag: '🇸🇷'),
  CountryCode(name: 'Sweden', code: 'SE', dialCode: '+46', flag: '🇸🇪'),
  CountryCode(name: 'Switzerland', code: 'CH', dialCode: '+41', flag: '🇨🇭'),
  CountryCode(name: 'Syria', code: 'SY', dialCode: '+963', flag: '🇸🇾'),
  CountryCode(name: 'Taiwan', code: 'TW', dialCode: '+886', flag: '🇹🇼'),
  CountryCode(name: 'Tajikistan', code: 'TJ', dialCode: '+992', flag: '🇹🇯'),
  CountryCode(name: 'Tanzania', code: 'TZ', dialCode: '+255', flag: '🇹🇿'),
  CountryCode(name: 'Thailand', code: 'TH', dialCode: '+66', flag: '🇹🇭'),
  CountryCode(name: 'Timor-Leste', code: 'TL', dialCode: '+670', flag: '🇹🇱'),
  CountryCode(name: 'Togo', code: 'TG', dialCode: '+228', flag: '🇹🇬'),
  CountryCode(name: 'Tonga', code: 'TO', dialCode: '+676', flag: '🇹🇴'),
  CountryCode(
    name: 'Trinidad and Tobago',
    code: 'TT',
    dialCode: '+1868',
    flag: '🇹🇹',
  ),
  CountryCode(name: 'Tunisia', code: 'TN', dialCode: '+216', flag: '🇹🇳'),
  CountryCode(name: 'Turkey', code: 'TR', dialCode: '+90', flag: '🇹🇷'),
  CountryCode(name: 'Turkmenistan', code: 'TM', dialCode: '+993', flag: '🇹🇲'),
  CountryCode(name: 'Tuvalu', code: 'TV', dialCode: '+688', flag: '🇹🇻'),
  CountryCode(name: 'Uganda', code: 'UG', dialCode: '+256', flag: '🇺🇬'),
  CountryCode(name: 'Ukraine', code: 'UA', dialCode: '+380', flag: '🇺🇦'),
  CountryCode(
    name: 'United Arab Emirates',
    code: 'AE',
    dialCode: '+971',
    flag: '🇦🇪',
  ),
  CountryCode(
    name: 'United Kingdom',
    code: 'GB',
    dialCode: '+44',
    flag: '🇬🇧',
  ),
  CountryCode(name: 'United States', code: 'US', dialCode: '+1', flag: '🇺🇸'),
  CountryCode(name: 'Uruguay', code: 'UY', dialCode: '+598', flag: '🇺🇾'),
  CountryCode(name: 'Uzbekistan', code: 'UZ', dialCode: '+998', flag: '🇺🇿'),
  CountryCode(name: 'Vanuatu', code: 'VU', dialCode: '+678', flag: '🇻🇺'),
  CountryCode(name: 'Vatican City', code: 'VA', dialCode: '+379', flag: '🇻🇦'),
  CountryCode(name: 'Venezuela', code: 'VE', dialCode: '+58', flag: '🇻🇪'),
  CountryCode(name: 'Vietnam', code: 'VN', dialCode: '+84', flag: '🇻🇳'),
  CountryCode(name: 'Yemen', code: 'YE', dialCode: '+967', flag: '🇾🇪'),
  CountryCode(name: 'Zambia', code: 'ZM', dialCode: '+260', flag: '🇿🇲'),
  CountryCode(name: 'Zimbabwe', code: 'ZW', dialCode: '+263', flag: '🇿🇼'),
];

class CustomerLoginScreen extends StatefulWidget {
  const CustomerLoginScreen({super.key});

  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeIn;

  final _phoneController = TextEditingController();
  CountryCode _selectedCountry = _countryCodes.firstWhere(
    (c) => c.code == 'SA',
    orElse: () => _countryCodes[0],
  );
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String _normalizePhone() {
    final raw = _phoneController.text.trim().replaceAll(
      RegExp(r'[\s\-\(\)]'),
      '',
    );
    final withoutLeadingZero = raw.startsWith('0') ? raw.substring(1) : raw;
    return '${_selectedCountry.dialCode}$withoutLeadingZero';
  }

  Future<void> _requestOtp() async {
    final l10n = AppLocalizations.of(context);
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = l10n.enterPhone);
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final normalized = _normalizePhone();
      Map<String, dynamic> otpResponse;
      if (MockApiDataSource.useMock) {
        otpResponse = await MockApiDataSource.requestOtp(normalized);
      } else {
        otpResponse = await CustomerAuthService(
          ApiClient(),
        ).requestOtp(phoneNumber: normalized);
      }
      if (mounted) {
        context.go(
          AppRoutes.customerOtp,
          extra: {
            'phone': normalized,
            'request_id': otpResponse['request_id']?.toString() ?? '',
            'expires_in': (otpResponse['expires_in'] as num?)?.toInt() ?? 120,
          },
        );
      }
    } catch (e) {
      final l = AppLocalizations.of(context);
      setState(() => _error = ApiException.messageOf(e) ?? l.failedToSendOtp);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCountryPicker() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CountryPickerSheet(
        selected: _selectedCountry,
        searchHint: l10n.searchCountry,
        title: l10n.selectCountry,
        onSelect: (c) {
          setState(() => _selectedCountry = c);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppTheme.mainBackground,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => context.go(AppRoutes.customerLanguage),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.cardWhite,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: AppTheme.primaryText,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                // Header image area — full-width, breaks out of scroll padding
                Container(
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    image: const DecorationImage(
                      image: NetworkImage(
                        'https://images.unsplash.com/photo-1565008447742-97f6f38c985c?w=800&q=80',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: AlignmentDirectional.centerStart,
                        end: AlignmentDirectional.centerEnd,
                        colors: [
                          AppTheme.brandNavy.withAlpha(204),
                          AppTheme.brandNavy.withAlpha(77),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          l10n.welcomeBack,
                          style: AppTheme.appFont(
                            context,
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          l10n.signInToAccess,
                          style: AppTheme.appFont(
                            context,
                            color: Colors.white.withAlpha(204),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 36),
                Text(
                  l10n.yourPhoneNumber,
                  style: AppTheme.appFont(
                    context,
                    color: AppTheme.primaryText,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.phoneSubtitle,
                  style: AppTheme.appFont(
                    context,
                    color: AppTheme.secondaryText,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 28),
                // Phone input — always LTR regardless of app locale
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardWhite,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _error != null
                            ? AppTheme.errorRed
                            : AppTheme.borderColor,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.shadowColor,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      textDirection: TextDirection.ltr,
                      children: [
                        // Country picker
                        GestureDetector(
                          onTap: _showCountryPicker,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 18,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                right: BorderSide(
                                  color: AppTheme.borderColor,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            child: Row(
                              textDirection: TextDirection.ltr,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _selectedCountry.flag,
                                  style: const TextStyle(fontSize: 20),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _selectedCountry.dialCode,
                                  textDirection: TextDirection.ltr,
                                  style: GoogleFonts.inter(
                                    color: AppTheme.primaryText,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 18,
                                  color: AppTheme.secondaryText,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Phone number input
                        Expanded(
                          child: TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.left,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[\d\s\-\(\)]'),
                              ),
                            ],
                            style: GoogleFonts.inter(
                              color: AppTheme.primaryText,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: '50 123 4567',
                              hintStyle: GoogleFonts.inter(
                                color: AppTheme.secondaryText.withAlpha(128),
                                fontSize: 16,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 18,
                              ),
                            ),
                            onSubmitted: (_) => _requestOtp(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ), // end Directionality LTR
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: AppTheme.appFont(
                      context,
                      color: AppTheme.errorRed,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                // WhatsApp OTP button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _requestOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.brandNavy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Send OTP via WhatsApp',
                                style: AppTheme.appFont(
                                  context,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                // Info note
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.softGoldBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppTheme.luxuryAccent.withAlpha(77),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppTheme.luxuryAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Your account is linked to your booking. Use the phone number provided during booking.',
                          style: AppTheme.appFont(
                            context,
                            color: AppTheme.brandNavy,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountryPickerSheet extends StatefulWidget {
  final CountryCode selected;
  final String searchHint;
  final String title;
  final ValueChanged<CountryCode> onSelect;

  const _CountryPickerSheet({
    required this.selected,
    required this.searchHint,
    required this.title,
    required this.onSelect,
  });

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _query = '';
  List<CountryCode> get _filtered => _countryCodes
      .where(
        (c) =>
            c.name.toLowerCase().contains(_query.toLowerCase()) ||
            c.dialCode.contains(_query),
      )
      .toList();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppTheme.mainBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: AppTheme.appFont(
                    context,
                    color: AppTheme.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: widget.searchHint,
                    hintStyle: AppTheme.appFont(
                      context,
                      color: AppTheme.secondaryText.withAlpha(128),
                      fontSize: 16,
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    filled: true,
                    fillColor: AppTheme.cardWhite,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.brandNavy),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final c = _filtered[i];
                final isSelected = c.code == widget.selected.code;
                return GestureDetector(
                  onTap: () => widget.onSelect(c),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.softGoldBg
                          : AppTheme.cardWhite,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.luxuryAccent
                            : AppTheme.borderColor,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(c.flag, style: const TextStyle(fontSize: 24)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            c.name,
                            style: AppTheme.appFont(
                              context,
                              color: AppTheme.primaryText,
                              fontSize: 15,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        Text(
                          c.dialCode,
                          style: AppTheme.appFont(
                            context,
                            color: isSelected
                                ? AppTheme.luxuryAccent
                                : AppTheme.secondaryText,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.check_circle_rounded,
                            color: AppTheme.luxuryAccent,
                            size: 18,
                          ),
                        ],
                      ],
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
