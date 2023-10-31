import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:lex/utils/http.dart';
import 'package:lex/modules/cms/models/course.dart';
import 'package:lex/modules/cms/models/forum.dart';
import 'package:lex/modules/cms/models/profile.dart';
import 'package:lex/modules/cms/models/search_result.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

@immutable
class CMSClient {
  const CMSClient(this.token);

  final _baseUrl =
      "https://cms.bits-hyderabad.ac.in/webservice/rest/server.php";
  final String token;

  Future<CMSUser> fetchUserDetail() async {
    final response = await dio.get(
      _baseUrl,
      queryParameters: {
        'wsfunction': 'core_webservice_get_site_info',
        'moodlewsrestformat': 'json',
        'wstoken': token,
      },
    );

    return CMSUser.fromJson(response.data);
  }

  Future<List<CMSRegisteredCourse>> fetchCourses(int userId) async {
    final response = await dio.get(
      _baseUrl,
      queryParameters: {
        'wsfunction': 'core_enrol_get_users_courses',
        'moodlewsrestformat': 'json',
        'wstoken': token,
        'userid': userId,
      },
    );

    final courses = response.data as List<dynamic>;

    return courses
        .map((course) => CMSRegisteredCourse.fromJson(course))
        .toList(growable: false);
  }

  Future<List<CMSCourseContent>> fetchCourseContent(int courseId) async {
    final response = await dio.get(
      _baseUrl,
      queryParameters: {
        'wsfunction': 'core_course_get_contents',
        'moodlewsrestformat': 'json',
        'wstoken': token,
        'courseid': courseId,
      },
    );
    final sections = response.data as List<dynamic>;
    return sections
        .map((section) => CMSCourseContent.fromJson(section))
        .toList(growable: false);
  }

  Future<List<CMSForumDiscussion>> fetchForum(int forumId) async {
    final response = await dio.get(
      _baseUrl,
      queryParameters: {
        'wsfunction': 'mod_forum_get_forum_discussions',
        'moodlewsrestformat': 'json',
        'wstoken': token,
        'forumid': forumId,
      },
    );

    final discussions = response.data['discussions'] as List<dynamic>;

    return discussions
        .map((discussion) => CMSForumDiscussion.fromJson(discussion))
        .toList(growable: false);
  }

  Future<List<CMSSearchResult>> searchCourses(String searchFor) async {
    final response = await dio.get(
      _baseUrl,
      queryParameters: {
        'wsfunction': 'core_course_search_courses',
        'moodlewsrestformat': 'json',
        'wstoken': token,
        'criterianame': 'search',
        'page': 0,
        'perpage': 15,
        'criteriavalue': searchFor,
      },
    );
    final courses = response.data['courses'] as List<dynamic>;
    return courses
        .map((course) => CMSSearchResult.fromJson(course))
        .toList(growable: false);
  }

  Future<bool> courseEnroll(int courseId) async {
    final response = await dio.post(
      _baseUrl,
      queryParameters: {
        'wsfunction': 'enrol_self_enrol_user',
        'moodlewsrestformat': 'json',
        'wstoken': token,
        'courseid': courseId,
      },
    );
    return response.data['status'] as bool;
  }

  Future<bool> download(CMSCourseFile file) async {
    if (kIsWeb) {
      final fileUri = Uri.parse(file.fileurl);
      return await launchUrl(
        fileUri.replace(queryParameters: {"token": token}),
      );
    }

    final response = await dio.download(
      file.fileurl,
      p.join(
        (await getApplicationSupportDirectory()).path,
        "cms",
        file.filename,
      ),
      queryParameters: {'token': token},
    );
    return response.statusCode == 200;
  }

  Future<String> registerUserDevice() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    final deviceInfo = await deviceInfoPlugin.deviceInfo;
    final deviceData = deviceInfo.data;

    String fcmToken = await FirebaseMessaging.instance.getToken() ?? "";

    String platform;
    if (kIsWeb) {
      platform = "web";
    } else {
      if (Platform.isAndroid) {
        platform = 'android';
      } else if (Platform.isIOS) {
        platform = 'ios';
      } else if (Platform.isLinux) {
        platform = 'linux';
      } else if (Platform.isWindows) {
        platform = 'windows';
      } else if (Platform.isMacOS) {
        platform = 'cringe';
      } else {
        platform = 'undefined';
      }
    }

    final response = await dio.get(
      _baseUrl,
      queryParameters: {
        'wsfunction': 'core_user_add_user_device',
        'moodlewsrestformat': 'json',
        'wstoken': token,
        'appid': "com.thecomputerm.lex",
        'name': deviceData['product'],
        'model': deviceData['model'],
        'platform': platform,
        'version': '', //deviceData['version']
        'pushid': fcmToken,
        'uuid': deviceData['id'],
      },
    );

    if (response.data.toString() == "[]") {
      return "Registered for notifications successfully!";
    } else {
      return response.data[0][0]["message"].toString();
    }
  }

  Future<String> unregisterUserDevice() async {
    final deviceInfoPlugin = DeviceInfoPlugin();
    final deviceInfo = await deviceInfoPlugin.deviceInfo;
    final deviceData = deviceInfo.data;

    final response = await dio.get(
      _baseUrl,
      queryParameters: {
        'wsfunction': 'core_user_remove_user_device',
        'moodlewsrestformat': 'json',
        'wstoken': token,
        'appid': "com.thecomputerm.lex",
        'uuid': deviceData['id'],
      },
    );

    if (response.data["removed"] == true) {
      return "You won't be receiving notifications anymore";
    } else {
      return response.data["warnings"][0]["message"].toString();
    }
  }
}
