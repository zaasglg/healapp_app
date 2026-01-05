import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/organization_repository.dart';
import '../../core/network/api_exceptions.dart';
import '../../utils/app_logger.dart';
import 'organization_event.dart';
import 'organization_state.dart';

class OrganizationBloc extends Bloc<OrganizationEvent, OrganizationState> {
  final OrganizationRepository _organizationRepository;

  OrganizationBloc({OrganizationRepository? organizationRepository})
    : _organizationRepository =
          organizationRepository ?? OrganizationRepository(),
      super(const OrganizationInitial()) {
    on<LoadOrganizationRequested>(_onLoadOrganizationRequested);
    on<UpdateOrganizationRequested>(_onUpdateOrganizationRequested);
  }

  /// Загрузка данных организации
  Future<void> _onLoadOrganizationRequested(
    LoadOrganizationRequested event,
    Emitter<OrganizationState> emit,
  ) async {
    emit(const OrganizationLoading());

    try {
      log.d('Загрузка данных организации...');

      final organization = await _organizationRepository.getOrganization();

      log.i('Организация загружена: $organization');
      emit(OrganizationLoaded(organization));
    } on UnauthorizedException {
      log.e('Ошибка авторизации');
      emit(const OrganizationFailure('Требуется авторизация'));
    } on NetworkException catch (e) {
      log.e('Ошибка сети: ${e.message}');
      emit(OrganizationFailure('Ошибка сети: ${e.message}'));
    } on ServerException catch (e) {
      log.e('Ошибка сервера: ${e.message}');
      emit(OrganizationFailure('Ошибка сервера: ${e.message}'));
    } on ApiException catch (e) {
      log.e('API ошибка: ${e.message}');
      emit(OrganizationFailure(e.message));
    } catch (e) {
      log.e('Неизвестная ошибка: $e');
      emit(const OrganizationFailure('Неизвестная ошибка'));
    }
  }

  /// Обновление данных организации
  Future<void> _onUpdateOrganizationRequested(
    UpdateOrganizationRequested event,
    Emitter<OrganizationState> emit,
  ) async {
    emit(const OrganizationLoading());

    try {
      log.d('Обновление данных организации:');
      log.d(
        'name: ${event.name}, phone: ${event.phone}, address: ${event.address}',
      );

      final organization = await _organizationRepository.updateOrganization(
        name: event.name,
        phone: event.phone,
        address: event.address,
      );

      log.i('Организация успешно обновлена: $organization');
      emit(OrganizationUpdated(organization));
    } on ValidationException catch (e) {
      log.w('Ошибка валидации: ${e.message}');
      log.w('Все ошибки: ${e.getAllErrors()}');
      final errorMessage = e.getAllErrors().isNotEmpty
          ? e.getAllErrors().join(', ')
          : e.message;
      emit(OrganizationFailure(errorMessage));
    } on UnauthorizedException {
      log.e('Ошибка авторизации');
      emit(const OrganizationFailure('Требуется авторизация'));
    } on NetworkException catch (e) {
      log.e('Ошибка сети: ${e.message}');
      emit(OrganizationFailure('Ошибка сети: ${e.message}'));
    } on ServerException catch (e) {
      log.e('Ошибка сервера: ${e.message}');
      emit(OrganizationFailure('Ошибка сервера: ${e.message}'));
    } on ApiException catch (e) {
      log.e('API ошибка: ${e.message}');
      emit(OrganizationFailure(e.message));
    } catch (e) {
      log.e('Неизвестная ошибка: $e');
      emit(const OrganizationFailure('Неизвестная ошибка'));
    }
  }
}
