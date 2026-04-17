// lib/features/auth/bloc/auth_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../repo/auth_repo.dart';

// Events
abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthCheckStatusEvent extends AuthEvent {}
class AuthLoginEvent extends AuthEvent {
  final String phone;
  final String otp;
  const AuthLoginEvent({required this.phone, required this.otp});
  @override
  List<Object?> get props => [phone, otp];
}
class AuthLogoutEvent extends AuthEvent {}
class AuthRegisterEvent extends AuthEvent {
  final String username;
  final String phone;
  final String? email;
  const AuthRegisterEvent({required this.username, required this.phone, this.email});
}

// States
abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}
class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}
class AuthAuthenticated extends AuthState {
  final String userId;
  final String username;
  final String? subscriptionTier;
  const AuthAuthenticated({required this.userId, required this.username, this.subscriptionTier});
  @override
  List<Object?> get props => [userId, username, subscriptionTier];
}
class AuthUnauthenticated extends AuthState {}
class AuthError extends AuthState {
  final String message;
  const AuthError(this.message);
  @override
  List<Object?> get props => [message];
}

// Bloc
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepo _repo;

  AuthBloc(this._repo) : super(AuthInitial()) {
    on<AuthCheckStatusEvent>(_onCheckStatus);
    on<AuthLoginEvent>(_onLogin);
    on<AuthLogoutEvent>(_onLogout);
    on<AuthRegisterEvent>(_onRegister);
  }

  Future<void> _onCheckStatus(AuthCheckStatusEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await _repo.getCurrentUser();
      if (user != null) {
        emit(AuthAuthenticated(
          userId: user['id'] as String,
          username: user['username'] as String,
          subscriptionTier: user['subscription_tier'] as String?,
        ));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (_) {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLogin(AuthLoginEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = await _repo.verifyOtp(phone: event.phone, otp: event.otp);
      emit(AuthAuthenticated(
        userId: user['id'] as String,
        username: user['username'] as String,
        subscriptionTier: user['subscription_tier'] as String?,
      ));
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }

  Future<void> _onLogout(AuthLogoutEvent event, Emitter<AuthState> emit) async {
    await _repo.logout();
    emit(AuthUnauthenticated());
  }

  Future<void> _onRegister(AuthRegisterEvent event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await _repo.register(
        username: event.username,
        phone: event.phone,
        email: event.email,
      );
      emit(AuthUnauthenticated()); // After register, go to OTP
    } catch (e) {
      emit(AuthError(e.toString()));
    }
  }
}
