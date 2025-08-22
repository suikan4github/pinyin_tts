import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'generate_source_hanzi_list.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pinyin TTS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Pinyin TTS'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class HanziItem {
  final String simplified;
  final String pinyinWithTone;

  HanziItem({required this.simplified, required this.pinyinWithTone});
}

class _MyHomePageState extends State<MyHomePage> {
  late FlutterTts flutterTts;
  late ScrollController scrollController;
  List<HanziItem> hanziList = [];
  int currentIndex = 0;
  bool isPlaying = false;
  bool isPaused = false;

  @override
  void initState() {
    super.initState();
    scrollController = ScrollController();
    initTts();
    loadHanziList();
  }

  initTts() {
    flutterTts = FlutterTts();
    flutterTts.setLanguage("zh-CN");
    flutterTts.setSpeechRate(0.5);
    flutterTts.setVolume(1.0);
    flutterTts.setPitch(1.0);

    flutterTts.setCompletionHandler(() {
      if (isPlaying && !isPaused) {
        Future.delayed(const Duration(seconds: 1), () {
          if (isPlaying && !isPaused) {
            moveToNext();
          }
        });
      }
    });
  }

  loadHanziList() {
    final sourceList = generateSourceHanziList();
    hanziList = sourceList
        .map(
          (hanzi) => HanziItem(
            simplified: hanzi.simplified,
            pinyinWithTone: hanzi.pinyinWithTone,
          ),
        )
        .toList();
    setState(() {});
  }

  Future<void> speak(String text) async {
    await flutterTts.speak(text);
  }

  void startPlaying() {
    setState(() {
      isPlaying = true;
      isPaused = false;
    });
    if (hanziList.isNotEmpty) {
      speak(hanziList[currentIndex].simplified);
    }
  }

  void pausePlaying() {
    setState(() {
      isPaused = true;
    });
    flutterTts.stop();
  }

  void moveToNext() {
    if (currentIndex < hanziList.length - 1) {
      setState(() {
        currentIndex++;
      });
      scrollToCurrentItem();
      if (isPlaying && !isPaused) {
        speak(hanziList[currentIndex].simplified);
      }
    } else {
      // 最後に到達したら停止
      setState(() {
        isPlaying = false;
        isPaused = false;
      });
    }
  }

  void scrollToCurrentItem() {
    if (scrollController.hasClients) {
      // ListTileの高さを約72pxと想定してスクロール位置を計算
      const itemHeight = 72.0;
      final targetOffset = currentIndex * itemHeight;
      
      scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void onItemTapped(int index) {
    setState(() {
      currentIndex = index;
    });
    scrollToCurrentItem();
    speak(hanziList[index].simplified);
  }

  @override
  void dispose() {
    flutterTts.stop();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
        actions: [
          IconButton(
            onPressed: isPlaying && !isPaused ? pausePlaying : startPlaying,
            icon: Icon(isPlaying && !isPaused ? Icons.pause : Icons.play_arrow),
          ),
        ],
      ),
      body: hanziList.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              controller: scrollController,
              itemCount: hanziList.length,
              itemBuilder: (context, index) {
                final item = hanziList[index];
                final isSelected = index == currentIndex;

                return ListTile(
                  selected: isSelected,
                  selectedTileColor: Colors.blue.withOpacity(0.3),
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(
                    item.simplified,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    item.pinyinWithTone,
                    style: TextStyle(
                      fontSize: 16,
                      color: isSelected ? Colors.blue[700] : Colors.grey[600],
                    ),
                  ),
                  onTap: () => onItemTapped(index),
                );
              },
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "start",
            onPressed: startPlaying,
            tooltip: 'Start',
            child: const Icon(Icons.play_arrow),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "pause",
            onPressed: pausePlaying,
            tooltip: 'Pause',
            child: const Icon(Icons.pause),
          ),
        ],
      ),
    );
  }
}
