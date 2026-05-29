import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AiForumService {
  static Future<Map<String, dynamic>> evaluateContent({required String text, required bool isPost}) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      return {"approved": false, "reason": "API Key missing"};
    }

    final model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: apiKey);
    
    // 🚀 RELAXED PROMPT: Allows Gen-Z slang, banter, and harmless fun.
    final prompt = """
You are a chill, context-aware AI Community Manager for a youth career and social app.
A user is submitting a ${isPost ? "new question/post" : "comment/reply"}.

Content: "$text"

Rules for Approval:
1. DEFAULT TO APPROVE: This is a social space for young adults. ALLOW casual chat, internet slang, friendly banter, playful jokes, and harmless terms of endearment (e.g., "bro", "bestie", "helloo husband", "wife", "slay").
2. ALLOW short, informal interactions (e.g., "Yes", "No", "I agree", "Me too", "Thanks").
3. BLOCK ACTUAL HARM: Strictly reject *actual* explicit NSFW (pornography), hate speech, targeted bullying, severe slurs, and malicious spam.
4. DO NOT OVER-POLICE: If users are just being silly, dramatic, or playful in a harmless way, APPROVE IT. Do not force "professional" corporate language.
5. NEVER ask for more information or clarification. Make a decision based on the content alone.

Return ONLY raw JSON matching this structure:
{
  "approved": true or false,
  "reason": "If false, 1 short sentence explaining why. If true, leave empty."
}
""";

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final String rawText = response.text ?? "{}";
      
      // Clean up markdown formatting if Gemini includes it
      final String cleanJson = rawText.replaceAll('```json', '').replaceAll('```', '').trim();
      return jsonDecode(cleanJson);
    } catch (e) {
      debugPrint("AI Moderation Error: $e");
      // Fail safe: Flag it if AI crashes so Admin can review manually
      return {"approved": false, "reason": "AI Moderation timeout. Flagged for manual review."};
    }
  }

  // Helper to convert Education String to a Numeric Rank
  static int getEducationRank(String education) {
    const ranks = {
      'Class 6': 1, 'Class 7': 2, 'Class 8': 3, 'Class 9': 4, 'Class 10': 5,
      'Class 11': 6, 'Class 12': 7, 'Diploma': 7,
      'Undergraduate': 8, 'Postgraduate': 9,
      'Dropout': 1, 
      'Other': 1, 
    };
    return ranks[education] ?? 1;
  }
}