import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
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
  List<GlobalKey> itemKeys = [];
  Set<int> markedItems = {};
  int currentIndex = 0;
  bool isPlaying = false;
  bool isPaused = false;
  bool isSaving = false;
  String? lastSavedFilePath;

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
    
    // 各アイテムにGlobalKeyを生成
    itemKeys = List.generate(hanziList.length, (index) => GlobalKey());
    
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
    if (currentIndex < itemKeys.length &&
        itemKeys[currentIndex].currentContext != null) {
      Scrollable.ensureVisible(
        itemKeys[currentIndex].currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.5, // 画面中央に配置
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

  void toggleMark() {
    setState(() {
      if (markedItems.contains(currentIndex)) {
        markedItems.remove(currentIndex);
      } else {
        markedItems.add(currentIndex);
      }
    });
  }

  Future<void> saveMarkedItemsToFile() async {
    if (markedItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('マークされたアイテムがありません')));
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      // アプリのドキュメントディレクトリを取得
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'pinyin_marked_characters.txt';
      final file = File('${directory.path}/$fileName');

      // マークされたアイテムの簡体字文字を収集
      final markedCharacters = <String>[];
      final sortedMarkedItems = markedItems.toList()..sort();
      for (int index in sortedMarkedItems) {
        if (index < hanziList.length) {
          markedCharacters.add(hanziList[index].simplified);
        }
      }

      // ファイル内容を作成
      final fileContent = markedCharacters.join('\n');

      // ファイルに保存
      await file.writeAsString(fileContent);

      // 最後に保存されたファイルパスを更新
      setState(() {
        lastSavedFilePath = file.path;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$fileName を保存しました (${markedCharacters.length}文字)\nパス: ${file.path}',
          ),
          action: SnackBarAction(
            label: 'シェア',
            onPressed: () => shareFile(file.path),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  Future<void> shareFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await Share.shareXFiles(
          [XFile(filePath)],
          text: 'マークされた漢字のリスト',
          subject: 'Pinyin TTS - マークされた漢字',
        );
      } else {
        throw Exception('ファイルが見つかりません');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ファイル共有に失敗しました: $e')),
      );
    }
  }

  void goToNextMarkedItem() {
    if (markedItems.isEmpty) return;

    final sortedMarkedItems = markedItems.toList()..sort();
    int? nextIndex;

    for (int markedIndex in sortedMarkedItems) {
      if (markedIndex > currentIndex) {
        nextIndex = markedIndex;
        break;
      }
    }

    // 現在位置より後にマークされたアイテムがない場合、最初のマークされたアイテムに移動
    nextIndex ??= sortedMarkedItems.first;

    setState(() {
      currentIndex = nextIndex!;
    });
    scrollToCurrentItem();
    speak(hanziList[currentIndex].simplified);
  }

  void goToPreviousMarkedItem() {
    if (markedItems.isEmpty) return;

    final sortedMarkedItems = markedItems.toList()..sort();
    int? previousIndex;

    for (int markedIndex in sortedMarkedItems.reversed) {
      if (markedIndex < currentIndex) {
        previousIndex = markedIndex;
        break;
      }
    }

    // 現在位置より前にマークされたアイテムがない場合、最後のマークされたアイテムに移動
    previousIndex ??= sortedMarkedItems.last;

    setState(() {
      currentIndex = previousIndex!;
    });
    scrollToCurrentItem();
    speak(hanziList[currentIndex].simplified);
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
            onPressed: isSaving ? null : saveMarkedItemsToFile,
            icon: isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            tooltip: 'Save Marked Items',
          ),
          IconButton(
            onPressed: lastSavedFilePath != null
                ? () => shareFile(lastSavedFilePath!)
                : null,
            icon: const Icon(Icons.share),
            tooltip: 'Share Last Saved File',
          ),
          IconButton(
            onPressed: markedItems.isEmpty ? null : goToPreviousMarkedItem,
            icon: const Icon(Icons.skip_previous),
            tooltip: 'Previous Marked Item',
          ),
          IconButton(
            onPressed: markedItems.isEmpty ? null : goToNextMarkedItem,
            icon: const Icon(Icons.skip_next),
            tooltip: 'Next Marked Item',
          ),
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
                final isMarked = markedItems.contains(index);

                return ListTile(
                  key: itemKeys[index],
                  selected: isSelected,
                  selectedTileColor: Colors.blue.withOpacity(0.3),
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          item.pinyinWithTone,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (isMarked)
                        const Icon(Icons.star, color: Colors.orange, size: 24),
                      if (!isMarked)
                        const SizedBox(width: 24), // マークがない場合の空白スペース
                      const Expanded(flex: 1, child: SizedBox()), // 右側のスペース
                    ],
                  ),
                  subtitle: Text(
                    item.simplified,
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
            heroTag: "save",
            onPressed: isSaving ? null : saveMarkedItemsToFile,
            tooltip: 'Save Marked Items',
            backgroundColor: isSaving ? Colors.grey : Colors.green,
            child: isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "share",
            onPressed: lastSavedFilePath != null
                ? () => shareFile(lastSavedFilePath!)
                : null,
            tooltip: 'Share Last Saved File',
            backgroundColor: lastSavedFilePath != null ? null : Colors.grey,
            child: const Icon(Icons.share),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "prev_marked",
            onPressed: markedItems.isEmpty ? null : goToPreviousMarkedItem,
            tooltip: 'Previous Marked Item',
            backgroundColor: markedItems.isEmpty ? Colors.grey : null,
            child: const Icon(Icons.skip_previous),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "next_marked",
            onPressed: markedItems.isEmpty ? null : goToNextMarkedItem,
            tooltip: 'Next Marked Item',
            backgroundColor: markedItems.isEmpty ? Colors.grey : null,
            child: const Icon(Icons.skip_next),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "mark",
            onPressed: toggleMark,
            tooltip: markedItems.contains(currentIndex) ? 'Unmark' : 'Mark',
            backgroundColor: markedItems.contains(currentIndex)
                ? Colors.orange
                : null,
            child: Icon(
              markedItems.contains(currentIndex)
                  ? Icons.star
                  : Icons.star_border,
            ),
          ),
          const SizedBox(height: 10),
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
