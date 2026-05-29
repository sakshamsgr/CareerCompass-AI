import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../data/models/career_model.dart';

class AiEarnService {
  
  // 🚀 HELPER: Strips markdown backticks from AI responses
  static String _cleanJsonString(String rawString) {
    String cleaned = rawString.trim();
    int startIndex = cleaned.indexOf('{');
    int endIndex = cleaned.lastIndexOf('}');
    
    if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
       return cleaned.substring(startIndex, endIndex + 1);
    }
    return cleaned;
  }

  static Future<Map<String, dynamic>?> discoverGigsAndSkills(Map<String, dynamic> userData) async {
    final apiKey = dotenv.env['MISTRAL_API_KEY'];
    if (apiKey == null) return null;

    const String url = "https://api.mistral.ai/v1/chat/completions";

    final assets = (userData['assets'] as List<dynamic>?)?.join(', ') ?? 'None';
    final budget = userData['financialCondition'] ?? 'Unknown';
    final time = userData['timeCommitment'] ?? 'Unknown';

    final String prompt = """
The user wants to make money and learn skills. Here is their situation:
- Assets Owned: $assets
- Investment Budget: $budget
- Time Available: $time

Task 1 (EARN): Recommend 6 to 8 immediate freelance, gig, or side-hustle opportunities they can start THIS WEEK based strictly on the assets and time they have.
Task 2 (LEARN): Recommend 6 to 8 high-income digital or practical skills they should learn to dramatically increase their income.

RETURN ONLY RAW JSON. NO MARKDOWN:
{
  "earn": [
    {
      "title": "Gig Title",
      "payout": "Estimated Earnings",
      "whyItFits": "1 sentence.",
      "requiredAsset": "Main asset used"
    }
  ],
  "learn": [
    {
      "title": "Skill Name",
      "timeToLearn": "e.g., 30 Days",
      "whyItFits": "1 sentence."
    }
  ]
}
""";

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'},
        body: jsonEncode({
          "model": "mistral-small-latest",
          "messages": [
            {"role": "system", "content": "You are a realistic Indian Hustle & Gig Economy Expert. Output strictly valid JSON."},
            {"role": "user", "content": prompt}
          ],
          "response_format": {"type": "json_object"},
          "temperature": 0.4, 
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        String content = responseData['choices'][0]['message']['content'];
        
        // Strip markdown/conversational text before decoding
        content = _cleanJsonString(content);
        
        try {
          return jsonDecode(content);
        } catch (parseError) {
          debugPrint("❌ Discover Gigs Parse Error: $parseError\nRAW CONTENT: $content");
          return null;
        }
      } else {
        debugPrint("❌ Discover Gigs API Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("❌ Discover Gigs HTTP Error: $e");
      return null;
    }
  }

  static Future<CareerModel?> generateSkillRoadmap(String skillName) async {
    final apiKey = dotenv.env['MISTRAL_API_KEY'];
    if (skillName.trim().isEmpty || apiKey == null) return null;

    const String url = "https://api.mistral.ai/v1/chat/completions";

    final String prompt = """
The user wants to master the skill: "$skillName".
Task: Generate a highly detailed, 30-day learning roadmap in JSON format.

RETURN ONLY RAW JSON. NO MARKDOWN:
{
  "name": "Mastering $skillName",
  "expectedIncome": "Freelance/Job Potential",
  "baseGraduationAge": 0,
  "description": "Why this skill is profitable.",
  "requiredStreams": ["Any"],
  "examsNeeded": "Certifications",
  "examLink": "",
  "examLinkName": "",
  "roadmapSteps": [
    {"id": "n1", "label": "START TODAY: Quick YouTube Crash Course", "nextSteps": ["n2"]},
    {"id": "n2", "label": "Week 1: Fundamentals", "nextSteps": ["n3"]},
    {"id": "n3", "label": "Week 2: Advanced Techniques", "nextSteps": ["n4"]},
    {"id": "n4", "label": "Week 3: Practical Projects", "nextSteps": ["n5"]},
    {"id": "n5", "label": "Week 4: Portfolio & Outreach", "nextSteps": []}
  ],
  "salaryBeginner": "₹X/project",
  "salaryMid": "₹Y/project",
  "salaryHigh": "₹Z+",
  "topCompanies": ["Freelance", "Startups"],
  "branches": [{"name": "Scope", "description": "Details"}],
  "pros": ["High demand", "Remote"],
  "cons": ["Consistency required"],
  "coreSkills": ["Practice", "Tools"]
}
""";

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'},
        body: jsonEncode({
          "model": "mistral-small-latest",
          "messages": [
            {"role": "system", "content": "You are an Elite Skill Coach. Output strictly valid JSON."},
            {"role": "user", "content": prompt}
          ],
          "response_format": {"type": "json_object"},
          "temperature": 0.3, 
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        String content = responseData['choices'][0]['message']['content'];
        
        // Strip markdown/conversational text before decoding
        content = _cleanJsonString(content);

        try {
          return CareerModel.fromJson(jsonDecode(content), isTemporary: true);
        } catch (parseError) {
          debugPrint("❌ Skill Parse Error: $parseError\nRAW CONTENT: $content");
          return null;
        }
      } else {
        debugPrint("❌ Skill API Error: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("❌ Skill HTTP Error: $e");
      return null;
    }
  }

  static Future<CareerModel?> generateGigRoadmap(String gigName) async {
    final apiKey = dotenv.env['MISTRAL_API_KEY'];
    if (gigName.trim().isEmpty || apiKey == null) return null;

    const String url = "https://api.mistral.ai/v1/chat/completions";

    final String prompt = """
The user wants to start executing this gig/hustle: "$gigName".
Task: Generate a highly detailed, 7-to-14 day action plan in JSON format.

CRITICAL INSTRUCTIONS:
1. THE "START TODAY" RULE: Node 1 MUST be a free, immediate action (e.g., "Sign up for Platform X", "Optimize Profile").
2. STEP-BY-STEP: Break the gig down into execution phases (e.g., Profile Setup -> Sourcing Leads -> First Pitch -> Delivering Work -> Getting Paid).
3. REUSE CAREER SCHEMA: We are reusing a career JSON schema for an execution roadmap. Keep `baseGraduationAge` at 0. Use `salaryBeginner` for standard payouts.

RETURN ONLY RAW JSON. NO MARKDOWN:
{
  "name": "Executing $gigName",
  "expectedIncome": "Gig Payout Potential",
  "baseGraduationAge": 0,
  "description": "2-3 sentences on how to succeed and get paid quickly doing this.",
  "requiredStreams": ["Any"],
  "examsNeeded": "None",
  "examLink": "",
  "examLinkName": "",
  "roadmapSteps": [
    {"id": "n1", "label": "START TODAY: [Platform Sign Up / Profile Setup]", "nextSteps": ["n2"]},
    {"id": "n2", "label": "Day 2: [Optimize profile/portfolio]", "nextSteps": ["n3"]},
    {"id": "n3", "label": "Day 3: [Sourcing your first lead/client]", "nextSteps": ["n4"]},
    {"id": "n4", "label": "Day 5: [Pitching / Bidding on jobs]", "nextSteps": ["n5"]},
    {"id": "n5", "label": "Execution: [Delivering the actual work]", "nextSteps": ["n6"]},
    {"id": "n6", "label": "Getting Paid & Asking for Reviews", "nextSteps": []}
  ],
  "salaryBeginner": "₹X/day",
  "salaryMid": "₹Y/week",
  "salaryHigh": "₹Z/month",
  "topCompanies": ["Relevant Platforms (e.g., Swiggy, Upwork, Local)"],
  "branches": [{"name": "Upsell opportunity", "description": "Details"}],
  "pros": ["Immediate cash", "Flexible"],
  "cons": ["Hustle required", "Variable income"],
  "coreSkills": ["Communication", "Reliability", "Time Management"]
}
""";

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $apiKey', 'Content-Type': 'application/json'},
        body: jsonEncode({
          "model": "mistral-small-latest",
          "messages": [
            {"role": "system", "content": "You are a Gig Economy Execution Expert. Output strictly valid JSON."},
            {"role": "user", "content": prompt}
          ],
          "response_format": {"type": "json_object"},
          "temperature": 0.3, 
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        String content = responseData['choices'][0]['message']['content'];
        
        // Strip markdown before decoding gig JSON!
        content = _cleanJsonString(content);

        try {
          return CareerModel.fromJson(jsonDecode(content), isTemporary: true);
        } catch (e) {
          debugPrint("❌ Gig Parse Error: $e\nRAW CONTENT: $content");
          return null;
        }
      }
      return null;
    } catch (e) {
      debugPrint("❌ Gig HTTP Error: $e");
      return null;
    }
  }
}