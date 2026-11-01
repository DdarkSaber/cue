import 'package:cue/data/db/database.dart';
import 'package:drift/native.dart';

CueDatabase openTestDatabase() => CueDatabase(NativeDatabase.memory());
