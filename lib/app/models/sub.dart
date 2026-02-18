import 'dart:io';

class Sub {
  int? id;
  String name;
  File subPath1;
  File mp3Path;
  
  Sub(this.name, this.subPath1, this.mp3Path, {this.id});

  // Convert Sub to Map for database operations
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'subPath1': subPath1.path,
      'mp3Path': mp3Path.path,
    };
  }

  // Create Sub from Map (from database)
  factory Sub.fromMap(Map<String, dynamic> map) {
    return Sub(
      map['name'],
      File(map['subPath1']),
      File(map['mp3Path']),
      id: map['id'],
    );
  }

  // Copy with method for creating modified copies
  Sub copyWith({
    int? id,
    String? name,
    File? subPath1,
    File? mp3Path,
  }) {
    return Sub(
      name ?? this.name,
      subPath1 ?? this.subPath1,
      mp3Path ?? this.mp3Path,
      id: id ?? this.id,
    );
  }

  @override
  String toString() {
    return 'Sub(id: $id, name: $name, subPath1: ${subPath1.path}, mp3Path: ${mp3Path.path})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Sub &&
        other.id == id &&
        other.name == name &&
        other.subPath1.path == subPath1.path &&
        other.mp3Path.path == mp3Path.path;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        subPath1.path.hashCode ^
        mp3Path.path.hashCode;
  }
}
