import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/organization_repository.dart';
import '../../core/network/api_exceptions.dart';
import 'organization_event.dart';
import 'organization_state.dart';

class OrganizationBloc extends Bloc<OrganizationEvent, OrganizationState> {
  final OrganizationRepository _organizationRepository;

  OrganizationBloc({OrganizationRepository? organizationRepository})
    : _organizationRepository =
          organizationRepository ?? OrganizationRepository(),
      super(const OrganizationInitial()) {
    on<UpdateOrganizationRequested>(_onUpdateOrganizationRequested);
  }

  Future<void> _onUpdateOrganizationRequested(
    UpdateOrganizationRequested event,
    Emitter<OrganizationState> emit,
  ) async {
    emit(const OrganizationLoading());

    try {
      print('📤 Обновление данных организации:');
      print('   name: ${event.name}');
      print('   phone: ${event.phone}');
      print('   address: ${event.address}');

      final organization = await _organizationRepository.updateOrganization(
        name: event.name,
        phone: event.phone,
        address: event.address,
      );

      print('✅ Организация успешно обновлена: $organization');
      emit(OrganizationUpdated(organization));
    } on ValidationException catch (e) {
      print('❌ Ошибка валидации: ${e.message}');
      print('   Все ошибки: ${e.getAllErrors()}');
      final errorMessage = e.getAllErrors().isNotEmpty
          ? e.getAllErrors().join(', ')
          : e.message;
      emit(OrganizationFailure(errorMessage));
    } on UnauthorizedException {
      print('❌ Ошибка авторизации');
      emit(const OrganizationFailure('Требуется авторизация'));
    } on NetworkException catch (e) {
      print('❌ Ошибка сети: ${e.message}');
      emit(OrganizationFailure('Ошибка сети: ${e.message}'));
    } on ServerException catch (e) {
      print('❌ Ошибка сервера: ${e.message}');
      emit(OrganizationFailure('Ошибка сервера: ${e.message}'));
    } on ApiException catch (e) {
      print('❌ API ошибка: ${e.message}');
      emit(OrganizationFailure(e.message));
    } catch (e) {
      print('❌ Неизвестная ошибка: $e');
      emit(const OrganizationFailure('Неизвестная ошибка'));
    }
  }
}
