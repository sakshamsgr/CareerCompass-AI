import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../core/theme.dart';
import '../../services/ai_forum_service.dart';

class ForumPostDetailScreen extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> postData;

  const ForumPostDetailScreen({super.key, required this.postId, required this.postData});

  @override
  State<ForumPostDetailScreen> createState() => _ForumPostDetailScreenState();
}

class _ForumPostDetailScreenState extends State<ForumPostDetailScreen> {
  final TextEditingController _commentCtrl = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  bool _isSubmitting = false;

  // 🚀 MENTIONS STATE (Now captures the comment text too!)
  String? _replyingToUserId;
  String? _replyingToUserName;
  String? _replyingToContent; 

  void _startReply(String userId, String userName, String content) {
    setState(() {
      _replyingToUserId = userId;
      _replyingToUserName = userName;
      _replyingToContent = content; // Store the snippet they are replying to
      _commentCtrl.text = "@$userName ";
    });
    _commentFocusNode.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyingToUserId = null;
      _replyingToUserName = null;
      _replyingToContent = null;
      _commentCtrl.clear();
    });
    FocusScope.of(context).unfocus();
  }

  // 🚀 UPGRADED NOTIFICATION DISPATCHER
  Future<void> _sendNotification({
    required String targetUserId, 
    required String type, 
    required String senderName, 
    required String senderImage,
    String? parentCommentSnippet,
  }) async {
    
    // 🚀 THE FIX: I removed the rule that blocks self-notifications so you can test it!
    // if (targetUserId == _currentUserId) return; 

    await FirebaseFirestore.instance
        .collection('users')
        .doc(targetUserId)
        .collection('notifications')
        .add({
      'type': type, 
      'postId': widget.postId,
      'postTitle': widget.postData['title'],
      'senderName': senderName,
      'senderImage': senderImage,
      'parentSnippet': parentCommentSnippet ?? '', 
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    });
  }
  Future<void> _submitComment({String? editCommentId}) async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    
    // Capture state before clearing
    final targetReplyId = _replyingToUserId;
    final targetReplyName = _replyingToUserName;
    final targetReplyContent = _replyingToContent;
    
    // Optimistic UI
    _commentCtrl.clear();
    FocusScope.of(context).unfocus();
    setState(() {
      _replyingToUserId = null;
      _replyingToUserName = null;
      _replyingToContent = null;
    });
    
    if (_currentUserId != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_currentUserId).get();
      final userName = doc.data()?['name'] ?? 'User';
      final userImage = doc.data()?['profileImage'] ?? '';

      if (editCommentId != null) {
        setState(() => _isSubmitting = true);
        final aiResult = await AiForumService.evaluateContent(text: text, isPost: false);
        
        await FirebaseFirestore.instance.collection('forum_comments').doc(editCommentId).update({
          'content': text,
          'status': aiResult['approved'] == true ? 'approved' : 'flagged',
          'aiRejectionReason': aiResult['reason'] ?? '',
        });
        
        if (aiResult['approved'] == false) {
          await FirebaseFirestore.instance.collection('forum_posts').doc(widget.postId).update({
             'commentCount': FieldValue.increment(-1)
          });
        }
        setState(() => _isSubmitting = false);
      } else {
        // INSTANT WRITE
        final commentRef = await FirebaseFirestore.instance.collection('forum_comments').add({
          'postId': widget.postId,
          'authorId': _currentUserId,
          'authorName': userName,
          'authorImage': userImage,
          'content': text,
          'replyingToId': targetReplyId,
          'replyingToName': targetReplyName,
          'createdAt': FieldValue.serverTimestamp(),
          'status': 'approved', 
          'aiRejectionReason': '',
        });

        await FirebaseFirestore.instance.collection('forum_posts').doc(widget.postId).update({
          'commentCount': FieldValue.increment(1)
        });

        // 🚀 DUAL-NOTIFICATION LOGIC
        // 1. If replying to a specific comment, notify that comment's author
        if (targetReplyId != null) {
          _sendNotification(
            targetUserId: targetReplyId, 
            type: 'mention', 
            senderName: userName, 
            senderImage: userImage,
            parentCommentSnippet: targetReplyContent // Attach the snippet!
          );
        }
        // 2. ALWAYS notify the original post author (unless they are the ones who were just mentioned, to avoid double-pinging them)
        if (widget.postData['authorId'] != targetReplyId) {
           _sendNotification(
            targetUserId: widget.postData['authorId'], 
            type: 'post_reply', 
            senderName: userName, 
            senderImage: userImage
          );
        }

        // BACKGROUND AI
        AiForumService.evaluateContent(text: text, isPost: false).then((aiResult) {
          if (aiResult['approved'] == false) {
            commentRef.update({
              'status': 'flagged',
              'aiRejectionReason': aiResult['reason'] ?? 'Flagged by AI'
            });
            FirebaseFirestore.instance.collection('forum_posts').doc(widget.postId).update({
              'commentCount': FieldValue.increment(-1)
            });
            
            // 🚀 FIRE NOTIFICATION TO AUTHOR THAT COMMENT WAS FLAGGED
            _sendNotification(
              targetUserId: _currentUserId, 
              type: 'comment_flagged', 
              senderName: 'AI Moderator', 
              senderImage: '',
              parentCommentSnippet: aiResult['reason']
            );
          }
        });
      }
    }
  }

  Future<void> _deleteComment(String commentId) async {
    await FirebaseFirestore.instance.collection('forum_comments').doc(commentId).delete();
    await FirebaseFirestore.instance.collection('forum_posts').doc(widget.postId).update({
      'commentCount': FieldValue.increment(-1)
    });
  }

  void _beginEdit(String commentId, String currentContent) {
    _commentCtrl.text = currentContent;
    showDialog(
      context: context,
      builder: (context) {
        bool isDark = AppTheme.isDark(context);
        return AlertDialog(
          backgroundColor: isDark ? AppTheme.backgroundDark : Colors.white,
          title: Text("Edit Comment", style: TextStyle(color: isDark ? Colors.white : Colors.black)),
          content: TextField(
            controller: _commentCtrl,
            maxLines: 3,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: AppTheme.inputDecoration('Update your thoughts...', Icons.edit, context),
          ),
          actions: [
            TextButton(onPressed: () { _commentCtrl.clear(); Navigator.pop(context); }, child: const Text("Cancel")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryAccent),
              onPressed: () {
                Navigator.pop(context);
                _submitComment(editCommentId: commentId);
              }, 
              child: const Text("Save", style: TextStyle(color: Colors.white))
            )
          ],
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = AppTheme.isDark(context);
    Color textColor = isDark ? AppTheme.textWhite : AppTheme.textDark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
      appBar: AppBar(title: Text("Discussion", style: TextStyle(color: textColor)), iconTheme: IconThemeData(color: textColor)),
      body: Column(
        children: [
          // THE POST
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(bottom: BorderSide(color: AppTheme.primaryAccent.withValues(alpha: 51))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20, backgroundColor: AppTheme.primaryAccent,
                      backgroundImage: widget.postData['authorImage'] != '' ? NetworkImage(widget.postData['authorImage']) : null,
                      child: widget.postData['authorImage'] == '' ? const Icon(Icons.person, color: Colors.white) : null,
                    ),
                    const SizedBox(width: 12),
                    Text(widget.postData['authorName'], style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 16),
                Text(widget.postData['title'], style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(widget.postData['content'], style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[800], fontSize: 15, height: 1.5)),
              ],
            ),
          ),
          
          // THE COMMENTS
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('forum_comments')
                  .where('postId', isEqualTo: widget.postId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('An error occurred.', style: TextStyle(color: textColor)));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryAccent));
                
                var comments = snapshot.data!.docs.map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>}).toList();
                comments = comments.where((c) => c['status'] == 'approved').toList();
                
                comments.sort((a, b) {
                  Timestamp? tA = a['createdAt'] as Timestamp?;
                  Timestamp? tB = b['createdAt'] as Timestamp?;
                  if (tA == null && tB == null) return 0;
                  if (tA == null) return 1; 
                  if (tB == null) return -1;
                  return tA.compareTo(tB);
                });

                if (comments.isEmpty) {
                  return Center(child: Text("No comments yet. Start the discussion!", style: TextStyle(color: Colors.grey[500])));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final c = comments[index];
                    final DateTime? cTime = (c['createdAt'] as Timestamp?)?.toDate();
                    final bool isOwner = c['authorId'] == _currentUserId;
                    
                    List<TextSpan> contentSpans = [];
                    String contentText = c['content'];
                    if (c['replyingToName'] != null && contentText.startsWith("@${c['replyingToName']}")) {
                      contentSpans.add(TextSpan(text: "@${c['replyingToName']} ", style: const TextStyle(color: AppTheme.primaryAccent, fontWeight: FontWeight.bold)));
                      contentSpans.add(TextSpan(text: contentText.replaceFirst("@${c['replyingToName']} ", "")));
                    } else {
                      contentSpans.add(TextSpan(text: contentText));
                    }
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withAlpha(13) : Colors.black.withAlpha(13),
                        borderRadius: BorderRadius.circular(12)
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(c['authorName'], style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(width: 8),
                              if (cTime != null)
                                Text(timeago.format(cTime), style: TextStyle(color: Colors.grey[500], fontSize: 11))
                              else
                                const Text("Just now", style: TextStyle(color: AppTheme.primaryAccent, fontSize: 11)),
                              
                              const Spacer(),
                              
                              // 🚀 MENTION / REPLY BUTTON (Now passes the content text)
                              InkWell(
                                onTap: () => _startReply(c['authorId'], c['authorName'], c['content']),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                                  child: Text("Reply", style: TextStyle(color: AppTheme.secondaryAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                                ),
                              ),

                              if (isOwner)
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert, color: Colors.grey[500], size: 16),
                                  color: isDark ? AppTheme.backgroundDark : Colors.white,
                                  padding: EdgeInsets.zero,
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _beginEdit(c['id'], c['content']);
                                    } else if (value == 'delete') {
                                      _deleteComment(c['id']);
                                    }
                                  },
                                  itemBuilder: (BuildContext context) => [
                                    const PopupMenuItem(value: 'edit', height: 35, child: Text('Edit', style: TextStyle(fontSize: 13))),
                                    const PopupMenuItem(value: 'delete', height: 35, child: Text('Delete', style: TextStyle(color: Colors.red, fontSize: 13))),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          RichText(text: TextSpan(style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[800], fontSize: 14), children: contentSpans)),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // COMMENT INPUT
          Container(
            padding: const EdgeInsets.all(16),
            color: isDark ? AppTheme.backgroundDark : Colors.white,
            child: Column(
              children: [
                if (_replyingToUserName != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        Text("Replying to @$_replyingToUserName", style: const TextStyle(color: AppTheme.primaryAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                        const Spacer(),
                        InkWell(onTap: _cancelReply, child: const Icon(Icons.close, size: 16, color: Colors.grey)),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentCtrl,
                        focusNode: _commentFocusNode,
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: 'Add to the discussion...',
                          hintStyle: TextStyle(color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight),
                          filled: true,
                          fillColor: isDark
                              ? const Color.fromARGB(13, 255, 255, 255)
                              : const Color.fromARGB(13, 0, 0, 0),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: AppTheme.secondaryAccent,
                      child: _isSubmitting 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 18), onPressed: _submitComment),
                    )
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}