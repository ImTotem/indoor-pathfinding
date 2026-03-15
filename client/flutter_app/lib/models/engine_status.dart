enum SessionState {
  idle,
  mapping,
  localizing,
  error;

  static SessionState fromString(String value) {
    switch (value) {
      case 'mapping':
        return SessionState.mapping;
      case 'localizing':
        return SessionState.localizing;
      case 'error':
        return SessionState.error;
      default:
        return SessionState.idle;
    }
  }
}

class PoseResult {
  final double x, y, z;
  final double qx, qy, qz, qw;

  const PoseResult({
    required this.x,
    required this.y,
    required this.z,
    required this.qx,
    required this.qy,
    required this.qz,
    required this.qw,
  });

  factory PoseResult.fromMap(Map<dynamic, dynamic> map) {
    return PoseResult(
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      z: (map['z'] as num).toDouble(),
      qx: (map['qx'] as num).toDouble(),
      qy: (map['qy'] as num).toDouble(),
      qz: (map['qz'] as num).toDouble(),
      qw: (map['qw'] as num).toDouble(),
    );
  }
}

class EngineStatus {
  final SessionState state;
  final PoseResult? pose;
  final int frameCount;
  final int totalPushed;
  final bool queueFull;
  final String? errorMessage;
  // IMU
  final List<double>? accel; // [ax, ay, az]
  final List<double>? gyro; // [gx, gy, gz]
  // 기압
  final double? pressure; // hPa

  const EngineStatus({
    required this.state,
    this.pose,
    required this.frameCount,
    this.totalPushed = 0,
    this.queueFull = false,
    this.errorMessage,
    this.accel,
    this.gyro,
    this.pressure,
  });

  factory EngineStatus.fromMap(Map<dynamic, dynamic> map) {
    return EngineStatus(
      state: SessionState.fromString(map['state'] as String? ?? 'idle'),
      pose: map['pose'] != null
          ? PoseResult.fromMap(map['pose'] as Map<dynamic, dynamic>)
          : null,
      frameCount: (map['frameCount'] as num?)?.toInt() ?? 0,
      totalPushed: (map['totalPushed'] as num?)?.toInt() ?? 0,
      queueFull: map['queueFull'] as bool? ?? false,
      errorMessage: map['errorMessage'] as String?,
      accel: (map['accel'] as List?)?.map((e) => (e as num).toDouble()).toList(),
      gyro: (map['gyro'] as List?)?.map((e) => (e as num).toDouble()).toList(),
      pressure: (map['pressure'] as num?)?.toDouble(),
    );
  }

  static const idle = EngineStatus(
    state: SessionState.idle,
    frameCount: 0,
  );

  bool get isActive =>
      state == SessionState.mapping || state == SessionState.localizing;
}
