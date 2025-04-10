/// Класс для сохраненных поисков
class SavedSearch {
  final String id;
  final String name;
  final String? city;
  final DateTime? checkInDate;
  final DateTime? checkOutDate;
  final int? guestsCount;
  final double? minPrice;
  final double? maxPrice;
  final String? propertyType;
  final DateTime createdAt;

  SavedSearch({
    required this.id,
    required this.name,
    this.city,
    this.checkInDate,
    this.checkOutDate,
    this.guestsCount,
    this.minPrice,
    this.maxPrice,
    this.propertyType,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
} 