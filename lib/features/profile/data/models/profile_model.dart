import 'package:hive/hive.dart';

enum ProfileType { xtream, m3u }

class ProfileModel {
  const ProfileModel({
    required this.id,
    required this.profileName,
    required this.type,
    this.serverUrl,
    this.username,
    this.password,
    this.m3uUrl,
    this.avatarPath,
    required this.createdDate,
  });

  final String id;
  final String profileName;
  final ProfileType type;
  final String? serverUrl;
  final String? username;
  final String? password;
  final String? m3uUrl;
  final String? avatarPath;
  final DateTime createdDate;

  ProfileModel copyWith({
    String? id,
    String? profileName,
    ProfileType? type,
    String? serverUrl,
    String? username,
    String? password,
    String? m3uUrl,
    String? avatarPath,
    DateTime? createdDate,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      profileName: profileName ?? this.profileName,
      type: type ?? this.type,
      serverUrl: serverUrl ?? this.serverUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      m3uUrl: m3uUrl ?? this.m3uUrl,
      avatarPath: avatarPath ?? this.avatarPath,
      createdDate: createdDate ?? this.createdDate,
    );
  }
}

class ProfileModelAdapter extends TypeAdapter<ProfileModel> {
  @override
  final int typeId = 1;

  @override
  ProfileModel read(BinaryReader reader) {
    final int numOfFields = reader.readByte();
    final Map<int, dynamic> fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return ProfileModel(
      id: fields[0] as String,
      profileName: fields[1] as String,
      type: ProfileType.values.byName(fields[2] as String),
      serverUrl: fields[3] as String?,
      username: fields[4] as String?,
      password: fields[5] as String?,
      m3uUrl: fields[6] as String?,
      avatarPath: fields[7] as String?,
      createdDate: fields[8] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ProfileModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.profileName)
      ..writeByte(2)
      ..write(obj.type.name)
      ..writeByte(3)
      ..write(obj.serverUrl)
      ..writeByte(4)
      ..write(obj.username)
      ..writeByte(5)
      ..write(obj.password)
      ..writeByte(6)
      ..write(obj.m3uUrl)
      ..writeByte(7)
      ..write(obj.avatarPath)
      ..writeByte(8)
      ..write(obj.createdDate);
  }
}
