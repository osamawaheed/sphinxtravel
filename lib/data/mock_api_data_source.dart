import '../models/customer_bootstrap_model.dart';
import '../models/driver_bootstrap_model.dart';
import '../models/driver_profile_model.dart';
import '../models/trip_model.dart';
import '../models/flight_model.dart';
import '../models/hotel_model.dart';
import '../models/extra_service_model.dart';
import '../models/transportation_segment_model.dart';
import '../models/driver_assignment_model.dart';
import '../models/vehicle_model.dart';
import '../services/localization_service.dart';

class MockApiDataSource {
  static const bool useMock = bool.fromEnvironment(
    'USE_MOCK_API',
    defaultValue: false,
  );

  static String get _lang => LocalizationService.instance.currentLanguage;

  // ─── Localized content helpers ─────────────────────────────────────────────

  static String _tripName(String lang) {
    switch (lang) {
      case 'ar':
        return 'رحلة جورجيا';
      case 'ru':
        return 'Путешествие по Грузии';
      case 'ka':
        return 'საქართველოს მოგზაურობა';
      default:
        return 'Georgia Journey';
    }
  }

  static String _tripDescription(String lang) {
    switch (lang) {
      case 'ar':
        return 'رحلة فاخرة عبر قلب جورجيا، تستكشف الأديرة العريقة والمناظر الجبلية والمطبخ العالمي.';
      case 'ru':
        return 'Премиальное путешествие по сердцу Грузии: древние монастыри, горные пейзажи и мировая кухня.';
      case 'ka':
        return 'პრემიუმ მოგზაურობა საქართველოს გულში: უძველესი მონასტრები, მთის პეიზაჟები და მსოფლიო სამზარეულო.';
      default:
        return 'A premium journey through the heart of Georgia, exploring ancient monasteries, mountain landscapes, and world-class cuisine.';
    }
  }

  static String _transferDescription(String lang) {
    switch (lang) {
      case 'ar':
        return 'نقل خاص إلى جبال كازبيغي عبر غودوري';
      case 'ru':
        return 'Частный трансфер в горы Казбеги через Гудаури';
      case 'ka':
        return 'კერძო ტრანსფერი ყაზბეგის მთებში გუდაურის გავლით';
      default:
        return 'Private transfer to Kazbegi mountains via Gudauri';
    }
  }

  static String _airportTransfer(String lang) {
    switch (lang) {
      case 'ar':
        return 'توصيل من المطار';
      case 'ru':
        return 'Трансфер из аэропорта';
      case 'ka':
        return 'აეროპორტის ტრანსფერი';
      default:
        return 'Airport Transfer';
    }
  }

  static String _simCardDescription(String lang) {
    switch (lang) {
      case 'ar':
        return 'شريحة اتصال محلية في جورجيا مع 10 جيجابايت بيانات';
      case 'ru':
        return 'Местная SIM-карта Грузии с 10 ГБ данных';
      case 'ka':
        return 'საქართველოს ლოკალური SIM ბარათი 10 GB მონაცემებით';
      default:
        return 'Georgia local SIM card with 10GB data';
    }
  }

  static String _insuranceDescription(String lang) {
    switch (lang) {
      case 'ar':
        return 'تغطية تأمين سفر شاملة';
      case 'ru':
        return 'Комплексное страхование путешествий';
      case 'ka':
        return 'სრული სამოგზაურო დაზღვევა';
      default:
        return 'Comprehensive travel insurance coverage';
    }
  }

  static String _breakfastTitle(String lang) {
    switch (lang) {
      case 'ar':
        return 'إفطار في الفندق';
      case 'ru':
        return 'Завтрак в отеле';
      case 'ka':
        return 'საუზმე სასტუმროში';
      default:
        return 'Breakfast at Hotel';
    }
  }

  static String _driverPickupTitle(String lang) {
    switch (lang) {
      case 'ar':
        return 'استقبال السائق';
      case 'ru':
        return 'Подача водителя';
      case 'ka':
        return 'მძღოლის მიყვანა';
      default:
        return 'Driver Pickup';
    }
  }

  static String _privateTransferDesc(String lang) {
    switch (lang) {
      case 'ar':
        return 'نقل خاص إلى كازبيغي';
      case 'ru':
        return 'Частный трансфер в Казбеги';
      case 'ka':
        return 'კერძო ტრანსფერი ყაზბეგში';
      default:
        return 'Private transfer to Kazbegi';
    }
  }

