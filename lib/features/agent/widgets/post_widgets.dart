import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// Widget to display a post card
class PostCard extends StatelessWidget {
  final String id;
  final String title;
  final String description;
  final String content;
  final String timestamp;

  const PostCard({
    super.key,
    required this.id,
    required this.title,
    required this.description,
    required this.content,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Text(content),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatTimestamp(timestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Implement like functionality
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Post liked!')),
                    );
                  },
                  icon: const Icon(Icons.thumb_up),
                  label: const Text('Like'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return timestamp;
    }
  }
}

/// Widget for creating a new post
class PostCreatorForm extends StatefulWidget {
  const PostCreatorForm({super.key});

  @override
  State<PostCreatorForm> createState() => _PostCreatorFormState();
}

class _PostCreatorFormState extends State<PostCreatorForm> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contentController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Create a New Post',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Enter post title...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Brief description...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Content',
                hintText: 'Write your post content here...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _createPost,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Create Post'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _createPost() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in title and content')),
      );
      return;
    }

    // Clear form
    _titleController.clear();
    _descriptionController.clear();
    _contentController.clear();

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Post created!')),
    );
  }
}

/// Schema defining the data structure for the post card widget
final postCardSchema = S.object(
  properties: {
    'id': S.string(description: 'Unique identifier for the post'),
    'title': S.string(description: 'Post title'),
    'description': S.string(description: 'Post description'),
    'content': S.string(description: 'Post content'),
    'timestamp': S.string(description: 'Post timestamp'),
  },
  required: ['id', 'title', 'content'],
);

/// Catalog entry for the post card widget
final postCardWidget = CatalogItem(
  name: 'PostCard',
  dataSchema: postCardSchema,
  widgetBuilder: (itemContext) {
    final dataMap = itemContext.data as Map<String, dynamic>;
    return PostCard(
      id: dataMap['id'] ?? '',
      title: dataMap['title'] ?? 'Untitled',
      description: dataMap['description'] ?? '',
      content: dataMap['content'] ?? '',
      timestamp: dataMap['timestamp'] ?? '',
    );
  },
);

/// Schema defining the data structure for the post creator form widget
final postCreatorSchema = S.object(
  properties: {
    'placeholder': S.string(description: 'Placeholder text for the form'),
  },
);

/// Catalog entry for the post creator form
final postCreatorWidget = CatalogItem(
  name: 'PostCreatorForm',
  dataSchema: postCreatorSchema,
  widgetBuilder: (itemContext) => const PostCreatorForm(),
);
