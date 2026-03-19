import 'package:flutter_bloc/flutter_bloc.dart';
import '../../config/app_config.dart';
import '../../repositories/hint_repository.dart';
import 'hint_event.dart';
import 'hint_state.dart';

class HintBloc extends Bloc<HintEvent, HintState> {
  final HintRepository _hintRepository;

  HintBloc({HintRepository? hintRepository})
    : _hintRepository = hintRepository ?? const HintRepository(),
      super(const HintState()) {
    on<HintShowRequested>(_onShowRequested);
    on<HintDismissRequested>(_onDismissRequested);
    on<HintResetRequested>(_onResetRequested);
  }

  Future<void> _onShowRequested(
    HintShowRequested event,
    Emitter<HintState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      if (AppConfig.demoHintsAlwaysVisible) {
        emit(
          state.copyWith(
            activeHintId: event.hintId,
            isLoading: false,
            clearError: true,
          ),
        );
        return;
      }

      final isSeen = await _hintRepository.isHintSeen(event.hintId);

      if (isSeen) {
        emit(
          state.copyWith(
            isLoading: false,
            clearActiveHint: state.activeHintId == event.hintId,
            clearError: true,
          ),
        );
        return;
      }

      emit(
        state.copyWith(
          activeHintId: event.hintId,
          isLoading: false,
          clearError: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Не удалось загрузить подсказку',
        ),
      );
    }
  }

  Future<void> _onDismissRequested(
    HintDismissRequested event,
    Emitter<HintState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      if (!AppConfig.demoHintsAlwaysVisible) {
        await _hintRepository.markHintSeen(event.hintId);
      }
      emit(
        state.copyWith(
          isLoading: false,
          clearActiveHint: state.activeHintId == event.hintId,
          clearError: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          clearActiveHint: state.activeHintId == event.hintId,
          errorMessage: 'Не удалось сохранить подсказку',
        ),
      );
    }
  }

  Future<void> _onResetRequested(
    HintResetRequested event,
    Emitter<HintState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      await _hintRepository.resetAllHints();
      emit(
        state.copyWith(
          isLoading: false,
          clearActiveHint: true,
          clearError: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Не удалось сбросить подсказки',
        ),
      );
    }
  }
}
