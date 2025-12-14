import 'package:equatable/equatable.dart';

abstract class OrganizationEvent extends Equatable {
  const OrganizationEvent();

  @override
  List<Object?> get props => [];
}

class UpdateOrganizationRequested extends OrganizationEvent {
  final String name;
  final String phone;
  final String address;

  const UpdateOrganizationRequested({
    required this.name,
    required this.phone,
    required this.address,
  });

  @override
  List<Object?> get props => [name, phone, address];
}