  static String _gudauriTitle(String lang) {
    switch (lang) {
      case 'ar':
        return 'منظر غودوري البانورامي';
      case 'ru':
        return 'Смотровая площадка Гудаури';
      case 'ka':
        return 'გუდაურის პანორამული ხედი';
      default:
        return 'Gudauri Viewpoint';
    }
  }

  static String _gudauriDesc(String lang) {
    switch (lang) {
      case 'ar':
        return 'مناظر بانورامية لجبال القوقاز الكبرى';
      case 'ru':
        return 'Панорамный вид на Большой Кавказ';
      case 'ka':
        return 'დიდი კავკასიონის პანორამული ხედები';
      default:
        return 'Panoramic views of the Greater Caucasus';
    }
  }

  static String _lunchTitle(String lang) {
    switch (lang) {
      case 'ar':
        return 'غداء في كازبيغي';
      case 'ru':
        return 'Обед в Казбеги';
      case 'ka':
        return 'სადილი ყაზბეგში';
      default:
        return 'Lunch at Kazbegi';
    }
  }

  static String _gergetiTitle(String lang) {
    switch (lang) {
      case 'ar':
        return 'كنيسة غيرغيتي الثالوث';
      case 'ru':
        return 'Церковь Гергети Троицы';
      case 'ka':
        return 'გერგეთის სამება';
      default:
        return 'Gergeti Trinity Church';
    }
  }

  static String _gergetiDesc(String lang) {
    switch (lang) {
      case 'ar':
        return 'زيارة الكنيسة الأيقونية من القرن الرابع عشر';
      case 'ru':
        return 'Посещение знаменитой церкви XIV века';
      case 'ka':
        return 'XIV საუკუნის ეკლესიის მონახულება';
      default:
        return 'Visit the iconic 14th century church';
    }
  }

  static String _checkInTitle(String lang, String hotelName) {
    switch (lang) {
      case 'ar':
        return 'تسجيل الوصول في $hotelName';
      case 'ru':
        return 'Заезд в $hotelName';
      case 'ka':
        return '$hotelName-ში ჩასვლა';
      default:
        return 'Check-in $hotelName';
    }
  }

  static String _hikingTitle(String lang) {
    switch (lang) {
      case 'ar':
        return 'جولة المشي في كازبيغي';
      case 'ru':
        return 'Пешеходная экскурсия по Казбеги';
      case 'ka':
        return 'ყაზბეგის ლაშქრობის ტური';
      default:
        return 'Kazbegi Hiking Tour';
    }
  }

  static String _hikingDesc(String lang) {
    switch (lang) {
      case 'ar':
        return 'مشي موجّه عبر مسارات جبلية خلابة';
      case 'ru':
        return 'Экскурсия с гидом по живописным горным тропам';
      case 'ka':
        return 'გიდის ხელმძღვანელობით ლაშქრობა მთის ბილიკებზე';
      default:
        return 'Guided hiking through stunning mountain trails';
    }
  }

  static String _driverNotes(String lang) {
    switch (lang) {
      case 'ar':
        return 'العميل: عبدالله العريبي. 2 مسافرين. الأمتعة: 2 حقيبة كبيرة.';
      case 'ru':
        return 'Клиент: Abdullah Oraybi. 2 пассажира. Багаж: 2 большие сумки.';
      case 'ka':
        return 'კლიენტი: Abdullah Oraybi. 2 მგზავრი. ბარგი: 2 დიდი ჩანთა.';
      default:
        return 'Customer: Abdullah Oraybi. 2 passengers. Luggage: 2 large bags.';
    }
  }

