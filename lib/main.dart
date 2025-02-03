import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Family Albums',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black26,
          elevation: 0,
        ),
        scaffoldBackgroundColor: Colors.black,
      ),
      home: const RepositoryListPage(),
    );
  }
}

class RepositoryListPage extends StatefulWidget {
  const RepositoryListPage({super.key});

  @override
  State<RepositoryListPage> createState() => _RepositoryListPageState();
}

class _RepositoryListPageState extends State<RepositoryListPage> {
  List<Map<String, dynamic>> repositories = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRepositories();
  }

  Future<void> _fetchRepositories() async {
    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/users/FamilyWebsites/repos'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> repos = json.decode(response.body);
        setState(() {
          repositories = repos
              .map((repo) => {
                    'name': repo['name'],
                    'description': repo['description'] ?? 'No description',
                  })
              .toList();
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      debugPrint('Error fetching repositories: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Albums'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: repositories.length,
              itemBuilder: (context, index) {
                final repo = repositories[index];
                return ListTile(
                  title: Text(repo['name']),
                  subtitle: Text(repo['description']),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => GalleryPage(
                          repoName: repo['name'],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class GalleryPage extends StatefulWidget {
  final String repoName;

  const GalleryPage({
    super.key,
    required this.repoName,
  });

  @override
  State<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends State<GalleryPage> {
  List<String> imagePaths = [];
  bool isLoading = true;

  String get thumbnailBaseUrl =>
      'https://raw.githubusercontent.com/FamilyWebsites/${widget.repoName}/main/thumbnails';
  String get fullImageBaseUrl =>
      'https://raw.githubusercontent.com/FamilyWebsites/${widget.repoName}/main';

  void _showFullImage(BuildContext context, String imageName) {
    final fullImageUrl = '$fullImageBaseUrl/$imageName';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Full Image'),
            actions: [
              IconButton(
                icon: const Icon(Icons.download),
                onPressed: () => _downloadImage(fullImageUrl, imageName),
              ),
            ],
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                fullImageUrl,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _downloadImage(String imageUrl, String fileName) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));
      final dir = await getExternalStorageDirectory();
      final file = File('${dir?.path}/$fileName');
      await file.writeAsBytes(response.bodyBytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image saved to ${file.path}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to download image')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchImagePaths();
  }

  Future<void> _fetchImagePaths() async {
    try {
      final response = await http.get(Uri.parse(
          'https://api.github.com/repos/FamilyWebsites/${widget.repoName}/contents/thumbnails'));

      if (response.statusCode == 200) {
        final List<dynamic> contents = json.decode(response.body);
        setState(() {
          imagePaths = contents
              .where((item) =>
                  item['type'] == 'file' &&
                  (item['name'].endsWith('.jpg') ||
                      item['name'].endsWith('.jpeg') ||
                      item['name'].endsWith('.png')))
              .map((item) => item['name'] as String)
              .toList();
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      debugPrint('Error fetching images: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.repoName),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : MasonryGridView.builder(
              itemCount: imagePaths.length,
              gridDelegate:
                  const SliverSimpleGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
              ),
              itemBuilder: (context, index) {
                final thumbnailUrl = '$thumbnailBaseUrl/${imagePaths[index]}';
                return GestureDetector(
                  onTap: () => _showFullImage(context, imagePaths[index]),
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Image.network(
                      thumbnailUrl,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
