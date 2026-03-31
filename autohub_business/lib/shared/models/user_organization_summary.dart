class UserOrganizationSummary {
  final String id;
  final String name;
  final String role;

  const UserOrganizationSummary({
    required this.id,
    required this.name,
    required this.role,
  });

  factory UserOrganizationSummary.fromJson(Map<String, dynamic> j) {
    return UserOrganizationSummary(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      role: (j['role'] as String? ?? '').toLowerCase(),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'role': role};
}
