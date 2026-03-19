import 'package:equatable/equatable.dart';

class HintState extends Equatable {
  final String? activeHintId;
  final bool isLoading;
  final String? errorMessage;

  const HintState({
    this.activeHintId,
    this.isLoading = false,
    this.errorMessage,
  });

  bool isHintVisible(String hintId) => activeHintId == hintId;

  HintState copyWith({
    String? activeHintId,
    bool clearActiveHint = false,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return HintState(
      activeHintId: clearActiveHint
          ? null
          : (activeHintId ?? this.activeHintId),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [activeHintId, isLoading, errorMessage];
}
