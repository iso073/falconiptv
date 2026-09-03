part of 'connection_cubit.dart';

enum ConnectionPhase { checking, online, offline, serverIssue }

class ConnectionSnapshot {
  const ConnectionSnapshot({
    required this.phase,
    required this.title,
    required this.detail,
  });

  const ConnectionSnapshot.checking()
      : phase = ConnectionPhase.checking,
        title = 'Kontrol ediliyor',
        detail = 'Bağlantı durumu alınıyor...';

  final ConnectionPhase phase;
  final String title;
  final String detail;

  ConnectionSnapshot copyWith({
    ConnectionPhase? phase,
    String? title,
    String? detail,
  }) {
    return ConnectionSnapshot(
      phase: phase ?? this.phase,
      title: title ?? this.title,
      detail: detail ?? this.detail,
    );
  }
}