  // ─── Auth ──────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> requestOtp(String phone) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return {
      'success': true,
      'request_id': 'otp_mock_${DateTime.now().millisecondsSinceEpoch}',
      'expires_in': 120,
    };
  }

  static Future<Map<String, dynamic>> verifyOtp(
    String phone,
    String otp,
  ) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    if (otp == '123456' || otp.length == 6) {
      return {
        'success': true,
        'access_token':
            'mock_access_token_customer_${DateTime.now().millisecondsSinceEpoch}',
        'refresh_token': 'mock_refresh_token_customer',
        'role': 'customer',
      };
    }
    throw Exception('invalid_otp');
  }

  static Future<Map<String, dynamic>> driverLogin(
    String username,
    String password,
  ) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    if (username.isNotEmpty && password.isNotEmpty) {
      return {
        'success': true,
        'access_token':
            'mock_access_token_driver_${DateTime.now().millisecondsSinceEpoch}',
        'refresh_token': 'mock_refresh_token_driver',
        'expires_in': 3600,
        'user': {
          'id': 2871,
          'role': 'driver',
          'name': _mockDriverName,
          'phone': '+995555000111',
          'profile_completed': _mockProfileCompleted,
          'rating': 5.0,
          'trip_count': 1,
          'vehicle_model': _mockVehicleModel,
          'vehicle_color': 'Black',
          'photo_url': '',
          'location_required': true,
        },
      };
    }
    throw Exception('invalid_credentials');
  }

  // ─── Customer Bootstrap ────────────────────────────────────────────────────

  static Future<CustomerBootstrapModel> getCustomerBootstrap() async {
    await Future.delayed(const Duration(milliseconds: 600));
    final lang = _lang;
    final now = DateTime.now();
    final tripStart = now.subtract(const Duration(days: 2));
    final tripEnd = now.add(const Duration(days: 5));

    String dateStr(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    return CustomerBootstrapModel(
      customerId: 1001,
      customerName: 'Ahmed Al-Rashidi',
      customerPhone: '+966512345678',
      customerEmail: 'ahmed@example.com',
      avatarUrl: null,
      currency: 'USD',
      trips: [
        TripModel(
          id: 5001,
          reference: 'SPX-2024-GEO-001',
          name: _tripName(lang),
          destination: 'Tbilisi, Georgia',
          startDate: dateStr(tripStart),
          endDate: dateStr(tripEnd),
          totalDays: 7,
          currentDay: 3,
          status: 'active',
          heroImageUrl:
              'https://images.unsplash.com/photo-1565008447742-97f6f38c985c?w=800&q=80',
          description: _tripDescription(lang),
          tripState: 'in_progress',
          flights: [
            FlightModel(
              id: 101,
              flightNumber: 'EK 117',
              airline: 'Emirates',
              origin: 'DXB',
              destination: 'TBS',
              departureTime: '02:35',
              arrivalTime: '07:10',
              departureDate: dateStr(tripStart),
              terminal: 'T3',
              gate: 'B22',
              status: 'completed',
            ),
          ],
          hotels: [
            HotelModel(
              id: 201,
              name: 'Radisson Blu Iveria',
              location: 'Tbilisi, Georgia',
              checkIn: dateStr(tripStart),
              checkOut: dateStr(now.add(const Duration(days: 2))),
              nights: 4,
              roomType: 'Deluxe King Room',
              photoUrl:
                  'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=600&q=80',
              rating: 4.7,
              address: 'Rose Revolution Square 1, Tbilisi',
              phone: '+995322727272',
            ),
            HotelModel(
              id: 202,
              name: 'Rooms Hotel Kazbegi',
              location: 'Kazbegi, Georgia',
              checkIn: dateStr(now.add(const Duration(days: 2))),
              checkOut: dateStr(tripEnd),
              nights: 3,
              roomType: 'Mountain View Suite',
              photoUrl:
                  'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=600&q=80',
              rating: 4.9,
              address: 'Kazbegi, Stepantsminda',
              phone: '+995322727273',
            ),
          ],
          transportationSegments: [
            TransportationSegmentModel(
              id: 301,
              segmentType: 'transfer',
              pickupLocation: 'Radisson Blu Iveria',
              dropoffLocation: 'Kazbegi & Gudauri',
              pickupTime: '09:00',
              date: dateStr(now),
              description: _transferDescription(lang),
              status: 'scheduled',
              driverAssignment: DriverAssignment(
                driverId: 401,
                driverName: 'Giorgi Kvaratskhelia',
                driverPhone: '+995599123456',
                driverPhotoUrl:
                    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&q=80',
                rating: 4.8,
                totalTrips: 118,
                vehicle: VehicleModel(
                  id: 501,
                  make: 'Toyota',
                  model: 'Camry',
                  color: 'Black',
                  plateNumber: 'GG-123-AB',
                  vehicleType: 'sedan',
                ),
              ),
            ),
          ],
          extraServices: [
            ExtraServiceModel(
              id: 601,
              name: lang == 'ar'
                  ? 'شريحة eSIM'
                  : lang == 'ru'
                  ? 'eSIM карта'
                  : lang == 'ka'
                  ? 'eSIM ბარათი'
                  : 'eSIM Card',
              serviceType: 'sim_card',
              description: _simCardDescription(lang),
              quantity: 2,
              status: 'pending',
            ),
            ExtraServiceModel(
              id: 602,
              name: lang == 'ar'
                  ? 'تأمين السفر'
                  : lang == 'ru'
                  ? 'Страхование путешествий'
                  : lang == 'ka'
                  ? 'სამოგზაურო დაზღვევა'
                  : 'Travel Insurance',
              serviceType: 'insurance',
              description: _insuranceDescription(lang),
              quantity: 1,
              status: 'active',
            ),
          ],
          todayItinerary: [
            ItineraryItem(
              time: '09:00 AM',
              title: _driverPickupTitle(lang),
              location: 'Radisson Blu Iveria',
              type: 'transport',
              status: 'completed',
              description: lang == 'ar'
                  ? 'السائق: جيورجي ك.'
                  : lang == 'ru'
                  ? 'Водитель: Giorgi K.'
                  : lang == 'ka'
                  ? 'მძღოლი: გიორგი კ.'
                  : 'Driver: Giorgi K.',
            ),
            ItineraryItem(
              time: '10:00 – 19:00',
              title: lang == 'ar'
                  ? 'كازبيغي وغودوري'
                  : lang == 'ru'
                  ? 'Казбеги и Гудаури'
                  : lang == 'ka'
                  ? 'ყაზბეგი და გუდაური'
                  : 'Kazbegi & Gudauri',
              location: 'Georgia',
              type: 'tour',
              status: 'current',
              description: lang == 'ar'
                  ? 'جولة خاصة ليوم كامل'
                  : lang == 'ru'
                  ? 'Частный тур на полный день'
                  : lang == 'ka'
                  ? 'კერძო სრული დღის ტური'
                  : 'Private Full-Day Tour',
            ),
            ItineraryItem(
              time: '19:30',
              title: lang == 'ar'
                  ? 'العودة إلى الفندق'
                  : lang == 'ru'
                  ? 'Возврат в отель'
                  : lang == 'ka'
                  ? 'სასტუმროში დაბრუნება'
                  : 'Return to Hotel',
              location: 'Radisson Blu Iveria',
              type: 'hotel',
              status: 'upcoming',
            ),
          ],
          tomorrowItinerary: [
            ItineraryItem(
              time: '',
              title: lang == 'ar'
                  ? 'صباح حر'
                  : lang == 'ru'
                  ? 'Свободное утро'
                  : lang == 'ka'
                  ? 'თავისუფალი დილა'
                  : 'Free Morning',
              location: null,
              type: 'activity',
              status: 'upcoming',
            ),
            ItineraryItem(
              time: '2:00 PM',
              title: lang == 'ar'
                  ? 'تجربة مدينة تبليسي'
                  : lang == 'ru'
                  ? 'Тбилиси Сити Экспириенс'
                  : lang == 'ka'
                  ? 'თბილისის სიტი ექსფერიენსი'
                  : 'Tbilisi City Experience',
              location: 'Tbilisi, Georgia',
              type: 'tour',
              status: 'upcoming',
              description: _hikingDesc(lang),
            ),
          ],
        ),
      ],
    );
  }

  // ─── Driver Bootstrap ──────────────────────────────────────────────────────

  static Future<DriverBootstrapModel> getDriverBootstrap() async {
    await Future.delayed(const Duration(milliseconds: 600));
    final lang = _lang;
    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final tomorrowStr = () {
      final t = now.add(const Duration(days: 1));
      return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
    }();

    String dateStr(DateTime d) =>
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    // Trip started 2 days ago, ends in 8 days → Day 3 of 10
    final tripStart = now.subtract(const Duration(days: 2));
    final tripEnd = now.add(const Duration(days: 8));
    // Hotel 1: check-in 2 days ago, check-out in 2 days (4 nights)
    final hotel1CheckIn = dateStr(tripStart);
    final hotel1CheckOut = dateStr(now.add(const Duration(days: 2)));
    // Hotel 2: check-in in 2 days, check-out at trip end
    final hotel2CheckIn = dateStr(now.add(const Duration(days: 2)));
    final hotel2CheckOut = dateStr(tripEnd);

    final assignedTrip = TripModel(
      id: 4201,
      reference: 'RQ.42830',
      name: _tripName(lang),
      destination: lang == 'ru'
          ? 'Кахетия, Грузия'
          : lang == 'ka'
          ? 'კახეთი, საქართველო'
          : 'Kakheti, Georgia',
      startDate: dateStr(tripStart),
      endDate: dateStr(tripEnd),
      totalDays: 10,
      currentDay: 3,
      status: 'active',
      tripState: 'in_progress',
      customerName: 'Abdullah Oraybi',
      customerPhone: '+966512345678',
      arrivalDate: dateStr(tripStart),
      arrivalTime: '07:10',
      arrivalFlightNumber: 'XY 123',
      arrivalAirport: lang == 'ru'
          ? 'Международный аэропорт Тбилиси'
          : lang == 'ka'
          ? 'თბილისის საერთაშორისო აეროპორტი'
          : 'Tbilisi International Airport',
      arrivalAirline: 'Flynas',
      departureDate: dateStr(tripEnd),
      departureTime: '14:30',
      departureFlightNumber: 'EK 118',
      departureAirport: lang == 'ru'
          ? 'Тбилиси (TBS)'
          : lang == 'ka'
          ? 'თბილისი (TBS)'
          : 'Tbilisi (TBS)',
      departureAirline: 'Emirates',
      firstPickupLocation: lang == 'ru'
          ? 'Radisson Blu Iveria, Лобби'
          : lang == 'ka'
          ? 'Radisson Blu Iveria, ლობი'
          : 'Radisson Blu Iveria, Lobby',
      firstPickupTime: '09:00',
      vehicleDisplayName: _mockVehicleType.isNotEmpty
          ? '$_mockVehicleType · $_mockVehicleModel'
          : 'Mercedes Vito',
      passengerCount: 2,
      heroImageUrl:
          'https://images.unsplash.com/photo-1565008447742-97f6f38c985c?w=800&q=80',
      flights: [
        FlightModel(
          id: 101,
          flightNumber: 'EK 117',
          airline: 'Emirates',
          origin: 'DXB',
          destination: 'TBS',
          departureTime: '02:35',
          arrivalTime: '07:10',
          departureDate: dateStr(tripStart),
          terminal: 'T3',
          gate: 'B22',
          status: 'completed',
        ),
        FlightModel(
          id: 102,
          flightNumber: 'EK 118',
          airline: 'Emirates',
          origin: 'TBS',
          destination: 'DXB',
          departureTime: '14:30',
          arrivalTime: '18:45',
          departureDate: dateStr(tripEnd),
          terminal: 'T1',
          gate: null,
          status: 'scheduled',
        ),
      ],
      hotels: [
        HotelModel(
          id: 201,
          name: 'Radisson Blu Iveria',
          location: lang == 'ru'
              ? 'Тбилиси'
              : lang == 'ka'
              ? 'თბილისი'
              : 'Tbilisi',
          checkIn: hotel1CheckIn,
          checkOut: hotel1CheckOut,
          nights: 4,
          roomType: lang == 'ru'
              ? 'Делюкс Кинг'
              : lang == 'ka'
              ? 'დელუქს კინგი'
              : 'Deluxe King Room',
          checkInTime: '14:00',
          checkOutTime: '12:00',
          guestInfo: 'Abdullah Oraybi · 2 guests',
          photoUrl:
              'https://images.unsplash.com/photo-1566073771259-6a8506099945?w=600&q=80',
          rating: 4.7,
          address: 'Rose Revolution Square 1, Tbilisi',
          phone: '+995322727272',
        ),
        HotelModel(
          id: 202,
          name: 'Rooms Hotel Kazbegi',
          location: lang == 'ru'
              ? 'Казбеги'
              : lang == 'ka'
              ? 'ყაზბეგი'
              : 'Kazbegi',
          checkIn: hotel2CheckIn,
          checkOut: hotel2CheckOut,
          nights: 6,
          roomType: lang == 'ru'
              ? 'Сьют с видом на горы'
              : lang == 'ka'
              ? 'მთის ხედის სუიტი'
              : 'Mountain View Suite',
          checkInTime: '15:00',
          checkOutTime: '11:00',
          guestInfo: 'Abdullah Oraybi · 2 guests',
          photoUrl:
              'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=600&q=80',
          rating: 4.9,
          address: 'Kazbegi, Stepantsminda',
          phone: '+995322727273',
        ),
      ],
      transportationSegments: [
        // Today's segments
        TransportationSegmentModel(
          id: 301,
          segmentType: 'transfer',
          pickupLocation: lang == 'ru'
              ? 'Radisson Blu Iveria'
              : lang == 'ka'
              ? 'Radisson Blu Iveria'
              : 'Radisson Blu Iveria',
          dropoffLocation: lang == 'ru'
              ? 'Казбеги'
              : lang == 'ka'
              ? 'ყაზბეგი'
              : 'Kazbegi',
          pickupTime: '09:00',
          date: todayStr,
          description: lang == 'ru'
              ? 'Трансфер из отеля'
              : lang == 'ka'
              ? 'სასტუმროდან გამგზავრება'
              : 'Hotel Pickup',
          status: 'completed',
          tripReference: 'RQ.42830',
          customerName: 'Abdullah Oraybi',
          vehicleDisplayName: _mockVehicleType.isNotEmpty
              ? _mockVehicleType
              : 'Mercedes Vito',
          notes: _driverNotes(lang),
        ),
        TransportationSegmentModel(
          id: 302,
          segmentType: 'tour',
          pickupLocation: lang == 'ru'
              ? 'Казбеги'
              : lang == 'ka'
              ? 'ყაზბეგი'
              : 'Kazbegi',
          dropoffLocation: lang == 'ru'
              ? 'Казбеги и Гудаури'
              : lang == 'ka'
              ? 'ყაზბეგი და გუდაური'
              : 'Kazbegi & Gudauri',
          pickupTime: '10:00',
          date: todayStr,
          description: lang == 'ru'
              ? 'Казбеги и Гудаури — Частный тур на весь день'
              : lang == 'ka'
              ? 'ყაზბეგი და გუდაური — კერძო მთელი დღის ტური'
              : 'Kazbegi & Gudauri — Private Full-Day Tour',
          status: 'active',
          tripReference: 'RQ.42830',
          customerName: 'Abdullah Oraybi',
          vehicleDisplayName: _mockVehicleType.isNotEmpty
              ? _mockVehicleType
              : 'Mercedes Vito',
          notes: 'Stops: Ananuri, Gudauri, Kazbegi. End time: 19:00',
        ),
        TransportationSegmentModel(
          id: 304,
          segmentType: 'transfer',
          pickupLocation: lang == 'ru'
              ? 'Казбеги'
              : lang == 'ka'
              ? 'ყაზბეგი'
              : 'Kazbegi',
          dropoffLocation: lang == 'ru'
              ? 'Radisson Blu Iveria'
              : lang == 'ka'
              ? 'Radisson Blu Iveria'
              : 'Radisson Blu Iveria',
          pickupTime: '19:30',
          date: todayStr,
          description: lang == 'ru'
              ? 'Возврат в отель'
              : lang == 'ka'
              ? 'სასტუმროში დაბრუნება'
              : 'Return to Hotel',
          status: 'scheduled',
          tripReference: 'RQ.42830',
          customerName: 'Abdullah Oraybi',
          vehicleDisplayName: _mockVehicleType.isNotEmpty
              ? _mockVehicleType
              : 'Mercedes Vito',
        ),
        // Tomorrow's segments
        TransportationSegmentModel(
          id: 305,
          segmentType: 'transfer',
          pickupLocation: lang == 'ru'
              ? 'Radisson Blu Iveria'
              : lang == 'ka'
              ? 'Radisson Blu Iveria'
              : 'Radisson Blu Iveria',
          dropoffLocation: lang == 'ru'
              ? 'Казбеги'
              : lang == 'ka'
              ? 'ყაზბეგი'
              : 'Kazbegi',
          pickupTime: '08:00',
          date: tomorrowStr,
          description: lang == 'ru'
              ? 'Частный трансфер в Казбеги'
              : lang == 'ka'
              ? 'კერძო ტრანსფერი ყაზბეგში'
              : 'Private transfer to Kazbegi',
          status: 'scheduled',
          tripReference: 'RQ.42830',
          customerName: 'Abdullah Oraybi',
          vehicleDisplayName: _mockVehicleType.isNotEmpty
              ? _mockVehicleType
              : 'Mercedes Vito',
        ),
      ],
      extraServices: [
        ExtraServiceModel(
          id: 601,
          name: lang == 'ru'
              ? 'eSIM карта'
              : lang == 'ka'
              ? 'eSIM ბარათი'
              : 'eSIM Card',
          serviceType: 'sim_card',
          description: _simCardDescription(lang),
          quantity: 2,
          status: 'pending',
        ),
        ExtraServiceModel(
          id: 602,
          name: lang == 'ru'
              ? 'Страхование путешествий'
              : lang == 'ka'
              ? 'სამოგზაურო დაზღვევა'
              : 'Travel Insurance',
          serviceType: 'insurance',
          description: _insuranceDescription(lang),
          quantity: 1,
          status: 'active',
        ),
      ],
      todayItinerary: [],
      tomorrowItinerary: [],
    );

    final mockSegments = assignedTrip.transportationSegments;
    TransportationSegmentModel? mockNextToday;
    for (final s in mockSegments) {
      if (s.date == todayStr && !s.isCompleted) {
        mockNextToday = s;
        break;
      }
    }

    return DriverBootstrapModel(
      driver: DriverProfile(
        id: 2871,
        name: _mockDriverName,
        phone: '+995555000111',
        profileCompleted: _mockProfileCompleted,
        rating: 5.0,
        tripCount: 1,
        vehicleModel: _mockVehicleModel,
        vehicleColor: 'Black',
        photoUrl: _mockProfilePhotoUrl ?? '',
      ),
      locationRequired: true,
      nextToday: mockNextToday,
      assignedSegments: mockSegments,
      assignedTrips: [assignedTrip],
    );
  }

  // ─── Driver Profile (Mock Odoo source of truth) ────────────────────────────

  /// Simulates profile_completed state stored in Odoo.
  /// In production this comes from GET /api/v1/driver/profile.
  static bool _mockProfileCompleted = false;

  /// Stores the driver name entered during profile submission for the session.
  /// Odoo is the source of truth; in mock mode this persists across screens.
  static String _mockDriverName = 'Driver';

  /// Stores vehicle data entered during profile submission.
  static String _mockVehicleType = '';
  static String _mockVehicleModel = '';
  static String _mockManufacturingYear = '';
  static String? _mockProfilePhotoUrl;

  static Future<Map<String, dynamic>> getDriverProfile() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return {
      'name': _mockDriverName,
      'profile_completed': _mockProfileCompleted,
      'vehicle_model': _mockProfileCompleted ? 'Toyota Camry' : '',
      'personal_photos': _mockProfileCompleted
          ? [
              'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=400&q=80',
              'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=400&q=80',
              'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=400&q=80',
            ]
          : [],
      'vehicle_photos': _mockProfileCompleted
          ? [
              'https://images.unsplash.com/photo-1449965408869-eaa3f722e40d?w=400&q=80',
              'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=400&q=80',
              'https://images.unsplash.com/photo-1494976388531-d1058494cdd8?w=400&q=80',
              'https://images.unsplash.com/photo-1583121274602-3e2820c69888?w=400&q=80',
              'https://images.unsplash.com/photo-1542362567-b07e54358753?w=400&q=80',
            ]
          : [],
    };
  }

  /// Simulates PUT /api/v1/driver/profile + POST /api/v1/driver/profile/photos
  /// Sets profile_completed = true in Odoo (mock) and stores the driver name.
  static Future<Map<String, dynamic>> submitDriverProfile({
    required String driverName,
    required String vehicleModel,
    required List<String> personalPhotos,
    required List<String> vehiclePhotos,
    String? profilePhotoUrl,
    String? vehicleType,
    String? manufacturingYear,
  }) async {
    await Future.delayed(const Duration(milliseconds: 1200));
    // Simulate Odoo storing profile_completed = true and saving driver name
    _mockProfileCompleted = true;
    if (driverName.isNotEmpty) {
      _mockDriverName = driverName;
    }
    _mockVehicleModel = vehicleModel;
    _mockVehicleType = vehicleType ?? '';
    _mockManufacturingYear = manufacturingYear ?? '';
    _mockProfilePhotoUrl = profilePhotoUrl;
    return {
      'success': true,
      'profile_completed': true,
      'driver_name': _mockDriverName,
      'vehicle_model': vehicleModel,
      'personal_photos': personalPhotos,
      'vehicle_photos': vehiclePhotos,
    };
  }
}
