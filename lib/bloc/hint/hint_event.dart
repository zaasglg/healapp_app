import 'package:equatable/equatable.dart';

abstract class HintEvent extends Equatable {
  const HintEvent();

  @override
  List<Object?> get props => [];
}

class HintShowRequested extends HintEvent {
  final String hintId;

  const HintShowRequested(this.hintId);

  @override
  List<Object?> get props => [hintId];
}

class HintDismissRequested extends HintEvent {
  final String hintId;

  const HintDismissRequested(this.hintId);

  @override
  List<Object?> get props => [hintId];
}

class HintResetRequested extends HintEvent {
  const HintResetRequested();
}
