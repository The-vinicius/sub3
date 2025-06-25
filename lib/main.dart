import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Subtitle Audio Player',
      theme: ThemeData(primarySwatch: Colors.blue),
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
  File? _srtFile;
  File? _mp3File;

  Future<void> _pickSrt() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['srt'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _srtFile = File(result.files.single.path!));
    }
  }

  Future<void> _pickMp3() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _mp3File = File(result.files.single.path!));
    }
  }

  void _openPlayer() {
    if (_srtFile != null && _mp3File != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) =>
                  SubtitlePlayerScreen(srtFile: _srtFile!, mp3File: _mp3File!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Files')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _pickSrt,
              child: Text(
                _srtFile == null
                    ? 'Pick Subtitle (.srt)'
                    : 'Subtitle: ${_srtFile!.path.split(Platform.pathSeparator).last}',
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _pickMp3,
              child: Text(
                _mp3File == null
                    ? 'Pick Audio (.mp3)'
                    : 'Audio: ${_mp3File!.path.split(Platform.pathSeparator).last}',
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed:
                  (_srtFile != null && _mp3File != null) ? _openPlayer : null,
              child: const Text('Play with Subtitles'),
            ),
          ],
        ),
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
  final File srtFile;
  final File mp3File;
  const SubtitlePlayerScreen({
    super.key,
    required this.srtFile,
    required this.mp3File,
  });
  @override
  State<SubtitlePlayerScreen> createState() => _SubtitlePlayerScreenState();
}

class _SubtitlePlayerScreenState extends State<SubtitlePlayerScreen> {
  late final AudioPlayer _audioPlayer;
  List<Subtitle> _subtitles = [];
  int _currentIndex = 0;
  bool _sync = false;
  StreamSubscription<Duration>? _posSub;
  final ItemScrollController _scrollController = ItemScrollController();
  final ItemPositionsListener _positionsListener =
      ItemPositionsListener.create();
  final ScrollController _scrollCtrl = ScrollController();
  bool _loaded = false;
  final double _itemHeight = 150.0;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _loadSubtitles();
    _audioPlayer.setFilePath(widget.mp3File.path).then((_) {
      _loaded = true;
      setState(() {});
    });
    _posSub = _audioPlayer.positionStream.listen((pos) {
      if (_sync) _updateSubtitle(pos);
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _audioPlayer.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _loadSubtitles() {
    final lines = widget.srtFile.readAsLinesSync();
    final regex = RegExp(
      r"(\d{2}:\d{2}:\d{2},\d{3}) --> (\d{2}:\d{2}:\d{2},\d{3})",
    );
    for (int i = 0; i < lines.length; i++) {
      final match = regex.firstMatch(lines[i]);
      if (match != null) {
        Duration parse(String s) {
          final parts = s.split(RegExp(r'[:,]')).map(int.parse).toList();
          return Duration(
            hours: parts[0],
            minutes: parts[1],
            seconds: parts[2],
            milliseconds: parts[3],
          );
        }

        final start = parse(match.group(1)!);
        final end = parse(match.group(2)!);
        i++;
        final text = StringBuffer();
        while (i < lines.length && lines[i].trim().isNotEmpty) {
          text.writeln(lines[i]);
          i++;
        }
        _subtitles.add(Subtitle(start, end, text.toString().trim()));
      }
    }
    setState(() {});
  }

  void _updateSubtitle(Duration pos) {
    for (var i = 0; i < _subtitles.length; i++) {
      if (pos >= _subtitles[i].start && pos <= _subtitles[i].end) {
        _currentIndex = i;
        final viewport = _scrollCtrl.position.viewportDimension;
        final targetOffset =
            (i * _itemHeight) - (viewport / 2) + (_itemHeight / 2);
        _scrollCtrl.animateTo(
          targetOffset.clamp(
            _scrollCtrl.position.minScrollExtent,
            _scrollCtrl.position.maxScrollExtent,
          ),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        );
        setState(() {});
        break;
      }
    }
  }

  Future<void> _togglePlay() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.pause();
    } else {
      if (_loaded) {
        await _audioPlayer.play();
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Player')),
      body: SafeArea(
        child: Column(
          children: [
            // Playback controls
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  // Progress bar
                  StreamBuilder<Duration>(
                    stream: _audioPlayer.positionStream,
                    builder: (context, snapshot) {
                      final pos = snapshot.data ?? Duration.zero;
                      final total = _audioPlayer.duration ?? Duration.zero;
                      return Column(
                        children: [
                          Slider(
                            min: 0,
                            max: total.inMilliseconds.toDouble(),
                            value:
                                pos.inMilliseconds
                                    .clamp(0, total.inMilliseconds)
                                    .toDouble(),
                            onChanged:
                                (value) => _audioPlayer.seek(
                                  Duration(milliseconds: value.toInt()),
                                ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatDuration(pos)),
                              Text(_formatDuration(total)),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.replay_10),
                        onPressed:
                            () => _audioPlayer.seek(
                              (_audioPlayer.position -
                                  const Duration(seconds: 10)),
                            ),
                      ),
                      IconButton(
                        icon: Icon(
                          _audioPlayer.playing
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                        ),
                        iconSize: 48,
                        onPressed: _togglePlay,
                      ),
                      IconButton(
                        icon: const Icon(Icons.forward_10),
                        onPressed:
                            () => _audioPlayer.seek(
                              (_audioPlayer.position +
                                  const Duration(seconds: 10)),
                            ),
                      ),
                      const SizedBox(width: 16),
                      Row(
                        children: [
                          const Text('Sync'),
                          Switch(
                            value: _sync,
                            onChanged: (v) => setState(() => _sync = v),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
            // Subtitle list
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                itemCount: _subtitles.length,
                itemBuilder: (context, index) {
                  final sub = _subtitles[index];
                  final selected = _sync && index == _currentIndex;
                  return Container(
                    height: _itemHeight,
                    color: selected ? Colors.yellow : null,
                    child: Center(
                      child: Text(
                        sub.text,
                        style: const TextStyle(fontSize: 18),
                      ),
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

  String _formatDuration(Duration d) {
    final two = (int n) => n.toString().padLeft(2, '0');
    final minutes = two(d.inMinutes.remainder(60));
    final seconds = two(d.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}
