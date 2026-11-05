import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_theme.dart';
import '../../routes/app_routes.dart';
import '../../l10n/app_localizations.dart';
import '../../services/localization_service.dart';
import '../../services/driver_api_service.dart';
import '../../services/api_client.dart';
import '../../data/mock_api_data_source.dart';
import '../../models/driver_bootstrap_model.dart';
import '../../models/driver_profile_model.dart';
import '../../widgets/first_letter_capitalize_formatter.dart';
import '../../widgets/az_case.dart';

class DriverProfileCompletionScreen extends StatefulWidget {
  /// Bootstrap data passed from the profile check screen so we can
  /// pre-fill phone / username from Odoo without an extra network call.
  final DriverBootstrapModel? bootstrap;

  /// Driver returned by login (used to pre-fill vehicle fields).
  final DriverProfile? initialDriver;

  const DriverProfileCompletionScreen({
    super.key,
    this.bootstrap,
    this.initialDriver,
  });

  @override
  State<DriverProfileCompletionScreen> createState() =>
      _DriverProfileCompletionScreenState();
}

class _DriverProfileCompletionScreenState
    extends State<DriverProfileCompletionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  final _driverNameController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  final _manufacturingYearController = TextEditingController();

  String? _selectedVehicleType;

  static const List<String> _vehicleTypes = [
    'Sedan',
    'Minivan',
    'Mercedes Vito',
    'Sprinter',
    'Minibus',
    'Bus',
  ];

  // Photo slots: null = empty, Uint8List = compressed JPEG already uploaded
  final List<Uint8List?> _personalPhotos = List.filled(3, null);
  final List<Uint8List?> _vehiclePhotos = List.filled(5, null);

  // Slots currently uploading ("personal_1", "vehicle_3", ...)
  final Set<String> _uploadingSlots = {};

  // Slots highlighted as missing after a profile_completed=false response
  bool _highlightPersonal = false;
  bool _highlightVehicle = false;

  final ImagePicker _imagePicker = ImagePicker();

  bool _isSubmitting = false;
  String? _errorMessage;
  String? _statusMessage;

  static const int _maxPersonalPhotos = 3;
  static const int _maxVehiclePhotos = 5;
  static const int _maxImageWidth = 1280;
  static const int _jpegQuality = 80;

  // Validation helpers
  bool get _isDriverNameValid {
    final text = _driverNameController.text.trim();
    if (text.isEmpty) return false;
    return RegExp(
      r"^[A-Za-zƏəĞğıİŞşÇçÖöÜü][A-Za-zƏəĞğıİŞşÇçÖöÜü ]*$",
    ).hasMatch(text);
  }

  bool get _isVehicleModelValid {
    final text = _vehicleModelController.text.trim();
    if (text.isEmpty) return false;
    return RegExp(
      r"^[A-Za-z0-9ƏəĞğıİŞşÇçÖöÜü][A-Za-z0-9ƏəĞğıİŞşÇçÖöÜü ]*$",
    ).hasMatch(text);
  }

  bool get _isVehicleColorValid =>
      _vehicleColorController.text.trim().isNotEmpty;

  bool get _isManufacturingYearValid {
    final text = _manufacturingYearController.text.trim();
    if (text.length != 4) return false;
    final year = int.tryParse(text);
    if (year == null) return false;
    final currentYear = DateTime.now().year;
    return year >= 1980 && year <= currentYear + 1;
  }

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
    LocalizationService.instance.addListener(_onLocaleChanged);
    _prefillVehicleFields();
  }

  void _applyDriverPrefill(DriverProfile? d) {
    if (d == null) return;
    if (_vehicleModelController.text.isEmpty && d.vehicleModel.isNotEmpty) {
      _vehicleModelController.text = d.vehicleModel;
    }
    if (_vehicleColorController.text.isEmpty && d.vehicleColor.isNotEmpty) {
      _vehicleColorController.text = d.vehicleColor;
    }
    if (_manufacturingYearController.text.isEmpty && d.vehicleYear.isNotEmpty) {
      _manufacturingYearController.text = d.vehicleYear;
    }
  }

  Future<void> _prefillVehicleFields() async {
    _applyDriverPrefill(widget.bootstrap?.driver ?? widget.initialDriver);
    if (widget.bootstrap != null || widget.initialDriver != null) return;
    if (MockApiDataSource.useMock) return;
    try {
      final b = await DriverApiService(ApiClient()).refreshBootstrap();
      if (!mounted) return;
      setState(() => _applyDriverPrefill(b.driver));
    } catch (_) {}
  }

  @override
  void dispose() {
    _animController.dispose();
    _driverNameController.dispose();
    _vehicleModelController.dispose();
    _vehicleColorController.dispose();
    _manufacturingYearController.dispose();
    LocalizationService.instance.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() => setState(() {});

  int get _personalPhotoCount => _personalPhotos.where((p) => p != null).length;
  int get _vehiclePhotoCount => _vehiclePhotos.where((p) => p != null).length;

  bool get _canSubmit =>
      _personalPhotoCount == _maxPersonalPhotos &&
      _vehiclePhotoCount == _maxVehiclePhotos &&
      _isDriverNameValid &&
      _selectedVehicleType != null &&
      _isVehicleModelValid &&
      _isVehicleColorValid &&
      _isManufacturingYearValid &&
      _uploadingSlots.isEmpty;

  static String _slotName(bool isPersonal, int index) =>
      '${isPersonal ? 'personal' : 'vehicle'}_${index + 1}';

  /// Picks an image, compresses it (max width 1280px, JPEG quality 80) and
  /// returns the compressed bytes. Returns null if the user cancelled.
  Future<Uint8List?> _pickAndCompress(ImageSource source) async {
    final picked = await _imagePicker.pickImage(source: source);
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    return _compress(bytes);
  }

  Future<Uint8List> _compress(Uint8List bytes) async {
    if (kIsWeb) return bytes;
    try {
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: _maxImageWidth,
        minHeight: _maxImageWidth,
        quality: _jpegQuality,
        format: CompressFormat.jpeg,
      );
      return result.isNotEmpty ? result : bytes;
    } catch (e) {
      debugPrint('[DRIVER PROFILE] compress failed ($e) — using original');
      return bytes;
    }
  }

  /// Picks a photo for the given slot and uploads it immediately.
  Future<void> _pickAndUpload(
    ImageSource source,
    bool isPersonal,
    int index,
  ) async {
    final slot = _slotName(isPersonal, index);
    final l10n = AppLocalizations.of(context);
    try {
      final bytes = await _pickAndCompress(source);
      if (bytes == null || !mounted) return;

      setState(() {
        _uploadingSlots.add(slot);
        _errorMessage = null;
      });

      if (!MockApiDataSource.useMock) {
        await DriverApiService(
          ApiClient(),
        ).uploadProfilePhoto(slot: slot, imageBase64: base64Encode(bytes));
      }

      if (!mounted) return;
      setState(() {
        if (isPersonal) {
          _personalPhotos[index] = bytes;
        } else {
          _vehiclePhotos[index] = bytes;
        }
      });
    } catch (e) {
      debugPrint('[DRIVER PROFILE] photo upload error ($slot): $e');
      if (mounted) {
        setState(() {
          _errorMessage = ApiException.messageOf(e) ?? l10n.profileSubmitError;
        });
      }
    } finally {
      if (mounted) setState(() => _uploadingSlots.remove(slot));
    }
  }

  void _showPhotoOptions(
    BuildContext context,
    AppLocalizations l10n,
    bool isPersonal,
    int index,
  ) {
    final photos = isPersonal ? _personalPhotos : _vehiclePhotos;
    final hasPhoto = photos[index] != null;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppTheme.cardWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.borderColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            if (!hasPhoto) ...[
              _BottomSheetOption(
                icon: Icons.camera_alt_rounded,
                label: l10n.takePhoto,
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUpload(ImageSource.camera, isPersonal, index);
                },
              ),
              const SizedBox(height: 8),
              _BottomSheetOption(
                icon: Icons.photo_library_rounded,
                label: l10n.chooseFromGallery,
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUpload(ImageSource.gallery, isPersonal, index);
                },
              ),
            ] else ...[
              _BottomSheetOption(
                icon: Icons.refresh_rounded,
                label: l10n.replacePhoto,
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUpload(ImageSource.gallery, isPersonal, index);
                },
              ),
              const SizedBox(height: 8),
              _BottomSheetOption(
                icon: Icons.delete_outline_rounded,
                label: l10n.removePhoto,
                isDestructive: true,
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    if (isPersonal) {
                      _personalPhotos[index] = null;
                    } else {
                      _vehiclePhotos[index] = null;
                    }
                  });
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _submitProfile() async {
    final l10n = AppLocalizations.of(context);

    if (!_canSubmit) {
      setState(() => _errorMessage = l10n.fillAllFields);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _statusMessage = l10n.profileSubmitting;
      _highlightPersonal = false;
      _highlightVehicle = false;
    });

    try {
      bool profileCompleted;

      if (MockApiDataSource.useMock) {
        await MockApiDataSource.submitDriverProfile(
          driverName: _driverNameController.text.trim(),
          vehicleType: _selectedVehicleType ?? '',
          vehicleModel: _vehicleModelController.text.trim(),
          manufacturingYear: _manufacturingYearController.text.trim(),
          personalPhotos: const [],
          vehiclePhotos: const [],
        );
        profileCompleted = true;
      } else {
        final apiService = DriverApiService(ApiClient());

        final result = await apiService.submitProfile(
          vehicleModel: _vehicleModelController.text.trim(),
          vehicleYear: _manufacturingYearController.text.trim(),
          vehicleColor: _vehicleColorController.text.trim(),
        );
        profileCompleted = result['profile_completed'] == true;
      }

      if (!mounted) return;

      if (profileCompleted) {
        debugPrint(
          '[DRIVER ROUTE] DriverProfileCompletionScreen: profile_completed=true → navigating to driverLocationPermission',
        );
        setState(() => _statusMessage = l10n.profileSubmitSuccess);
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          context.go(AppRoutes.driverLocationPermission);
        }
      } else {
        // Stay on this screen and highlight the missing photos
        // (at least 1 personal + 1 vehicle photo are required).
        debugPrint(
          '[DRIVER ROUTE] DriverProfileCompletionScreen: submit returned profile_completed=false — staying on screen',
        );
        setState(() {
          _highlightPersonal = _personalPhotoCount < 1;
          _highlightVehicle = _vehiclePhotoCount < 1;
          _errorMessage = l10n.profileSubmitError;
          _statusMessage = null;
        });
      }
    } catch (e) {
      debugPrint(
        '[DRIVER ROUTE] DriverProfileCompletionScreen: submit error ($e)',
      );
      if (mounted) {
        setState(() {
          _errorMessage = ApiException.messageOf(e) ?? l10n.profileSubmitError;
          _statusMessage = null;
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppTheme.mainBackground,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: Column(
            children: [
              _buildHeader(l10n),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      _buildProgressBar(),
                      const SizedBox(height: 28),
                      _buildPersonalPhotosSection(l10n),
                      const SizedBox(height: 28),
                      _buildVehiclePhotosSection(l10n),
                      const SizedBox(height: 28),
                      _buildProfileInfoSection(l10n),
                      const SizedBox(height: 24),
                      if (_errorMessage != null) _buildErrorBanner(),
                      if (_statusMessage != null) _buildStatusBanner(),
                      const SizedBox(height: 16),
                      _buildSubmitButton(l10n),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      color: AppTheme.mainBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.brandNavy,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.completeYourProfile,
                      style: GoogleFonts.inter(
                        color: AppTheme.primaryText,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      l10n.profileCompletionSubtitle,
                      style: GoogleFonts.inter(
                        color: AppTheme.secondaryText,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    // 6 text/dropdown fields + photos
    final totalRequired = _maxPersonalPhotos + _maxVehiclePhotos + 6;
    int completed = _personalPhotoCount + _vehiclePhotoCount;
    if (_isDriverNameValid) completed++;
    if (_selectedVehicleType != null) completed++;
    if (_isVehicleModelValid) completed++;
    if (_isVehicleColorValid) completed++;
    if (_isManufacturingYearValid) completed++;
    final progress = completed / totalRequired;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${(progress * 100).round()}%',
              style: GoogleFonts.inter(
                color: AppTheme.navyText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$completed / $totalRequired',
              style: GoogleFonts.inter(
                color: AppTheme.secondaryText,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: AppTheme.borderColor,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.brandNavy),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalPhotosSection(AppLocalizations l10n) {
    return _PhotoSection(
      title: l10n.personalPhotos,
      subtitle: l10n.personalPhotosSubtitle,
      photos: _personalPhotos,
      required: _maxPersonalPhotos,
      icon: Icons.person_rounded,
      uploadingSlots: _uploadingSlots,
      slotPrefix: 'personal',
      highlightMissing: _highlightPersonal,
      onPhotoTap: (index) => _showPhotoOptions(context, l10n, true, index),
      l10n: l10n,
    );
  }

  Widget _buildVehiclePhotosSection(AppLocalizations l10n) {
    return _PhotoSection(
      title: l10n.vehiclePhotos,
      subtitle: l10n.vehiclePhotosSubtitle,
      photos: _vehiclePhotos,
      required: _maxVehiclePhotos,
      icon: Icons.directions_car_rounded,
      uploadingSlots: _uploadingSlots,
      slotPrefix: 'vehicle',
      highlightMissing: _highlightVehicle,
      onPhotoTap: (index) => _showPhotoOptions(context, l10n, false, index),
      l10n: l10n,
    );
  }

  Widget _buildProfileInfoSection(AppLocalizations l10n) {
    final bootstrap = widget.bootstrap;
    final hasPhone =
        bootstrap?.driverPhone != null && bootstrap!.driverPhone!.isNotEmpty;
    final hasUsername =
        bootstrap?.driverUsername != null &&
        bootstrap!.driverUsername!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.softGoldBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: AppTheme.luxuryAccent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l10n.vehicleInformation,
                style: GoogleFonts.inter(
                  color: AppTheme.primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Read-only Odoo fields ──────────────────────────────────────
          if (hasPhone) ...[
            _buildReadOnlyField(
              label: l10n.phoneNumber,
              value: bootstrap.driverPhone!,
              icon: Icons.phone_outlined,
            ),
            const SizedBox(height: 16),
          ],
          if (hasUsername) ...[
            _buildReadOnlyField(
              label: l10n.username,
              value: bootstrap.driverUsername!,
              icon: Icons.account_circle_outlined,
            ),
            const SizedBox(height: 16),
          ],

          // ── Editable fields ───────────────────────────────────────────
          // 1. Driver Name
          _buildTextField(
            controller: _driverNameController,
            label: l10n.driverNameLabel,
            hint: l10n.driverNameHint,
            icon: Icons.person_outline_rounded,
            textCapitalization: TextCapitalization.words,
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'[A-Za-zƏəĞğıİŞşÇçÖöÜü ]'),
              ),
              _TitleCaseFormatter(),
            ],
          ),
          const SizedBox(height: 16),
          // 2. Vehicle Type dropdown
          _buildVehicleTypeDropdown(l10n),
          const SizedBox(height: 16),
          // 3. Vehicle Model
          _buildTextField(
            controller: _vehicleModelController,
            label: l10n.vehicleModelLabel,
            hint: l10n.vehicleModelHintLong,
            icon: Icons.directions_car_outlined,
            textCapitalization: TextCapitalization.words,
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'[A-Za-z0-9ƏəĞğıİŞşÇçÖöÜü ]'),
              ),
              _TitleCaseFormatter(),
            ],
          ),
          const SizedBox(height: 16),
          // 3b. Model Year (required, 4 digits) — right under Vehicle Model
          _buildTextField(
            controller: _manufacturingYearController,
            label: l10n.modelYear,
            hint: '${l10n.exampleAbbrev} ${DateTime.now().year - 3}',
            icon: Icons.calendar_today_outlined,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
          ),
          const SizedBox(height: 16),
          // 3c. Vehicle Color
          _buildTextField(
            controller: _vehicleColorController,
            label: l10n.vehicleColorLabel,
            hint: l10n.vehicleColorHint,
            icon: Icons.palette_outlined,
            textCapitalization: TextCapitalization.words,
            inputFormatters: [
              LengthLimitingTextInputFormatter(30),
              const FirstLetterCapitalizeFormatter(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyField({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppTheme.primaryText,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.borderColor.withAlpha(60),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderColor, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppTheme.secondaryText, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  style: GoogleFonts.inter(
                    color: AppTheme.secondaryText,
                    fontSize: 15,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.softGoldBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  AppLocalizations.of(context).driverNameFromOdoo,
                  style: GoogleFonts.inter(
                    color: AppTheme.luxuryAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVehicleTypeDropdown(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.vehicleType,
          style: GoogleFonts.inter(
            color: AppTheme.primaryText,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.mainBackground,
            borderRadius: BorderRadius.circular(12),
            boxShadow: AppTheme.iconShadow,
            border: Border.all(
              color: _selectedVehicleType != null
                  ? AppTheme.navyText
                  : AppTheme.borderColor,
              width: 1.5,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedVehicleType,
              isExpanded: true,
              hint: Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  l10n.selectVehicleType,
                  style: GoogleFonts.inter(
                    color: AppTheme.secondaryText,
                    fontSize: 15,
                  ),
                ),
              ),
              icon: Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppTheme.secondaryText,
                  size: 22,
                ),
              ),
              padding: const EdgeInsets.only(left: 12),
              borderRadius: BorderRadius.circular(12),
              dropdownColor: AppTheme.cardWhite,
              style: GoogleFonts.inter(
                color: AppTheme.primaryText,
                fontSize: 15,
              ),
              items: _vehicleTypes.map((type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Row(
                    children: [
                      Icon(
                        Icons.directions_car_outlined,
                        color: AppTheme.secondaryText,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        l10n.vehicleTypeName(type),
                        style: GoogleFonts.inter(
                          color: AppTheme.primaryText,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedVehicleType = value);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: AppTheme.primaryText,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: AppTheme.iconShadow,
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            textCapitalization: textCapitalization,
            inputFormatters: inputFormatters,
            onChanged: (_) => setState(() {}),
            style: GoogleFonts.inter(color: AppTheme.primaryText, fontSize: 15),
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(icon, color: AppTheme.secondaryText, size: 20),
              filled: true,
              fillColor: AppTheme.mainBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.borderColor, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.borderColor, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.navyText, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorRed.withAlpha(51)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppTheme.errorRed,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: GoogleFonts.inter(color: AppTheme.errorRed, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final isSuccess =
        _statusMessage?.contains('success') == true ||
        _statusMessage?.contains('успешно') == true ||
        _statusMessage?.contains('წარმატებით') == true;
    final color = isSuccess ? AppTheme.successGreen : AppTheme.navyText;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(51)),
      ),
      child: Row(
        children: [
          if (!isSuccess)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(color: color, strokeWidth: 2),
            )
          else
            Icon(Icons.check_circle_outline_rounded, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _statusMessage!,
              style: GoogleFonts.inter(color: color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(AppLocalizations l10n) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: (_canSubmit && !_isSubmitting) ? _submitProfile : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _canSubmit
              ? AppTheme.brandNavy
              : AppTheme.borderColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                l10n.submitProfile,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

// ─── Title Case Text Input Formatter ──────────────────────────────────────────

class _TitleCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final buffer = StringBuffer();
    bool capitalizeNext = true;
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == ' ') {
        capitalizeNext = true;
        buffer.write(char);
      } else if (capitalizeNext) {
        buffer.write(AzCase.upper(char));
        capitalizeNext = false;
      } else {
        buffer.write(AzCase.lower(char));
      }
    }

    final formatted = buffer.toString();
    if (formatted == text) return newValue;
    // Same length (case-only change): keep selection; clear composing range.
    final base = newValue.selection.baseOffset.clamp(0, formatted.length);
    final extent = newValue.selection.extentOffset.clamp(0, formatted.length);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection(baseOffset: base, extentOffset: extent),
      composing: TextRange.empty,
    );
  }
}

// ─── Photo Section Widget ──────────────────────────────────────────────────────

class _PhotoSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Uint8List?> photos;
  final int required;
  final IconData icon;
  final Set<String> uploadingSlots;
  final String slotPrefix;
  final bool highlightMissing;
  final void Function(int index) onPhotoTap;
  final AppLocalizations l10n;

  const _PhotoSection({
    required this.title,
    required this.subtitle,
    required this.photos,
    required this.required,
    required this.icon,
    required this.uploadingSlots,
    required this.slotPrefix,
    required this.highlightMissing,
    required this.onPhotoTap,
    required this.l10n,
  });

  int get _uploadedCount => photos.where((p) => p != null).length;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlightMissing ? AppTheme.errorRed : AppTheme.borderColor,
          width: highlightMissing ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.softGoldBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.luxuryAccent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: AppTheme.primaryText,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: AppTheme.secondaryText,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _uploadedCount == required
                      ? AppTheme.successGreen.withAlpha(26)
                      : AppTheme.softGoldBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _uploadedCount == required
                        ? AppTheme.successGreen.withAlpha(77)
                        : AppTheme.luxuryAccent.withAlpha(77),
                  ),
                ),
                child: Text(
                  '$_uploadedCount / $required ${l10n.uploadedOf}',
                  style: GoogleFonts.inter(
                    color: _uploadedCount == required
                        ? AppTheme.successGreen
                        : AppTheme.luxuryAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: required <= 3 ? required : 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1,
            ),
            itemCount: required,
            itemBuilder: (context, index) {
              final photo = photos[index];
              final uploading = uploadingSlots.contains(
                '${slotPrefix}_${index + 1}',
              );
              return GestureDetector(
                onTap: uploading ? null : () => onPhotoTap(index),
                child: _PhotoSlot(
                  photo: photo,
                  index: index,
                  uploading: uploading,
                  highlight: highlightMissing && photo == null,
                  l10n: l10n,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Photo Slot Widget ─────────────────────────────────────────────────────────

class _PhotoSlot extends StatelessWidget {
  final Uint8List? photo;
  final int index;
  final bool uploading;
  final bool highlight;
  final AppLocalizations l10n;

  const _PhotoSlot({
    required this.photo,
    required this.index,
    required this.l10n,
    this.uploading = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    if (uploading) {
      return Container(
        decoration: BoxDecoration(
          color: AppTheme.mainBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderColor, width: 1.5),
        ),
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              color: AppTheme.brandNavy,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    if (photo != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(
              photo!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppTheme.softGoldBg,
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: AppTheme.secondaryText,
                ),
              ),
            ),
            Positioned(
              bottom: 6,
              right: 6,
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppTheme.brandNavy.withAlpha(204),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.edit_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.mainBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.iconShadow,
        border: Border.all(
          color: highlight ? AppTheme.errorRed : AppTheme.borderColor,
          width: 1.5,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            color: AppTheme.secondaryText,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.addPhoto,
            style: GoogleFonts.inter(
              color: AppTheme.secondaryText,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom Sheet Option ───────────────────────────────────────────────────────

class _BottomSheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  const _BottomSheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppTheme.errorRed : AppTheme.primaryText;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDestructive
              ? AppTheme.errorRed.withAlpha(10)
              : AppTheme.mainBackground,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppTheme.iconShadow,
          border: Border.all(
            color: isDestructive
                ? AppTheme.errorRed.withAlpha(51)
                : AppTheme.borderColor,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 14),
            Text(
              label,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
