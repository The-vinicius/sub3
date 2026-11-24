import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sub3/app/models/sub.dart';
import 'package:sub3/app/ui/subtitle_player_screen.dart';
import 'package:sub3/app/ui/widgets/card_sub.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sub3/app/services/database_service.dart';
import 'package:sub3/app/services/gguf_model_service.dart';
import 'package:sub3/app/ui/widgets/offline_model_banner.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Subtitle Audio Player',
      theme: ThemeData.dark(),
      home: const FileSelectorScreen(),
    );
  }
}

class FileSelectorScreen extends StatefulWidget {
  const FileSelectorScreen({super.key});
  @override
  State<FileSelectorScreen> createState() => _FileSelectorScreenState();
}

class _FileSelectorScreenState extends State<FileSelectorScreen> {
  File? subtitleFile;
  File? audioFile;
  List<Sub> subs = [];
  final DatabaseService _databaseService = DatabaseService.instance;

  @override
  void initState() {
    super.initState();
    _loadSubsFromDatabase();
    GgufModelService.instance.refresh();
  }

  // Load subs from database
  Future<void> _loadSubsFromDatabase() async {
    try {
      final loadedSubs = await _databaseService.getAllSubs();
      if (!mounted) return;
      setState(() {
        subs = loadedSubs;
      });
    } catch (_) {
      // Ignore database loading error on initial load
    }
  }

  // Save sub to database
  Future<bool> _saveSubToDatabase(Sub sub) async {
    try {
      await _databaseService.saveSub(sub);
      await _loadSubsFromDatabase(); // Reload the list
      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Subtitle "${sub.name}" saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving subtitle: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  // Delete sub from database
  Future<void> _deleteSubFromDatabase(int id) async {
    try {
      await _databaseService.deleteSub(id);
      await _loadSubsFromDatabase(); // Reload the list
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subtitle deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting subtitle: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String> getPath(String name) async {
    final appDoc = await getApplicationDocumentsDirectory();
    final dest = File('${appDoc.path}/$name');
    return dest.path;
  }

  Future<void> pickSubtitle() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        final path = await getPath(result.files.single.name);
        final ext = path.split('.').last.toLowerCase();
        if (['srt', 'vtt'].contains(ext)) {
          await File(result.files.single.path!).copy(path);
          if (!mounted) return;
          setState(() => subtitleFile = File(path));
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a .srt or .vtt file')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to open file picker: ${e.toString().replaceAll("Exception: ", "")}',
          ),
        ),
      );
    }
  }

  Future<void> pickAudio() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.audio);
      if (result != null && result.files.single.path != null) {
        if (!mounted) return;
        setState(() => audioFile = File(result.files.single.path!));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to open file picker: ${e.toString().replaceAll("Exception: ", "")}',
          ),
        ),
      );
    }
  }

  void openPlayer(Sub sub) {
    if (sub.subPath1.existsSync() && sub.mp3Path.existsSync()) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => SubtitlePlayerScreen(
                subtitleFile: sub.subPath1,
                audioFile: sub.mp3Path,
              ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('One or both files no longer exist')),
      );
    }
  }

  void subModal() {
    String subtitleName = '';
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Subtitle Info'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'Subtitle Name'),
                  onChanged: (value) {
                    subtitleName = value;
                  },
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: pickSubtitle,
                  child: Text(
                    subtitleFile == null
                        ? 'Pick Subtitle (.srt/.vtt)'
                        : 'Subtitle: ${subtitleFile!.path.split(Platform.pathSeparator).last}',
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: pickAudio,
                  child: Text(
                    audioFile == null
                        ? 'Pick Audio'
                        : 'Audio: ${audioFile!.path.split(Platform.pathSeparator).last}',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  if (subtitleFile != null && audioFile != null) {
                    final newSub = Sub(subtitleName, subtitleFile!, audioFile!);
                    final ok = await _saveSubToDatabase(newSub);
                    if (context.mounted && ok) {
                      Navigator.of(context).pop();
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Please select both subtitle and audio files',
                        ),
                      ),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Files')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const OfflineModelBanner(),
            Expanded(
              child: ListView.builder(
                itemCount: subs.length,
                itemBuilder: (context, index) {
                  final sub = subs[index];
                  return CardSub(
                    sub: sub,
                    onTap: openPlayer,
                    onDelete: (subToDelete) {
                      if (subToDelete.id != null) {
                        _deleteSubFromDatabase(subToDelete.id!);
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: subModal,
        child: const Icon(Icons.add),
      ),
    );
  }
}
