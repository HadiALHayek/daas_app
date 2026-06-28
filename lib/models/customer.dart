class Customer {
  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? phone;
  final String? address;
  final DateTime? createdAt;

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      address: json['address'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'phone': phone,
        'address': address,
      };
}
