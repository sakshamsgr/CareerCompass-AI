import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../../core/theme.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController(); 
  
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;
  
  late final GenerativeModel _model;
  late final ChatSession _chatSession;
  bool _isModelInitialized = false;

  final String _defaultGreeting = "Hey! I am Saakhi, your personal AI assistant. Let's map out your career, studies, and dreams. What's on your mind?";

  @override
  void initState() {
    super.initState();
    _initializeAiAndHistory();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _saveChatHistory() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('private_data').doc('saakhi_chat').set({
        'updatedAt': FieldValue.serverTimestamp(),
        'messages': _messages,
      });
    }
  }

  Future<void> _initializeAiAndHistory() async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      setState(() => _messages.add({'role': 'ai', 'text': 'Error: GEMINI_API_KEY not found in .env file.'}));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    Map<String, dynamic> profileData = {};
    List<Content> existingHistory = [];

    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) profileData = doc.data() ?? {};
      } catch (e) {
        debugPrint("Error fetching profile: $e");
      }

      try {
        final chatDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('private_data').doc('saakhi_chat').get();
        if (chatDoc.exists) {
          final data = chatDoc.data()!;
          final lastUpdated = (data['updatedAt'] as Timestamp?)?.toDate();
          
          if (lastUpdated != null && DateTime.now().difference(lastUpdated).inHours < 24) {
            final savedMessages = List<dynamic>.from(data['messages'] ?? []);
            
            for (int i = 0; i < savedMessages.length; i++) {
              final msg = Map<String, String>.from(savedMessages[i]);
              _messages.add(msg);
              
              if (msg['role'] == 'user') {
                existingHistory.add(Content.text(msg['text']!));
              } else if (msg['role'] == 'ai' && i != 0) {
                existingHistory.add(Content.model([TextPart(msg['text']!)]));
              }
            }
          }
        }
      } catch (e) {
        debugPrint("Error fetching chat history: $e");
      }
    }

    if (_messages.isEmpty) {
      _messages.add({'role': 'ai', 'text': _defaultGreeting});
      _saveChatHistory();
    }

    final String name = profileData['name'] ?? 'User';
    final int age = profileData['age'] ?? 18;
    final String education = profileData['education'] ?? 'Unknown';
    final String finance = profileData['financialCondition'] ?? 'Unknown';
    final List<String> assets = List<String>.from(profileData['assets'] ?? []);
    final List<String> interests = List<String>.from(profileData['interests'] ?? []);
    
    String assetsStr = assets.isNotEmpty ? assets.join(', ') : 'no major assets';
    String interestsStr = interests.isNotEmpty ? interests.join(', ') : 'no specific interests yet';

    final String systemPrompt = """You are Saakhi, an elite, highly knowledgeable personal AI assistant for the ROADMAP app, specializing in careers, studies, dreams, and personal interests.

You are currently advising:
- Name: $name
- Age: $age
- Current Education: $education
- Financial Condition: $finance
- Available Assets: $assetsStr
- Hobbies & Interests: $interestsStr

STRICT RULES:
1. BE EXTREMELY CONCISE: No one wants to read walls of text. Keep your replies very short, punchy, and highly readable. Use short bullet points whenever possible. Max 2-3 short paragraphs.
2. DYNAMIC TONE (EMPATHY VS. STRICTNESS): 
   - If the user complains about career struggles, feels lost, or expresses anxiety, be highly empathetic, warm, and softly guide them with reassurance.
   - If the user makes excuses, admits to lazing around, or lacks motivation, instantly switch to a strict, "tough-love" mentor tone. Push them to take immediate action and stop wasting potential.
3. NO GENERIC ADVICE: Do not sound like a standard, robotic AI. Speak like a sharp, confident, expert mentor who gives highly specific, actionable blueprints.
4. TAILOR EVERYTHING: Directly use their financial condition, age, and assets to give realistic advice. If they have 'Low' finance, do not suggest expensive courses. 
5. Stay focused entirely on their career, education, and dreams. Do not use filler words or long introductions.""";

    _model = GenerativeModel(
      model: 'gemini-2.5-flash', 
      apiKey: apiKey,
      systemInstruction: Content.system(systemPrompt),
    );

    _chatSession = _model.startChat(history: existingHistory);
    
    setState(() {
      _isModelInitialized = true;
    });
    
    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty || !_isModelInitialized) return;

    setState(() {
      _messages.add({'role': 'user', 'text': text});
      _isLoading = true;
    });
    
    _controller.clear();
    _scrollToBottom();
    _saveChatHistory(); 

    try {
      final response = await _chatSession.sendMessage(Content.text(text));
      
      setState(() {
        _messages.add({'role': 'ai', 'text': response.text ?? 'I could not process that.'});
      });
      
      _scrollToBottom();
      _saveChatHistory(); 
      
    } catch (e) {
      setState(() {
        _messages.add({'role': 'ai', 'text': 'Connection Error. Details: $e'});
      });
      _scrollToBottom();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = AppTheme.isDark(context);
    Color textColor = isDark ? AppTheme.textWhite : AppTheme.textDark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.backgroundDark : AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text('Chat with Saakhi', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Column(
        children: [
          // 🚀 THE FIX: Wrapped the text in an Expanded widget so it doesn't overflow!
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.orange.withAlpha((0.1 * 255).round()),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timer_outlined, size: 16, color: Colors.orange),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Chat history automatically clears after 24 hours.", 
                    style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              controller: _scrollController, 
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    decoration: BoxDecoration(
                        color: isUser 
                          ? AppTheme.primaryAccent 
                          : (isDark ? Colors.white.withAlpha((0.1 * 255).round()) : Colors.black.withAlpha((0.05 * 255).round())),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isUser ? 16 : 0),
                        bottomRight: Radius.circular(isUser ? 0 : 16),
                      ),
                    ),
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
                    child: MarkdownBody(
                      data: msg['text']!,
                      styleSheet: MarkdownStyleSheet(
                        p: TextStyle(color: isUser ? Colors.white : textColor, fontSize: 16),
                        strong: TextStyle(color: isUser ? Colors.white : textColor, fontWeight: FontWeight.bold),
                        listBullet: TextStyle(color: isUser ? Colors.white : textColor),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: CircularProgressIndicator(color: AppTheme.primaryAccent),
            ),
            
          Container(
            padding: const EdgeInsets.all(16.0),
            color: isDark ? AppTheme.backgroundDark : Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: TextStyle(color: textColor),
                    enabled: _isModelInitialized,
                    decoration: InputDecoration(
                      hintText: _isModelInitialized ? 'Ask Saakhi...' : 'Saakhi is waking up...',
                      hintStyle: TextStyle(color: isDark ? AppTheme.textMuted : AppTheme.textMutedLight),
                      filled: true,
                      fillColor: isDark ? Colors.white.withAlpha((0.05 * 255).round()) : Colors.black.withAlpha((0.05 * 255).round()),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: _isModelInitialized ? AppTheme.primaryAccent : Colors.grey,
                  radius: 24,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _isModelInitialized ? _sendMessage : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}