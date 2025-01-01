import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'To-Do App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: TodoScreen(),
    );
  }
}

class TodoScreen extends StatefulWidget {
  @override
  _TodoScreenState createState() => _TodoScreenState();
}

class _TodoScreenState extends State<TodoScreen> {
  List<Task> _tasks = [];
  TextEditingController _taskController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    List<String>? tasksData = prefs.getStringList('tasks');
    if (tasksData != null) {
      setState(() {
        _tasks = tasksData.map((task) => Task.fromJson(json.decode(task))).toList();
      });
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> tasksData = _tasks.map((task) => json.encode(task.toJson())).toList();
    await prefs.setStringList('tasks', tasksData);
  }

  void _addTask(String taskTitle) {
    if (taskTitle.trim().isEmpty) {
      _showErrorDialog('Task title cannot be empty.');
      return;
    }

    String normalizedTitle = taskTitle.trim().toLowerCase();
    if (_tasks.any((task) => task.title.toLowerCase() == normalizedTitle)) {
      _showErrorDialog('Task already exists.');
      return;
    }

    setState(() {
      _tasks.add(Task(title: taskTitle.trim()));
    });
    _taskController.clear();
    _saveTasks();
  }

  void _toggleTaskCompletion(int index) {
    setState(() {
      _tasks[index].isCompleted = !_tasks[index].isCompleted;
    });
    _saveTasks();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Task marked as ${_tasks[index].isCompleted ? 'completed' : 'incomplete'}'),
      ),
    );
  }

  void _deleteTask(int index) {
    final task = _tasks[index];
    if (!task.isCompleted) {
      _showConfirmationDialog(
        'Are you sure you want to delete this incomplete task?',
        () {
          setState(() {
            _tasks.removeAt(index);
          });
          _saveTasks();
        },
      );
    } else {
      setState(() {
        _tasks.removeAt(index);
      });
      _saveTasks();
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showConfirmationDialog(String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmation'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('To-Do App'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: IconButton(
              icon: Icon(Icons.post_add),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PostScreen()),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _taskController,
              decoration: InputDecoration(
                labelText: 'New Task',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.add),
                  onPressed: () => _addTask(_taskController.text),
                ),
              ),
            ),
          ),
          Expanded(
            child: _tasks.isEmpty
                ? Center(
                    child: Text(
                      'No tasks added yet!',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      final task = _tasks[index];
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                        child: ListTile(
                          title: Text(
                            task.title,
                            style: TextStyle(
                              decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          leading: Checkbox(
                            value: task.isCompleted,
                            onChanged: (_) => _toggleTaskCompletion(index),
                          ),
                          trailing: IconButton(
                            icon: Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteTask(index),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class Task {
  String title;
  bool isCompleted;

  Task({required this.title, this.isCompleted = false});

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      title: json['title'],
      isCompleted: json['isCompleted'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'isCompleted': isCompleted,
    };
  }
}

class Post {
  final int id;
  final String title;
  final String body;

  Post({required this.id, required this.title, required this.body});

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'],
      title: json['title'],
      body: json['body'],
    );
  }
}

class PostScreen extends StatefulWidget {
  @override
  _PostScreenState createState() => _PostScreenState();
}

class _PostScreenState extends State<PostScreen> {
  List<Post> _posts = [];
  bool _isLoading = false;
  TextEditingController _userIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts({String userId = ''}) async {
    setState(() {
      _isLoading = true;
    });

    final response = await http.get(
      Uri.parse('https://jsonplaceholder.typicode.com/posts' + (userId.isNotEmpty ? '?userId=$userId' : '')),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      setState(() {
        _posts = data.map((post) => Post.fromJson(post)).toList();
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load posts')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Posts from API'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _userIdController,
              decoration: InputDecoration(
                labelText: 'Search by User ID',
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () {
                    _fetchPosts(userId: _userIdController.text);
                  },
                ),
              ),
            ),
          ),
          _isLoading
              ? Center(child: CircularProgressIndicator())
              : Expanded(
                  child: ListView.builder(
                    itemCount: _posts.length,
                    itemBuilder: (context, index) {
                      final post = _posts[index];
                      return Card(
                        margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                        child: ListTile(
                          title: Text(post.title),
                          subtitle: Text(post.body),
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }
}
