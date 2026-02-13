import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart';

import 'summary.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: ArticleView());
  }
}

//Modelを定義
class ArticleModel {
  Future<Summary> getRandomArticleSummary() async {
    final uri = Uri.https(
      'en.wikipedia.org',
      '/api/rest_v1/page/random/summary',
    );
    final response = await get(uri);

    // エラーチェック
    if (response.statusCode != 200) {
      throw HttpException('Failed to update resource');
    }

    // JSONを解析してSummaryオブジェクトを返す
    return Summary.fromJson(jsonDecode(response.body));
  }
}

//ViewModelを定義
class ArticleViewModel extends ChangeNotifier {
  final ArticleModel model;
  Summary? summary;
  String? errorMessage;
  bool loading = false;

  ArticleViewModel(this.model) {
    getRandomArticleSummary();
  }

  Future<void> getRandomArticleSummary() async {
    loading = true;
    notifyListeners(); // ← UI更新を通知

    try {
      summary = await model.getRandomArticleSummary();
      print('Article loaded: ${summary!.titles.normalized}'); // ← デバッグ
      errorMessage = null; // 前のエラーをクリア
    } on HttpException catch (error) {
      errorMessage = error.message;
      print('Error loading article: ${error.message}'); // ← デバッグ
      summary = null; // 前の記事をクリア
    }

    loading = false;
    notifyListeners(); // ← UI更新を通知
  }
}

//Viewを定義
class ArticleView extends StatelessWidget {
  ArticleView({super.key});

  final ArticleViewModel viewModel = ArticleViewModel(ArticleModel());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wikipedia Flutter')),
      body: ListenableBuilder(
        listenable: viewModel,
        builder: (context, child) {
          return switch ((
            viewModel.loading,
            viewModel.summary,
            viewModel.errorMessage,
          )) {
            (true, _, _) => CircularProgressIndicator(),
            (false, _, String message) => Center(child: Text(message)),
            (false, null, null) => Center(
              child: Text('An unknown error has occurred'),
            ),
            (false, Summary summary, null) => ArticlePage(
              summary: summary,
              onPressed: viewModel.getRandomArticleSummary,
            ),
          };
        },
      ),
    );
  }
}

class ArticlePage extends StatelessWidget {
  const ArticlePage({
    super.key,
    required this.summary,
    required this.onPressed,
  });

  final Summary summary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          ArticleWidget(summary: summary),
          ElevatedButton(
            onPressed: onPressed,
            child: Text('Next random article'),
          ),
        ],
      ),
    );
  }
}

class ArticleWidget extends StatelessWidget {
  const ArticleWidget({super.key, required this.summary});

  final Summary summary;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        spacing: 10.0,
        children: [
          // 条件付きレンダリング
          if (summary.hasImage) Image.network(summary.originalImage!.source),
          // タイトル
          Text(
            summary.titles.normalized,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.displaySmall,
          ),
          // 説明（あれば）
          if (summary.description != null)
            Text(
              summary.description!,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          // 本文
          Text(summary.extract),
        ],
      ),
    );
  }
}
