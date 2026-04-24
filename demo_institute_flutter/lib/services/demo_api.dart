import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/announcement.dart';
import '../models/lecture_item.dart';
import '../models/material_item.dart';
import '../models/timetable_item.dart';

class DemoApi {
  DemoApi({http.Client? client}) : _client = client ?? http.Client();

  static const String apiBase = 'https://mmffj9rebh.execute-api.ap-south-1.amazonaws.com';

  final http.Client _client;

  String _basicAuth(String user, String pass) {
    final u = user.trim();
    final p = pass;
    final token = base64Encode(utf8.encode('$u:$p'));
    return 'Basic $token';
  }

  Uri _uri(String path, [Map<String, String?>? query]) {
    final q = <String, String>{};
    query?.forEach((k, v) {
      final s = v?.trim();
      if (s == null || s.isEmpty) return;
      q[k] = s;
    });
    return Uri.parse('$apiBase$path').replace(queryParameters: q.isEmpty ? null : q);
  }

  Uri _adminUri(String path, [Map<String, String?>? query]) => _uri(path, query);

  Future<List<Announcement>> getAnnouncements({String? klass, String? section}) async {
    final res = await _client.get(
      _uri('/announcements', {
        'class': klass,
        'section': section,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}');
    }

    final data = jsonDecode(res.body);
    final items = (data is Map<String, dynamic>) ? data['items'] : null;
    if (items is! List) return [];
    return items.map((x) => Announcement.fromJson(x)).toList();
  }

  Future<List<TimetableItem>> getTimetables({String? klass, String? section}) async {
    final res = await _client.get(
      _uri('/timetables', {
        'class': klass,
        'section': section,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}');
    }

    final data = jsonDecode(res.body);
    final items = (data is Map<String, dynamic>) ? data['items'] : null;
    if (items is! List) return [];
    return items.map((x) => TimetableItem.fromJson(x)).toList();
  }

  Future<List<MaterialItem>> getMaterials({required String category, String? klass}) async {
    final res = await _client.get(
      _uri('/materials', {
        'category': category,
        'class': klass,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}');
    }

    final data = jsonDecode(res.body);
    final items = (data is Map<String, dynamic>) ? data['items'] : null;
    if (items is! List) return [];
    return items.map((x) => MaterialItem.fromJson(x)).toList();
  }

  Future<List<LectureItem>> getLectures({String? klass}) async {
    final res = await _client.get(
      _uri('/lectures', {
        'class': klass,
      }),
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}');
    }

    final data = jsonDecode(res.body);
    final items = (data is Map<String, dynamic>) ? data['items'] : null;
    if (items is! List) return [];
    return items.map((x) => LectureItem.fromJson(x)).toList();
  }

  Future<void> submitLead({required String name, required String phone}) async {
    final res = await _client
        .post(
          _uri('/leads'),
          headers: {
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'name': name.trim(),
            'phone': phone.trim(),
          }),
        )
        .timeout(const Duration(seconds: 12));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
  }

  Future<void> submitBotclapLead({required String name, required String phone}) async {
    final uri = Uri.parse('https://botclap.com/webhook/contact/764610403118927');
    final res = await _client
        .post(
          uri,
          headers: {
            'content-type': 'application/x-www-form-urlencoded;charset=UTF-8',
          },
          body: {
            'Name': name,
            'PhoneNumber': phone,
          },
        )
        .timeout(const Duration(seconds: 25));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
  }

  Future<Map<String, dynamic>> getAdmissionOptions() async {
    final res = await _client.get(_uri('/admission/options')).timeout(const Duration(seconds: 12));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body);
    if (data is Map<String, dynamic>) return data;
    return const <String, dynamic>{};
  }

