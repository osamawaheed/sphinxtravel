enum TripStatus {
  assigned,
  onTheWay,
  arrived,
  passengerPickedUp,
  inProgress,
  completed;

  static TripStatus fromString(String s) {
    final key = s.trim().toLowerCase().replaceAll(RegExp(r'[\s\-]+'), '_');
    switch (key) {
      case 'on_the_way':
      case 'on_way':
      case 'ontheway':
      case 'arrived':
        return TripStatus.onTheWay;
      case 'passenger_picked_up':
      case 'picked_up':
      case 'pickedup':
      case 'passenger_on_board':
        return TripStatus.passengerPickedUp;
      case 'in_progress':
      case 'in_tour':
      case 'active':
        return TripStatus.inProgress;
      case 'completed':
      case 'done':
        return TripStatus.completed;
      default:
        return TripStatus.assigned;
    }
  }

  String toApiString() {
    switch (this) {
      case TripStatus.assigned:
        return 'assigned';
      case TripStatus.onTheWay:
        return 'on_the_way';
      case TripStatus.arrived:
        return 'arrived';
      case TripStatus.passengerPickedUp:
        return 'passenger_picked_up';
      case TripStatus.inProgress:
        return 'in_progress';
      case TripStatus.completed:
        return 'completed';
    }
  }

  TripStatus? get next {
    switch (this) {
      case TripStatus.assigned:
        return TripStatus.onTheWay;
      case TripStatus.onTheWay:
        return TripStatus.passengerPickedUp;
      case TripStatus.arrived:
        return TripStatus.passengerPickedUp;
      case TripStatus.passengerPickedUp:
        return TripStatus.inProgress;
      case TripStatus.inProgress:
        return TripStatus.completed;
      case TripStatus.completed:
        return null;
    }
  }

  bool get isCompleted => this == TripStatus.completed;
}
