import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';
import 'package:record/record.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/language_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../services/sos_service.dart';

class Lang {
  final String label;
  final String speechCode;
  final String transCode;

  const Lang(this.label, this.speechCode, this.transCode);
}

const List<Lang> kLanguages = [
  Lang('English', 'en-IN', 'english'),
  Lang('Hindi', 'hi-IN', 'hindi'),
  Lang('Tamil', 'ta-IN', 'tamil'),
  Lang('Telugu', 'te-IN', 'telugu'),
  Lang('Malayalam', 'ml-IN', 'malayalam'),
];

const String kBackendUrl = 'http://192.168.1.102:8000';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  final AudioRecorder recorder = AudioRecorder();
  final ScrollController captionScrollController = ScrollController();

  int currentIndex = 0;
  bool micActive = false;
  bool showSosOptions = false;
  bool keepListening = false;
  bool isTranslating = false;
  bool loopBusy = false;
  Timer? recordingLoopTimer;

  Lang sourceLang = kLanguages[0];
  String captionText =
      'Select the speaking language and tap the mic. Only translated output will appear here.';
  String lastTranslatedText = '';

  final List<NavItem> navItems = const [
    NavItem(
      icon: Icons.closed_caption_rounded,
      label: 'Captions',
      route: AppConstants.routeDashboard,
    ),
    NavItem(
      icon: Icons.upload_file_rounded,
      label: 'Upload',
      route: AppConstants.routeUpload,
    ),
    NavItem(
      icon: Icons.waving_hand_rounded,
      label: 'Gesture',
      route: AppConstants.routeGesture,
    ),
    NavItem(
      icon: Icons.people_alt_rounded,
      label: 'Community',
      route: AppConstants.routeCommunity,
    ),
  ];

  @override
  void dispose() {
    recordingLoopTimer?.cancel();
    captionScrollController.dispose();
    recorder.dispose();
    super.dispose();
  }

  Lang preferredTargetLang(String preferredLanguage) {
    return kLanguages.firstWhere(
          (lang) => lang.label.toLowerCase() == preferredLanguage.toLowerCase(),
      orElse: () => kLanguages[0],
    );
  }

  Future<bool> checkBackendHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$kBackendUrl/health'))
          .timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> toggleMic() async {
    final hasPermission = await recorder.hasPermission();
    if (!hasPermission) {
      if (!mounted) return;
      setState(() {
        captionText = 'Microphone permission is required to continue.';
      });
      return;
    }

    if (!keepListening) {
      final backendOk = await checkBackendHealth();
      if (!backendOk) {
        if (!mounted) return;
        setState(() {
          captionText =
          'Backend not reachable. Start FastAPI and check $kBackendUrl.';
        });
        return;
      }

      keepListening = true;
      if (!mounted) return;
      setState(() {
        micActive = true;
        captionText = 'Listening in ${sourceLang.label}...';
      });
      await startLoop();
    } else {
      keepListening = false;
      recordingLoopTimer?.cancel();

      try {
        if (await recorder.isRecording()) {
          await recorder.stop();
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        micActive = false;
        isTranslating = false;
        if (lastTranslatedText.trim().isEmpty) {
          captionText = 'Microphone stopped.';
        }
      });
    }
  }

  Future<void> startLoop() async {
    await captureAndTranslateChunk();

    recordingLoopTimer?.cancel();
    recordingLoopTimer = Timer.periodic(const Duration(seconds: 4), (_) async {
      if (!keepListening || loopBusy) return;
      await captureAndTranslateChunk();
    });
  }

  Future<void> captureAndTranslateChunk() async {
    if (loopBusy || !keepListening) return;

    loopBusy = true;

    final preferredLanguage =
        context.read<LanguageProvider>().selectedLanguage;
    final targetLang = preferredTargetLang(preferredLanguage);

    File? audioFile;

    try {
      if (!mounted) return;

      setState(() {
        isTranslating = true;
      });

      final dir = await Directory.systemTemp.createTemp('captrio_audio_');
      final path =
          '${dir.path}/chunk_${DateTime.now().millisecondsSinceEpoch}.wav';

      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 128000,
        ),
        path: path,
      );

      await Future.delayed(const Duration(seconds: 3));

      if (!keepListening) {
        try {
          await recorder.stop();
        } catch (_) {}
        return;
      }

      final recordedPath = await recorder.stop();
      if (recordedPath == null || recordedPath.isEmpty) {
        throw Exception('Recording failed');
      }

      audioFile = File(recordedPath);

      if (!await audioFile.exists()) {
        throw Exception('Recorded audio file not found');
      }

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$kBackendUrl/translate-audio'),
      );

      request.fields['source_language'] = sourceLang.transCode;
      request.fields['target_language'] = targetLang.transCode;

      request.files.add(
        await http.MultipartFile.fromPath(
          'audio',
          audioFile.path,
          contentType: MediaType('audio', 'wav'),
        ),
      );

      final streamedResponse =
      await request.send().timeout(const Duration(seconds: 20));
      final response = await http.Response.fromStream(streamedResponse);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(response.body);

        if (body is! Map<String, dynamic>) {
          setState(() {
            captionText = 'Invalid backend response format.';
          });
          return;
        }

        final success = body['success'] == true;
        final translatedText =
        (body['translated_text'] ?? '').toString().trim();
        final errorText = (body['error'] ?? '').toString().trim();

        setState(() {
          if (success && translatedText.isNotEmpty) {
            lastTranslatedText = translatedText;
            captionText = translatedText;
          } else if (errorText.isNotEmpty) {
            captionText = errorText;
          } else {
            captionText = 'No translated output received.';
          }
        });
      } else {
        setState(() {
          captionText = 'Backend error: ${response.statusCode}';
        });
      }

      scrollTranscriptToBottom();
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        captionText = 'Request timed out. Check backend speed or connection.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        captionText = 'Error: $e';
      });
    } finally {
      try {
        if (audioFile != null && await audioFile.exists()) {
          await audioFile.delete();
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          isTranslating = false;
          micActive = keepListening;
        });
      }

      loopBusy = false;
    }
  }

  void scrollTranscriptToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (captionScrollController.hasClients) {
        captionScrollController.animateTo(
          captionScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void onNavTap(int index) {
    setState(() => currentIndex = index);
    context.go(navItems[index].route);
  }

  void toggleSos() {
    setState(() => showSosOptions = !showSosOptions);
  }

  Future<void> _sendEmergencySos() async {
    HapticFeedback.heavyImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Sending SOS...'),
        backgroundColor: AppColors.surface3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
      ),
    );

    try {
      final contacts = await SosService().getContacts();
      if (contacts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No emergency contacts configured!'),
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
            ),
          );
        }
        return;
      }

      String message = AppConstants.sosDefaultMessage;

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
          message += '\nLocation: https://maps.google.com/?q=${position.latitude},${position.longitude}';
        }
      }

      var permissionStatus = await Permission.sms.status;
      if (!permissionStatus.isGranted) {
        permissionStatus = await Permission.sms.request();
      }

      if (permissionStatus.isGranted) {
        final telephony = Telephony.instance;
        for (var contact in contacts) {
          telephony.sendSms(
            to: contact.phoneNumber,
            message: message,
          );
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Emergency SOS sent successfully!'),
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('SMS permission denied. Cannot send SOS.'),
              backgroundColor: AppColors.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppConstants.radiusMd)),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('SOS Error: $e');
    }
  }

  void onWordTap(String word) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => WordMeaningDialog(word: word),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final preferredLanguage =
        context.watch<LanguageProvider>().selectedLanguage;
    final targetLang = preferredTargetLang(preferredLanguage);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    final navBottom = 12 + bottomInset;
    final micBottom = 34 + bottomInset;
    final sosBottom = 92 + bottomInset;
    final contentBottomSpace = 112 + bottomInset;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: Stack(
          children: [
            Positioned(
              top: -60,
              right: -40,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.06),
                ),
              ),
            ),
            Positioned(
              bottom: 140,
              left: -80,
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.secondary.withValues(alpha: 0.05),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spaceLg,
                ),
                child: Column(
                  children: [
                    LiveTopBar(
                      user: user,
                      onProfileTap: () => context.go(AppConstants.routeProfile),
                    ),
                    const SizedBox(height: AppConstants.spaceSm),
                    FadeInDown(
                      duration: const Duration(milliseconds: 400),
                      child: CompactHeader(
                        sourceLang: sourceLang,
                        targetLang: targetLang,
                        languages: kLanguages,
                        isTranslating: isTranslating,
                        micActive: micActive,
                        onSourceChanged: (lang) {
                          if (micActive) return;
                          setState(() => sourceLang = lang);
                        },
                      ),
                    ),
                    const SizedBox(height: AppConstants.spaceMd),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: contentBottomSpace),
                        child: FadeInUp(
                          delay: const Duration(milliseconds: 100),
                          duration: const Duration(milliseconds: 450),
                          child: LiveTranscriptCard(
                            text: captionText,
                            micActive: micActive,
                            isTranslating: isTranslating,
                            scrollController: captionScrollController,
                            onWordTap: onWordTap,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (showSosOptions)
              SosOverlay(
                bottomOffset: 120 + bottomInset,
                onCancel: () => setState(() => showSosOptions = false),
                onConfigure: () {
                  setState(() => showSosOptions = false);
                  context.go(AppConstants.routeSosConfigure);
                },
                onSend: () {
                  setState(() => showSosOptions = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('SOS sent successfully'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.surface3,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(AppConstants.radiusMd),
                      ),
                    ),
                  );
                },
              ),
            Positioned(
              right: 22,
              bottom: sosBottom,
              child: SosFab(
                onTap: toggleSos,
                onLongPress: _sendEmergencySos,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SizedBox(
                height: 170 + bottomInset,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: navBottom,
                      child: Container(
                        height: 76,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.navBackground.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: AppColors.border.withValues(alpha: 0.45),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.22),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            ...List.generate(
                              2,
                                  (i) => Expanded(
                                child: NavBarItem(
                                  item: navItems[i],
                                  isActive: currentIndex == i,
                                  onTap: () => onNavTap(i),
                                ),
                              ),
                            ),
                            const SizedBox(width: 82),
                            ...List.generate(
                              2,
                                  (i) => Expanded(
                                child: NavBarItem(
                                  item: navItems[i + 2],
                                  isActive: currentIndex == i + 2,
                                  onTap: () => onNavTap(i + 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: micBottom,
                      child: MicFab(
                        isActive: micActive,
                        onTap: toggleMic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LiveTopBar extends StatelessWidget {
  final dynamic user;
  final VoidCallback onProfileTap;

  const LiveTopBar({
    super.key,
    required this.user,
    required this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppConstants.spaceMd,
        bottom: AppConstants.spaceSm,
      ),
      child: Row(
        children: [
          Expanded(
            child: ShaderMask(
              shaderCallback: (bounds) =>
                  AppColors.primaryGradient.createShader(bounds),
              child: const Text(
                'CAPTRIO',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spaceSm),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: AppColors.textSecondary,
              size: 21,
            ),
          ),
          const SizedBox(width: AppConstants.spaceSm),
          GestureDetector(
            onTap: onProfileTap,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  user?.name != null && user.name.toString().isNotEmpty
                      ? user.name.toString()[0].toUpperCase()
                      : 'P',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CompactHeader extends StatelessWidget {
  final Lang sourceLang;
  final Lang targetLang;
  final List<Lang> languages;
  final bool isTranslating;
  final bool micActive;
  final ValueChanged<Lang> onSourceChanged;

  const CompactHeader({
    super.key,
    required this.sourceLang,
    required this.targetLang,
    required this.languages,
    required this.isTranslating,
    required this.micActive,
    required this.onSourceChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Live Captioning',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            if (isTranslating) ...[
              const SizedBox(width: AppConstants.spaceSm),
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Translating...',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppConstants.spaceMd),
        Row(
          children: [
            Expanded(
              child: LangDropdown(
                label: 'Source language',
                selected: sourceLang,
                languages: languages,
                enabled: !micActive,
                onChanged: onSourceChanged,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spaceSm,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.primary,
                size: 18,
              ),
            ),
            Expanded(
              child: ReadOnlyLangBox(
                label: 'Target language',
                value: targetLang.label,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppConstants.spaceSm),
        const Text(
          'Target language comes from your preferred language in profile settings.',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class LangDropdown extends StatelessWidget {
  final String label;
  final Lang selected;
  final List<Lang> languages;
  final bool enabled;
  final ValueChanged<Lang> onChanged;

  const LangDropdown({
    super.key,
    required this.label,
    required this.selected,
    required this.languages,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              border: Border.all(color: AppColors.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Lang>(
                value: selected,
                isExpanded: true,
                dropdownColor: AppColors.surface2,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary,
                  size: 18,
                ),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                items: languages
                    .map(
                      (l) => DropdownMenuItem<Lang>(
                    value: l,
                    child: Text(l.label),
                  ),
                )
                    .toList(),
                onChanged: enabled
                    ? (val) {
                  if (val != null) onChanged(val);
                }
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ReadOnlyLangBox extends StatelessWidget {
  final String label;
  final String value;

  const ReadOnlyLangBox({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppConstants.radiusFull),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.language_rounded,
                color: AppColors.primary,
                size: 15,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class LiveTranscriptCard extends StatelessWidget {
  final String text;
  final bool micActive;
  final bool isTranslating;
  final ScrollController scrollController;
  final void Function(String word) onWordTap;

  const LiveTranscriptCard({
    super.key,
    required this.text,
    required this.micActive,
    required this.isTranslating,
    required this.scrollController,
    required this.onWordTap,
  });

  List<String> splitWordsPreserveNewlines(String input) {
    final result = <String>[];
    final lines = input.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final words = lines[i].split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
      result.addAll(words);
      if (i != lines.length - 1) {
        result.add('\n');
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final pieces = splitWordsPreserveNewlines(text);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        border: Border.all(
          color: micActive
              ? AppColors.primary.withValues(alpha: 0.35)
              : AppColors.border,
        ),
        boxShadow: [
          if (micActive)
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.10),
              blurRadius: 22,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              micActive
                  ? (isTranslating ? 'Processing...' : 'Listening now')
                  : 'Waiting for audio',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: micActive ? AppColors.primary : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppConstants.spaceMd),
            Expanded(
              child: Scrollbar(
                controller: scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: scrollController,
                  physics: const BouncingScrollPhysics(),
                  child: Wrap(
                    alignment: WrapAlignment.start,
                    runSpacing: 6,
                    spacing: 2,
                    children: pieces.map((piece) {
                      if (piece == '\n') {
                        return const SizedBox(width: double.infinity, height: 0);
                      }

                      final cleanWord = piece.replaceAll(
                        RegExp(r'[^\w]', unicode: true),
                        '',
                      );

                      return SelectableText(
                        '$piece ',
                        onTap: cleanWord.isEmpty
                            ? null
                            : () => onWordTap(cleanWord),
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.45,
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NavBarItem extends StatelessWidget {
  final NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const NavBarItem({
    super.key,
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            item.icon,
            size: 22,
            color: isActive ? AppColors.navActive : AppColors.navInactive,
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? AppColors.navActive : AppColors.navInactive,
            ),
          ),
          const SizedBox(height: 3),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: isActive ? 18 : 0,
            height: 2.5,
            decoration: BoxDecoration(
              color: AppColors.navActive,
              borderRadius: BorderRadius.circular(AppConstants.radiusFull),
            ),
          ),
        ],
      ),
    );
  }
}

class MicFab extends StatelessWidget {
  final bool isActive;
  final Future<void> Function() onTap;

  const MicFab({
    super.key,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isActive
              ? AppColors.dangerGradient
              : AppColors.primaryGradient,
          boxShadow: [
            BoxShadow(
              color: isActive
                  ? AppColors.danger.withValues(alpha: 0.38)
                  : AppColors.primary.withValues(alpha: 0.38),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          isActive ? Icons.mic_rounded : Icons.mic_none_rounded,
          color: Colors.white,
          size: 30,
        ),
      ),
    );
  }
}

class SosFab extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const SosFab({
    super.key,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.danger.withValues(alpha: 0.16),
          border: Border.all(color: AppColors.danger, width: 1.6),
          boxShadow: [
            BoxShadow(
              color: AppColors.danger.withValues(alpha: 0.22),
              blurRadius: 18,
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'SOS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.danger,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }
}

class SosOverlay extends StatelessWidget {
  final double bottomOffset;
  final VoidCallback onCancel;
  final VoidCallback onConfigure;
  final VoidCallback onSend;

  const SosOverlay({
    super.key,
    required this.bottomOffset,
    required this.onCancel,
    required this.onConfigure,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCancel,
      child: Container(
        color: Colors.black.withValues(alpha: 0.58),
        child: Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: EdgeInsets.only(
              right: AppConstants.spaceLg,
              bottom: bottomOffset,
            ),
            child: FadeInUp(
              duration: const Duration(milliseconds: 220),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SosOptionButton(
                    label: 'Configure',
                    icon: Icons.settings_rounded,
                    color: AppColors.secondary,
                    onTap: onConfigure,
                  ),
                  const SizedBox(height: AppConstants.spaceSm),
                  SosOptionButton(
                    label: 'Cancel',
                    icon: Icons.close_rounded,
                    color: AppColors.textMuted,
                    onTap: onCancel,
                  ),
                  const SizedBox(height: AppConstants.spaceSm),
                  GestureDetector(
                    onLongPress: onSend,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spaceLg,
                        vertical: AppConstants.spaceMd,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.dangerGradient,
                        borderRadius:
                        BorderRadius.circular(AppConstants.radiusFull),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          SizedBox(width: AppConstants.spaceSm),
                          Text(
                            'Hold 2s to Send',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SosOptionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const SosOptionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spaceLg,
          vertical: AppConstants.spaceMd,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(AppConstants.radiusFull),
          border: Border.all(color: color.withValues(alpha: 0.26)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: AppConstants.spaceSm),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WordMeaningDialog extends StatefulWidget {
  final String word;

  const WordMeaningDialog({
    super.key,
    required this.word,
  });

  @override
  State<WordMeaningDialog> createState() => _WordMeaningDialogState();
}

class _WordMeaningDialogState extends State<WordMeaningDialog> {
  bool _isLoading = true;
  String _meaning = '';
  List<String> _allSynonyms = [];
  String _imageUrl = '';
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchMeaning();
  }

  Future<void> _fetchMeaning() async {
    try {
      final langProvider = context.read<LanguageProvider>();
      final preferredLanguage = langProvider.selectedLanguage;
      final langStr = preferredLanguage.toLowerCase();
      
      final url = Uri.parse('$kBackendUrl/dictionary/$langStr/${widget.word}');
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _meaning = data['meaning'] ?? '';
          if (data['all_synonyms'] != null) {
            _allSynonyms = List<String>.from(data['all_synonyms']);
          }
          _imageUrl = data['image_url'] ?? '';
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load meaning.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error connecting to server.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 60),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          color: const Color(0xFF0E1320),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: _isLoading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 36, horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 28, height: 28,
                    child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2.5),
                  ),
                  SizedBox(height: 12),
                  Text('Looking up...', style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image (compact)
                if (_imageUrl.isNotEmpty && !_imageUrl.contains('dummyimage.com'))
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: Image.network(
                      _imageUrl,
                      height: 110,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  )
                else
                  Container(
                    height: 54,
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 26),
                  ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Word
                      Text(
                        widget.word,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 6),

                      if (_error.isNotEmpty)
                        Text(_error,
                          style: const TextStyle(color: AppColors.danger, fontSize: 12))
                      else ...[
                        // Meaning
                        Text(
                          _meaning,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFFB0BAD0),
                            height: 1.45,
                          ),
                        ),

                        // Synonyms chips
                        if (_allSynonyms.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text('Related',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              letterSpacing: 0.8,
                            )),
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            children: _allSynonyms.take(4).map((s) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.13),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.3)),
                              ),
                              child: Text(s, style: const TextStyle(
                                fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500)),
                            )).toList(),
                          ),
                        ],
                      ],

                      const SizedBox(height: 10),
                      // Close button
                      SizedBox(
                        width: double.infinity,
                        height: 34,
                        child: TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Close',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                  ),
                ),
              ],
            ),
      ),
    );
  }
}

class NavItem {
  final IconData icon;
  final String label;
  final String route;

  const NavItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}