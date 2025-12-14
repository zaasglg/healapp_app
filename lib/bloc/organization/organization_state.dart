import 'package:equatable/equatable.dart';

abstract class OrganizationState extends Equatable {
  const OrganizationState();

  @override
  List<Object?> get props => [];
}

class OrganizationInitial extends OrganizationState {
  const OrganizationInitial();
}

class OrganizationLoading extends OrganizationState {
  const OrganizationLoading();
}

class OrganizationUpdated extends OrganizationState {
  final Map<String, dynamic> organization;

  const OrganizationUpdated(this.organization);

  @override
  List<Object?> get props => [organization];
}

class OrganizationFailure extends OrganizationState {
  final String message;

  const OrganizationFailure(this.message);

  @override
  List<Object?> get props => [message];
}
