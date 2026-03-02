import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pdf_file_model.dart';

class AppProvider extends ChangeNotifier {
  static const String _filesKey = 'pdf_files';
  static const String _proKey = 'is_pro';
  static const String _darkModeKey = 'dark_mode';

  bool _isPro = false;
  bool _isDarkMode = true;
  List<PdfFileModel> _files = [];
  bool _isLoading = false;

  bool get isPro => _isPro;
  bool get isDarkMode => _isDarkMode;
  List<PdfFileModel> get files => List.unmodifiable(_files);
  bool get isLoading => _isLoading;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isPro = prefs.getBool(_proKey) ?? false;
    _isDarkMode = prefs.getBool(_darkModeKey) ?? true;
    await _loadFiles(prefs);
    notifyListeners();
  }

  Future<void> _loadFiles(SharedPreferences prefs) async {
    final raw = prefs.getStringList(_filesKey) ?? [];
    _files =
        raw
            .map((s) {
              try {
                return PdfFileModel.fromJson(
                  jsonDecode(s) as Map<String, dynamic>,
                );
              } catch (_) {
                return null;
              }
            })
            .whereType<PdfFileModel>()
            .where((f) => File(f.path).existsSync())
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> _saveFiles() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _filesKey,
      _files.map((f) => jsonEncode(f.toJson())).toList(),
    );
  }

  Future<void> addFile(PdfFileModel file) async {
    _files.insert(0, file);
    await _saveFiles();
    notifyListeners();
  }

  Future<void> deleteFile(String id) async {
    final file = _files.firstWhere(
      (f) => f.id == id,
      orElse: () => throw Exception('Not found'),
    );
    try {
      final f = File(file.path);
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
    _files.removeWhere((f) => f.id == id);
    await _saveFiles();
    notifyListeners();
  }

  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, _isDarkMode);
    notifyListeners();
  }

  Future<void> unlockPro() async {
    _isPro = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_proKey, true);
    notifyListeners();
  }

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Refresh file list (remove deleted files).
  Future<void> refresh() async {
    _files = _files.where((f) => File(f.path).existsSync()).toList();
    await _saveFiles();
    notifyListeners();
  }
}
