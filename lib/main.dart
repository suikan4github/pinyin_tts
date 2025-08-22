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
      title: 'Pinyin TTS Checker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Pinyin TTS Checker'),
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
    if (currentIndex < 0 || currentIndex >= hanziList.length) return;
    
    if (scrollController.hasClients) {
      // より正確な計算のために、実際のListViewの寸法を使用
      final viewportHeight = scrollController.position.viewportDimension;
      final maxOffset = scrollController.position.maxScrollExtent;
      final minOffset = scrollController.position.minScrollExtent;
      
      // 全体のスクロール可能範囲をアイテム数で割って平均的なアイテム高さを算出
      final totalScrollableHeight = maxOffset + viewportHeight;
      final averageItemHeight = totalScrollableHeight / hanziList.length;
      
      // ターゲット位置を計算
      final targetOffset = currentIndex * averageItemHeight;
      
      // ターゲットアイテムを画面の中央に配置
      final centeredOffset = targetOffset - (viewportHeight / 2) + (averageItemHeight / 2);
      final adjustedOffset = centeredOffset.clamp(minOffset, maxOffset);
      
      scrollController.animateTo(
        adjustedOffset,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  void onItemTapped(int index) {
    setState(() {
      currentIndex = index;
    });
    
    // ウィジェットの更新が完了した後にスクロールを実行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollToCurrentItem();
    });
    
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

      // フォーカス位置を別ファイルに保存
      await saveFocusPosition();

      // 最後に保存されたファイルパスを更新
      setState(() {
        lastSavedFilePath = file.path;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$fileName を保存しました (${markedCharacters.length}文字)\nフォーカス位置: ${currentIndex + 1}\nパス: ${file.path}',
            ),
            action: SnackBarAction(
              label: 'シェア',
              onPressed: () => shareFile(file.path),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
        );
      }
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  Future<void> saveFocusPosition() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      const fileName = 'pinyin_focus_position.txt';
      final file = File('${directory.path}/$fileName');
      
      // フォーカス位置を1-basedで保存
      await file.writeAsString('${currentIndex + 1}');
    } catch (e) {
      // フォーカス位置の保存エラーは無視（メイン機能に影響させない）
      // エラーログは本番環境では出力しない
    }
  }

  Future<void> shareFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        // ファイル内容を読み取って文字列として共有
        final content = await file.readAsString();
        await SharePlus.instance.share(
          ShareParams(text: content),
        );
      } else {
        throw Exception('ファイルが見つかりません');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ファイル共有に失敗しました: $e')),
        );
      }
    }
  }

  Future<void> restoreMarkedItemsFromFile() async {
    try {
      setState(() {
        isSaving = true; // ローディング表示に使用
      });

      final directory = await getApplicationDocumentsDirectory();
      const fileName = 'pinyin_marked_characters.txt';
      final file = File('${directory.path}/$fileName');

      // デバッグ情報: ディレクトリ内のファイル一覧を表示
      final directoryContents = await directory.list().toList();
      final fileNames = directoryContents
          .whereType<File>()
          .map((entity) => entity.path.split('/').last)
          .toList();

      if (!await file.exists()) {
        throw Exception(
          '保存されたファイルが見つかりません\n'
          'ファイルパス: ${file.path}\n'
          'ディレクトリ内のファイル: ${fileNames.join(", ")}\n'
          'まず保存してから復元を試してください。',
        );
      }

      final content = await file.readAsString();
      final savedCharacters = content
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();

      // 現在のリストから該当する漢字を探してマーク
      final newMarkedItems = <int>{};
      for (int i = 0; i < hanziList.length; i++) {
        if (savedCharacters.contains(hanziList[i].simplified)) {
          newMarkedItems.add(i);
        }
      }

      setState(() {
        markedItems = newMarkedItems;
      });

      // フォーカス位置を復元
      await restoreFocusPosition();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'マークを復元しました (${newMarkedItems.length}個)\n元ファイル: ${savedCharacters.length}文字\nフォーカス位置: ${currentIndex + 1}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('復元に失敗しました: $e'),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      setState(() {
        isSaving = false;
      });
    }
  }

  Future<void> restoreFocusPosition() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      const fileName = 'pinyin_focus_position.txt';
      final file = File('${directory.path}/$fileName');
      
      if (await file.exists()) {
        final content = await file.readAsString();
        final position = int.tryParse(content.trim());
        
        if (position != null && position >= 1 && position <= hanziList.length) {
          final index = position - 1; // 1-based to 0-based
          setState(() {
            currentIndex = index;
          });
          
          // フォーカス位置を復元後にスクロール
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Future.delayed(const Duration(milliseconds: 100), () {
              scrollToCurrentItem();
            });
          });
        }
      }
    } catch (e) {
      // フォーカス位置の復元エラーは無視（メイン機能に影響させない）
      // エラーはログに記録されるが、print文はリリースビルドでは避ける
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
    
    // ウィジェットの更新が完了した後にスクロールを実行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollToCurrentItem();
    });
    
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
    
    // ウィジェットの更新が完了した後にスクロールを実行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollToCurrentItem();
    });
    
    speak(hanziList[currentIndex].simplified);
  }

  Future<void> showJumpToNumberDialog() async {
    final TextEditingController controller = TextEditingController();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('番号を指定してジャンプ'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('移動先の番号を入力してください (1-${hanziList.length})'),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '番号',
                    border: OutlineInputBorder(),
                    hintText: '例: 100',
                  ),
                  autofocus: true,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('キャンセル'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('ジャンプ'),
              onPressed: () {
                final input = controller.text.trim();
                if (input.isNotEmpty) {
                  final number = int.tryParse(input);
                  if (number != null &&
                      number >= 1 &&
                      number <= hanziList.length) {
                    jumpToNumber(number);
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '無効な番号です。1から${hanziList.length}の間で入力してください。',
                        ),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  void jumpToNumber(int number) {
    final index = number - 1; // 1-based to 0-based index
    setState(() {
      currentIndex = index;
    });
    
    // ウィジェットの更新が完了した後にスクロールを実行
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 少し遅延を入れてより確実にスクロール
      Future.delayed(const Duration(milliseconds: 100), () {
        scrollToCurrentItem();
      });
    });
    
    speak(hanziList[currentIndex].simplified);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$number番目のアイテムにジャンプしました (インデックス: $index)'),
        duration: const Duration(seconds: 2),
      ),
    );
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
                  selectedTileColor: Colors.blue.withValues(alpha: 0.3),
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
            heroTag: "restore",
            onPressed: isSaving ? null : restoreMarkedItemsFromFile,
            tooltip: 'Restore Marked Items',
            backgroundColor: isSaving ? Colors.grey : Colors.blue,
            child: const Icon(Icons.restore),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "jump",
            onPressed: showJumpToNumberDialog,
            tooltip: 'Jump to Number',
            backgroundColor: Colors.deepPurple,
            child: const Icon(Icons.tag),
          ),
        ],
      ),
    );
  }
}
