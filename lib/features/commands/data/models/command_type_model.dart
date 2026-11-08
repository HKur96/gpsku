/// Represents a supported command type query result from Traccar REST API.
/// Endpoint: GET `/api/commands/types`
///
/// Traccar returns an array of Typed objects: `[{"type": "engineStop"}, {"type": "engineResume"}]`.
class CommandTypeModel {
  final String type;

  const CommandTypeModel({required this.type});

  // Common Traccar command type constants
  static const String typeCustom = 'custom';
  static const String typeEngineStop = 'engineStop';
  static const String typeEngineResume = 'engineResume';
  static const String typePositionSingle = 'positionSingle';
  static const String typePositionPeriodic = 'positionPeriodic';
  static const String typePositionStop = 'positionStop';
  static const String typeAlarmArm = 'alarmArm';
  static const String typeAlarmDisarm = 'alarmDisarm';
  static const String typeAlarmDismiss = 'alarmDismiss';
  static const String typeSetTimezone = 'setTimezone';
  static const String typeRequestPhoto = 'requestPhoto';
  static const String typePowerOff = 'powerOff';
  static const String typeRebootDevice = 'rebootDevice';
  static const String typeFactoryReset = 'factoryReset';
  static const String typeSendSms = 'sendSms';
  static const String typeSendUssd = 'sendUssd';
  static const String typeSosNumber = 'sosNumber';
  static const String typeSilenceTime = 'silenceTime';
  static const String typeSetPhonebook = 'setPhonebook';
  static const String typeMessage = 'message';
  static const String typeVoiceMessage = 'voiceMessage';
  static const String typeOutputControl = 'outputControl';
  static const String typeVoiceMonitoring = 'voiceMonitoring';
  static const String typeSetAgps = 'setAgps';
  static const String typeSetIndicator = 'setIndicator';
  static const String typeConfiguration = 'configuration';
  static const String typeGetVersion = 'getVersion';
  static const String typeFirmwareUpdate = 'firmwareUpdate';
  static const String typeSetConnection = 'setConnection';
  static const String typeSetOdometer = 'setOdometer';
  static const String typeGetModemStatus = 'getModemStatus';
  static const String typeGetDeviceStatus = 'getDeviceStatus';
  static const String typeSetSpeedLimit = 'setSpeedLimit';
  static const String typeModePowerSaving = 'modePowerSaving';
  static const String typeModeDeepSleep = 'modeDeepSleep';
  static const String typeVideoStart = 'videoStart';
  static const String typeVideoStop = 'videoStop';

  factory CommandTypeModel.fromJson(Map<String, dynamic> json) {
    return CommandTypeModel(type: json['type'] as String? ?? '');
  }

  Map<String, dynamic> toJson() => {'type': type};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommandTypeModel &&
          runtimeType == other.runtimeType &&
          type == other.type;

  @override
  int get hashCode => type.hashCode;

  @override
  String toString() => 'CommandTypeModel(type: $type)';
}
