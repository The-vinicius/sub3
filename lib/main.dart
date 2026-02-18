import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:sub3/app/models/sub.dart';
import 'package:sub3/app/ui/widgets/card_sub.dart';
import 'package:sub3/app/services/database_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  }

  // Load subs from database
  Future<void> _loadSubsFromDatabase() async {
    try {
      final loadedSubs = await _databaseService.getAllSubs();
      setState(() {
        subs = loadedSubs;
      });
    } catch (e) {}
  }

  // Save sub to database
  Future<void> _saveSubToDatabase(Sub sub) async {
    try {
      await _databaseService.saveSub(sub);
      await _loadSubsFromDatabase(); // Reload the list
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Subtitle "${sub.name}" saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving subtitle: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Delete sub from database
  Future<void> _deleteSubFromDatabase(int id) async {
    try {
      await _databaseService.deleteSub(id);
      await _loadSubsFromDatabase(); // Reload the list
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Subtitle deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      final path = await getPath(result.files.single.name);
      final ext = path.split('.').last.toLowerCase();
      if (['srt', 'vtt'].contains(ext)) {
        await File(result.files.single.path!).copy(path);
        setState(() => subtitleFile = File(path));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a .srt or .vtt file')),
        );
      }
    }
  }

  Future<void> pickAudio() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null) {
      final path = await getPath(result.files.single.name);
      await File(result.files.single.path!).copy(path);
      setState(() => audioFile = File(path));
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
                    await _saveSubToDatabase(newSub);
                    if (context.mounted) {
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
      floatingActionButton: FloatingActionButton(
        onPressed: subModal,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class Subtitle {
  final Duration start;
  final Duration end;
  final String text;
  Subtitle(this.start, this.end, this.text);
}

class SubtitlePlayerScreen extends StatefulWidget {
  final File subtitleFile;
  final File audioFile;
  const SubtitlePlayerScreen({
    super.key,
    required this.subtitleFile,
    required this.audioFile,
  });
  @override
  State<SubtitlePlayerScreen> createState() => _SubtitlePlayerScreenState();
}

class _SubtitlePlayerScreenState extends State<SubtitlePlayerScreen> {
  final AudioPlayer player = AudioPlayer();
  late StreamSubscription<Duration> posSub;
  late StreamSubscription<PlayerState> stateSub;

  final List<Subtitle> subtitles = [];
  final ItemScrollController scrollCtrl = ItemScrollController();

  Duration duration = Duration.zero;
  Duration position = Duration.zero;
  PlayerState playerState = PlayerState.completed;
  int currentIndex = 0;
  bool sync = true;

  @override
  void initState() {
    super.initState();
    _loadSubtitles();
    player.setSource(DeviceFileSource(widget.audioFile.path)).then((_) async {
      duration = await player.getDuration() ?? Duration.zero;
      setState(() {});
    });
    posSub = player.onPositionChanged.listen((p) {
      position = p;
      if (sync) _updateSubtitle(p);
      setState(() {});
    });
    stateSub = player.onPlayerStateChanged.listen((s) {
      playerState = s;
      setState(() {});
    });
  }

  @override
  void dispose() {
    posSub.cancel();
    stateSub.cancel();
    player.dispose();
    super.dispose();
  }

  void _loadSubtitles() {
    final lines = widget.subtitleFile.readAsLinesSync();
    final regex = RegExp(
      r"(\d{2}:\d{2}:\d{2}[,\.]\d{3}) --> (\d{2}:\d{2}:\d{2}[,\.]\d{3})",
    );
    for (int i = 0; i < lines.length; i++) {
      final m = regex.firstMatch(lines[i]);
      if (m != null) {
        Duration parse(String s) {
          final parts = s.split(RegExp(r'[\,:\.]')).map(int.parse).toList();
          return Duration(
            hours: parts[0],
            minutes: parts[1],
            seconds: parts[2],
            milliseconds: parts[3],
          );
        }

        final start = parse(m.group(1)!);
        final end = parse(m.group(2)!);
        i++;
        final buf = StringBuffer();
        while (i < lines.length && lines[i].trim().isNotEmpty) {
          buf.writeln(lines[i]);
          i++;
        }
        subtitles.add(Subtitle(start, end, buf.toString().trim()));
      }
    }
    setState(() {});
  }

  void _updateSubtitle(Duration p) {
    for (int i = 0; i < subtitles.length; i++) {
      if (p >= subtitles[i].start && p <= subtitles[i].end) {
        if (currentIndex != i) {
          currentIndex = i;
          scrollCtrl.scrollTo(
            index: i,
            duration: const Duration(milliseconds: 200),
            alignment: 0.5,
          );
        }
        break;
      }
    }
  }

  void _togglePlay() {
    if (playerState == PlayerState.playing) {
      player.pause();
    } else {
      player.resume();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Player')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Slider(
                    min: 0,
                    max: duration.inMilliseconds.toDouble(),
                    value:
                        position.inMilliseconds
                            .clamp(0, duration.inMilliseconds)
                            .toDouble(),
                    onChanged:
                        (v) => player.seek(Duration(milliseconds: v.toInt())),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [Text(_fmt(position)), Text(_fmt(duration))],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.replay_10),
                        onPressed:
                            () => player.seek(
                              position - const Duration(seconds: 10),
                            ),
                      ),
                      IconButton(
                        iconSize: 48,
                        icon: Icon(
                          playerState == PlayerState.playing
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                        ),
                        onPressed: _togglePlay,
                      ),
                      IconButton(
                        icon: const Icon(Icons.forward_10),
                        onPressed:
                            () => player.seek(
                              position + const Duration(seconds: 10),
                            ),
                      ),
                      const SizedBox(width: 16),
                      Row(
                        children: [
                          const Text('Sync'),
                          Switch(
                            value: sync,
                            onChanged: (v) => setState(() => sync = v),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: ScrollablePositionedList.builder(
                itemCount: subtitles.length,
                itemScrollController: scrollCtrl,
                itemBuilder: (context, index) {
                  final s = subtitles[index];
                  final hl = (sync && index == currentIndex);
                  return Container(
                    padding: const EdgeInsets.all(8),
                    color: hl ? ColorScheme.of(context).primaryContainer : null,
                    child: Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            '${index + 1}\n${s.text}',
                            style: TextStyle(fontSize: hl ? 25 : 18),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            player.seek(s.start);
                            player.resume();
                          },
                          icon: Icon(Icons.play_circle_filled),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }
}