  Future<void> submitAdmission({required Map<String, dynamic> data, String photoBase64 = ''}) async {
    final res = await _client
        .post(
          _uri('/admission'),
          headers: {
            'content-type': 'application/json',
          },
          body: jsonEncode({
            'data': data,
            'photoBase64': photoBase64,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
  }

  Future<List<Map<String, dynamic>>> adminGetLectures({required String user, required String pass}) async {
    final res = await _client
        .get(
          _adminUri('/admin/lectures'),
          headers: {
            'authorization': _basicAuth(user, pass),
          },
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body);
    final items = (data is Map<String, dynamic>) ? data['items'] : null;
    if (items is! List) return const [];
    return items.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<void> adminCreateLecture({
    required String user,
    required String pass,
    required Map<String, dynamic> payload,
  }) async {
    final res = await _client
        .post(
          _adminUri('/admin/lectures'),
          headers: {
            'content-type': 'application/json',
            'authorization': _basicAuth(user, pass),
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
  }

  Future<void> adminDeleteLecture({required String user, required String pass, required String id}) async {
    final res = await _client
        .delete(
          _adminUri('/admin/lectures/$id'),
          headers: {
            'authorization': _basicAuth(user, pass),
          },
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
  }

  Future<List<Map<String, dynamic>>> adminGetAnnouncements({required String user, required String pass}) async {
    final res = await _client
        .get(
          _adminUri('/admin/announcements'),
          headers: {
            'authorization': _basicAuth(user, pass),
          },
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body);
    final items = (data is Map<String, dynamic>) ? data['items'] : null;
    if (items is! List) return const [];
    return items.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<void> adminCreateAnnouncement({
    required String user,
    required String pass,
    required Map<String, dynamic> payload,
  }) async {
    final res = await _client
        .post(
          _adminUri('/admin/announcements'),
          headers: {
            'content-type': 'application/json',
            'authorization': _basicAuth(user, pass),
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
  }

  Future<void> adminDeleteAnnouncement({required String user, required String pass, required String id}) async {
    final res = await _client
        .delete(
          _adminUri('/admin/announcements/$id'),
          headers: {
            'authorization': _basicAuth(user, pass),
          },
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
  }

  Future<List<Map<String, dynamic>>> adminGetSessions({required String user, required String pass}) async {
    final res = await _client
        .get(
          _adminUri('/admin/sessions'),
          headers: {
            'authorization': _basicAuth(user, pass),
          },
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body);
    final items = (data is Map<String, dynamic>) ? data['items'] : null;
    if (items is! List) return const [];
    return items.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<void> adminCreateSession({required String user, required String pass, required String name}) async {
    final res = await _client
        .post(
          _adminUri('/admin/sessions'),
          headers: {
            'content-type': 'application/json',
            'authorization': _basicAuth(user, pass),
          },
          body: jsonEncode({'name': name.trim()}),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
  }

  Future<void> adminDeleteSession({required String user, required String pass, required String id}) async {
    final res = await _client
        .delete(
          _adminUri('/admin/sessions/$id'),
          headers: {
            'authorization': _basicAuth(user, pass),
          },
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
  }

  Future<List<Map<String, dynamic>>> adminGetClasses({
    required String user,
    required String pass,
    required String session,
  }) async {
    final res = await _client
        .get(
          _adminUri('/admin/classes', {'session': session.trim()}),
          headers: {
            'authorization': _basicAuth(user, pass),
          },
        )
        .timeout(const Duration(seconds: 15));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body);
    final items = (data is Map<String, dynamic>) ? data['items'] : null;
    if (items is! List) return const [];
    return items.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<void> adminCreateClass({
    required String user,
    required String pass,
    required String session,
    required String klass,
    required String stream,
  }) async {
    final res = await _client
        .post(
          _adminUri('/admin/classes'),
          headers: {
            'content-type': 'application/json',
            'authorization': _basicAuth(user, pass),
          },
          body: jsonEncode({
            'session': session.trim(),
            'class': klass.trim(),
            'stream': stream.trim(),
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
  }

  Future<void> adminDeleteClass({required String user, required String pass, required String id}) async {
    final res = await _client
        .delete(
          _adminUri('/admin/classes/$id'),
          headers: {
            'authorization': _basicAuth(user, pass),
          },
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
  }

  Future<List<Map<String, dynamic>>> adminGetStudents({required String user, required String pass}) async {
    final res = await _client
        .get(
          _adminUri('/admin/students'),
          headers: {
            'authorization': _basicAuth(user, pass),
          },
        )
        .timeout(const Duration(seconds: 20));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body);
    final items = (data is Map<String, dynamic>) ? data['items'] : null;
    if (items is! List) return const [];
    return items.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<void> adminPatchStudent({
    required String user,
    required String pass,
    required String id,
    required Map<String, dynamic> payload,
  }) async {
    final res = await _client
        .patch(
          _adminUri('/admin/students/$id'),
          headers: {
            'content-type': 'application/json',
            'authorization': _basicAuth(user, pass),
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
  }

  Future<void> adminDeleteStudent({required String user, required String pass, required String id}) async {
    final res = await _client
        .delete(
          _adminUri('/admin/students/$id'),
          headers: {
            'authorization': _basicAuth(user, pass),
          },
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
  }

  Future<List<Map<String, dynamic>>> adminGetMaterials({required String user, required String pass}) async {
    final res = await _client
        .get(
          _adminUri('/admin/materials'),
          headers: {
            'authorization': _basicAuth(user, pass),
          },
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body);
    final items = (data is Map<String, dynamic>) ? data['items'] : null;
    if (items is! List) return const [];
    return items.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<void> adminDeleteMaterial({required String user, required String pass, required String id}) async {
    final res = await _client
        .delete(
          _adminUri('/admin/materials/$id'),
          headers: {
            'authorization': _basicAuth(user, pass),
          },
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
  }

  Future<List<Map<String, dynamic>>> adminGetTimetables({required String user, required String pass}) async {
    final res = await _client
        .get(
          _adminUri('/admin/timetables'),
          headers: {
            'authorization': _basicAuth(user, pass),
          },
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body);
    final items = (data is Map<String, dynamic>) ? data['items'] : null;
    if (items is! List) return const [];
    return items.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<void> adminDeleteTimetable({required String user, required String pass, required String id}) async {
    final res = await _client
        .delete(
          _adminUri('/admin/timetables/$id'),
          headers: {
            'authorization': _basicAuth(user, pass),
          },
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
  }

  Future<Map<String, dynamic>> adminStartResumableUpload({
    required String user,
    required String pass,
    required String startPath,
    required String fileName,
    required String mimeType,
    required int size,
  }) async {
    final res = await _client
        .post(
          _adminUri(startPath),
          headers: {
            'content-type': 'application/json',
            'authorization': _basicAuth(user, pass),
          },
          body: jsonEncode({
            'fileName': fileName,
            'mimeType': mimeType,
            'size': size,
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body);
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    return const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> adminUploadResumableChunk({
    required String user,
    required String pass,
    required String chunkPath,
    required String uploadUrl,
    required List<int> bytes,
    required int start,
    required int endExclusive,
    required int total,
  }) async {
    final res = await _client
        .put(
          _adminUri(chunkPath),
          headers: {
            'authorization': _basicAuth(user, pass),
            'content-type': 'application/octet-stream',
            'content-length': bytes.length.toString(),
            'content-range': 'bytes $start-${endExclusive - 1}/$total',
            'x-upload-url': uploadUrl,
          },
          body: bytes,
        )
        .timeout(const Duration(seconds: 60));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body);
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    return const <String, dynamic>{};
  }

  Future<Map<String, dynamic>> adminFinalizeResumableUpload({
    required String user,
    required String pass,
    required String finalizePath,
    required Map<String, dynamic> payload,
  }) async {
    final res = await _client
        .post(
          _adminUri(finalizePath),
          headers: {
            'content-type': 'application/json',
            'authorization': _basicAuth(user, pass),
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 60));

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode}: ${res.body}');
    }
    final data = jsonDecode(res.body);
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return data.cast<String, dynamic>();
    return const <String, dynamic>{};
  }
}
