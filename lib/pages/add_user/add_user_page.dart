import 'package:fall_detection/pages/auth/user_model.dart';
import 'package:fall_detection/util/utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// User model
class UserSearchPage extends StatefulWidget {
  const UserSearchPage({super.key});

  @override
  State<UserSearchPage> createState() => _UserSearchPageState();
}

class _UserSearchPageState extends State<UserSearchPage> {
  final TextEditingController _searchController = TextEditingController();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance.currentUser;
  List<UserModel> _allUsers = [];
  List<UserModel> _filteredUsers = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  bool _isInitialLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAllUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Load all users from Firebase once
  Future<void> _loadAllUsers() async {
    setState(() {
      _isInitialLoading = true;
    });

    try {
      var snapshot = await _firestore.collection('users').get();

      List<UserModel> users =
          snapshot.docs.map((doc) {
            var m = doc.data();
            m['uid'] = doc.id;
            return UserModel.fromMap(m);
          }).toList();
      users.forEach((user) => print(user.uid));
      users.removeWhere((user) => user.uid == _auth!.uid);

      setState(() {
        _allUsers = users;
        _filteredUsers = users;
        _isInitialLoading = false;
      });
    } catch (e) {
      setState(() {
        _isInitialLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading users: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Refresh users data
  Future<void> _refreshUsers() async {
    await _loadAllUsers();
    if (_searchQuery.isNotEmpty) {
      _performOfflineSearch(_searchQuery);
    }
  }

  // Perform offline search on loaded data
  void _performOfflineSearch(String query) {
    setState(() {
      _searchQuery = query.toLowerCase().trim();
      _hasSearched = query.isNotEmpty;
    });

    if (query.trim().isEmpty) {
      setState(() {
        _filteredUsers = _allUsers;
      });
      return;
    }

    List<UserModel> results =
        _allUsers.where((user) {
          String userName = user.name.toLowerCase();
          String userEmail = user.email.toLowerCase();

          return userName.contains(_searchQuery) ||
              userEmail.contains(_searchQuery);
        }).toList();

    // Sort results by relevance
    results.sort((a, b) {
      // Exact name matches first
      bool aNameStarts = a.name.toLowerCase().startsWith(_searchQuery);
      bool bNameStarts = b.name.toLowerCase().startsWith(_searchQuery);

      if (aNameStarts && !bNameStarts) return -1;
      if (!aNameStarts && bNameStarts) return 1;

      // Then exact email matches
      bool aEmailStarts = a.email.toLowerCase().startsWith(_searchQuery);
      bool bEmailStarts = b.email.toLowerCase().startsWith(_searchQuery);

      if (aEmailStarts && !bEmailStarts) return -1;
      if (!aEmailStarts && bEmailStarts) return 1;

      // Finally alphabetical by name
      return a.name.compareTo(b.name);
    });

    setState(() {
      _filteredUsers = results;
    });
  }

  // Show user operations dialog
  void _showUserOperations(UserModel user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) =>
              UserOperationsSheet(user: user, onUserUpdated: _refreshUsers),
    );
  }

  // Highlight search query in text
  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) return Text(text);

    String lowerText = text.toLowerCase();
    String lowerQuery = query.toLowerCase();

    if (!lowerText.contains(lowerQuery)) {
      return Text(text);
    }

    List<TextSpan> spans = [];
    int start = 0;

    while (true) {
      int index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: TextStyle(
            backgroundColor: Colors.yellow.withOpacity(0.3),
            fontWeight: FontWeight.bold,
          ),
        ),
      );

      start = index + query.length;
    }

    return RichText(
      text: TextSpan(children: spans, style: TextStyle(color: Colors.black)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Search Users'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshUsers,
            tooltip: 'Refresh Users',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search by name, email, or phone...',
                    prefixIcon: Icon(Icons.search),
                    suffixIcon:
                        _searchController.text.isNotEmpty
                            ? IconButton(
                              icon: Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _performOfflineSearch('');
                              },
                            )
                            : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {});
                    _performOfflineSearch(value);
                  },
                ),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _hasSearched
                          ? '${_filteredUsers.length} of ${_allUsers.length} users'
                          : '${_allUsers.length} total users',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    if (_isInitialLoading)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // Search Results
          Expanded(
            child:
                _isInitialLoading
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading users...'),
                          SizedBox(height: 8),
                          Text(
                            'This may take a moment',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                    : _filteredUsers.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _hasSearched
                                ? Icons.search_off
                                : Icons.people_outline,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            _hasSearched
                                ? 'No users found'
                                : 'No users available',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            _hasSearched
                                ? 'Try searching with different keywords'
                                : 'Add some users to get started',
                            style: TextStyle(color: Colors.grey),
                          ),
                          if (_hasSearched) ...[
                            SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                _searchController.clear();
                                _performOfflineSearch('');
                              },
                              child: Text('Show All Users'),
                            ),
                          ],
                        ],
                      ),
                    )
                    : RefreshIndicator(
                      onRefresh: _refreshUsers,
                      child: ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _filteredUsers.length,
                        itemBuilder: (context, index) {
                          UserModel user = _filteredUsers[index];
                          return Card(
                            margin: EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.all(16),
                              leading: CircleAvatar(
                                radius: 25,
                                backgroundColor: Colors.blue.withOpacity(0.1),

                                child: Text(
                                  user.name.isNotEmpty
                                      ? user.name[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                              title: _buildHighlightedText(
                                user.name,
                                _searchQuery,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 4),
                                  _buildHighlightedText(
                                    user.email,
                                    _searchQuery,
                                  ),

                                  SizedBox(height: 4),
                                  Text(
                                    'Joined ${_formatDate(user.createdAt.toDate())}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Icon(Icons.arrow_forward_ios, size: 16),
                              onTap: () => _showUserOperations(user),
                            ),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _refreshUsers,
        backgroundColor: Colors.blue,
        tooltip: 'Refresh Users',
        child: Icon(Icons.refresh, color: Colors.white),
      ),
    );
  }

  String _formatDate(DateTime date) {
    Duration difference = DateTime.now().difference(date);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year${(difference.inDays / 365).floor() > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}

// User Operations Bottom Sheet
class UserOperationsSheet extends StatelessWidget {
  final UserModel user;
  final VoidCallback onUserUpdated;

  const UserOperationsSheet({
    super.key,
    required this.user,
    required this.onUserUpdated,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: 8),
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // User Info Header
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.blue.withOpacity(0.1),

                  child: Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        user.email,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Active',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1),

          _buildOperationTile(
            context,
            icon: Icons.add,
            title: 'Add to your list',
            subtitle: 'Send a notification or message',
            onTap: () async {
              var auth = FirebaseAuth.instance.currentUser;
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(auth!.uid)
                  .update({
                    'related': FieldValue.arrayUnion([user.uid]),
                  });

              if (context.mounted) {
                showSnackBar(context, 'User Added Successfully');
                Navigator.pop(context);
              }
            },
          ),

          SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildOperationTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (isDestructive ? Colors.red : Colors.blue).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isDestructive ? Colors.red : Colors.blue,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : Colors.black,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(subtitle),
      onTap: onTap,
    );
  }
}
