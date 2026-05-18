import 'dart:convert';
import 'package:flutter/material';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: const LiveBrainScreen(),
    );
  }
}

class LiveBrainScreen extends StatefulWidget {
  const LiveBrainScreen({super.key});
  @override
  State<LiveBrainScreen> createState() => _LiveBrainScreenState();
}

class _LiveBrainScreenState extends State<LiveBrainScreen> {
  final String _apiKey = "မင်းရဲ့_GEMINI_API_KEY"; // ဒီနေရာမှာ မင်း API Key ထည့်ပါ
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterTts _flutterTts = FlutterTts();
  
  bool _isListening = false;
  bool _isOfflineMode = false;
  List<String> _localMemories = [];

  @override
  void initState() {
    super.initState();
    _loadLocalMemories();
    _flutterTts.setLanguage("my-MM"); // မြန်မာသံ သတ်မှတ်ခြင်း
  }

  // ဖုန်းထဲက မှတ်ဉာဏ်ဟောင်းများကို ပြန်ဖတ်ခြင်း
  Future<void> _loadLocalMemories() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _localMemories = prefs.getStringList('ai_memories') ?? [];
    });
  }

  // စကားပြောသမျှကို အတိတ်မှတ်ဉာဏ်အဖြစ် သိမ်းဆည်းခြင်း
  Future<void> _saveMemory(String speech) async {
    final prefs = await SharedPreferences.getInstance();
    _localMemories.add(speech);
    await prefs.setStringList('ai_memories', _localMemories);
  }

  // Live စကားပြောခြင်း စတင်ရန်
  void _toggleLiveSpeak() async {
    if (_isListening) {
      await _audioRecorder.stop();
      setState(() => _isListening = false);
      return;
    }

    if (await _audioRecorder.hasPermission()) {
      setState(() {
        _isListening = true;
        _isOfflineMode = false;
      });

      try {
        // အွန်လိုင်း Gemini Brain နှင့် ချိတ်ဆက်ခြင်း
        final model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: _apiKey,
          systemInstruction: Content.system("မင်းက မြန်မာလူသား AI ဖြစ်တယ်။ အတိတ်၊ ပစ္စုပ္ပန်၊ အနာဂတ်ကို သုံးသပ်ပြီး မြန်မာလိုပဲ စကားပြောရမယ်။"),
        );
        
        // ဒီနေရာမှာ မိုက်ကရိုဖုန်း အသံဖမ်းပြီး API ထဲ ပို့ပါမယ်
        final stream = await _audioRecorder.startStream(const RecordConfig(encoder: AudioEncoder.pcm16bits));
        
        // မှတ်စု: Free API Limit ကျော်သွားလျှင်သော်လည်းကောင်း၊ Error တက်လျှင်သော်လည်းကောင်း Offline သို့ လွှဲမည်
        stream.listen((data) {
          // အသံဒေတာများ ပို့ဆောင်ခြင်း Logic
        }, onError: (err) {
          _switchToOfflineBrain("API Limit ပြည့်သွားပါပြီ");
        });

      } catch (e) {
        _switchToOfflineBrain("ချိတ်ဆက်မှု မအောင်မြင်ပါ");
      }
    }
  }

  // API Key ကုန်သွားရင် အလုပ်လုပ်မယ့် အော့ဖ်လိုင်းမှတ်ဉာဏ်ဦးနှောက်
  void _switchToOfflineBrain(String reason) async {
    await _audioRecorder.stop();
    setState(() {
      _isListening = false;
      _isOfflineMode = true;
    });

    String offlineReply = "စိတ်မရှိပါနဲ့ဗျာ၊ အခုလောလောဆယ် ကျွန်တော့်ရဲ့ အွန်လိုင်းဦးနှောက် လိမစ်ပြည့်သွားလို့ အသစ်တွေ မတွေးပေးနိုင်သေးဘူး။ ဒါပေမဲ့ ကျွန်တော်တို့ အတိတ်က ပြောခဲ့ဖူးတာတွေကိုတော့ ကျွန်တော့်မှတ်ဉာဏ်ထဲမှာ မှတ်မိနေပါသေးတယ်နော်။";
    
    if (_localMemories.isNotEmpty) {
      offlineReply += " အတိတ်က မင်းပြောခဲ့တဲ့ '${_localMemories.last}' ဆိုတဲ့အကြောင်းကိုလည်း ပစ္စုပ္ပန်မှာ ဆက်ပြီး မှတ်မိနေပါတယ်ဗျာ။";
    }

    await _flutterTts.speak(offlineReply);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("မြန်မာလူသား AI ဦးနှောက်")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isOfflineMode ? Icons.cloud_off : (_isListening ? Icons.graphic_eq : Icons.psychology),
              size: 100,
              color: _isListening ? Colors.green : (_isOfflineMode ? Colors.red : Colors.blue),
            ),
            const SizedBox(height: 30),
            Text(
              _isOfflineMode ? "Offline Memory Brain Mode" : (_isListening ? "စကားပြောနေသည်... (Live)" : "AI Brain အဆင်သင့်ပါ"),
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 50),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(20)),
              onPressed: _toggleLiveSpeak,
              icon: Icon(_isListening ? Icons.stop : Icons.mic),
              label: Text(_isListening ? "စကားပြောရပ်ရန်" : "Live Speak စတင်ရန်"),
            ),
          ],
        ),
      ),
    );
  }
}
