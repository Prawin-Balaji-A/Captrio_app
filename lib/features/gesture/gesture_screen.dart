import 'dart:convert';
import 'dart:typed_data';
import 'package:animate_do/animate_do.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/language_provider.dart';
import '../../core/theme/app_colors.dart';

const String kBackendUrl = 'http://192.168.1.102:8000';

class GestureScreen extends StatefulWidget {
  const GestureScreen({super.key});

  @override
  State<GestureScreen> createState() => _GestureScreenState();
}

class _GestureScreenState extends State<GestureScreen>
    with WidgetsBindingObserver {
  bool _isDetecting = false;
  bool _isCameraPermissionGranted = false;
  bool _isInitializingCamera = true;
  bool _isSwitchingCamera = false;
  int _currentIndex = 2;

  WebSocketChannel? _channel;
  bool _isProcessingFrame = false;
  Uint8List? _processedImageBytes;

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;

  final ScrollController _transcriptScrollController = ScrollController();

  final List<String> _languages = const [
    'English',
    'Hindi',
    'Tamil',
    'Malayalam',
    'Telugu',
  ];

  final List<_NavItem> _navItems = const [
    _NavItem(
      icon: Icons.closed_caption_rounded,
      label: 'Captions',
      route: AppConstants.routeDashboard,
    ),
    _NavItem(
      icon: Icons.upload_file_rounded,
      label: 'Upload',
      route: AppConstants.routeUpload,
    ),
    _NavItem(
      icon: Icons.waving_hand_rounded,
      label: 'Gesture',
      route: AppConstants.routeGesture,
    ),
    _NavItem(
      icon: Icons.people_alt_rounded,
      label: 'Community',
      route: AppConstants.routeCommunity,
    ),
  ];



  String _gestureTranscript =
      'Detected gestures will appear here. Tap the button below to start gesture recognition.';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disconnectWebSocket();
    _transcriptScrollController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      controller.dispose();
      _cameraController = null;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera(_selectedCameraIndex);
    }
  }

  Future<void> _setupCamera() async {
    setState(() {
      _isInitializingCamera = true;
    });

    final status = await Permission.camera.request();

    if (!mounted) return;

    if (!status.isGranted) {
      setState(() {
        _isCameraPermissionGranted = false;
        _isInitializingCamera = false;
      });
      return;
    }

    _isCameraPermissionGranted = true;

    try {
      _cameras = await availableCameras();

      if (_cameras.isEmpty) {
        setState(() {
          _isInitializingCamera = false;
        });
        return;
      }

      final rearIndex = _cameras.indexWhere(
            (camera) => camera.lensDirection == CameraLensDirection.back,
      );

      _selectedCameraIndex = rearIndex >= 0 ? rearIndex : 0;

      await _initializeCamera(_selectedCameraIndex);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isInitializingCamera = false;
      });
    }
  }

  Future<void> _initializeCamera(int cameraIndex) async {
    if (_cameras.isEmpty) return;

    setState(() {
      _isInitializingCamera = true;
    });

    final previousController = _cameraController;

    final controller = CameraController(
      _cameras[cameraIndex],
      ResolutionPreset.low,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await previousController?.dispose();
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _selectedCameraIndex = cameraIndex;
        _isInitializingCamera = false;
      });
    } catch (_) {
      await controller.dispose();

      if (!mounted) return;

      setState(() {
        _cameraController = null;
        _isInitializingCamera = false;
      });
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 || _isSwitchingCamera) return;

    setState(() {
      _isSwitchingCamera = true;
    });

    final nextIndex = (_selectedCameraIndex + 1) % _cameras.length;
    await _initializeCamera(nextIndex);

    if (!mounted) return;

    setState(() {
      _isSwitchingCamera = false;
    });
  }

  void _toggleDetection() {
    if (!_isCameraPermissionGranted || _cameraController == null) return;

    setState(() {
      _isDetecting = !_isDetecting;

      if (_isDetecting) {
        _gestureTranscript = 'Connecting to recognition server...';
        _connectWebSocket();
      } else {
        _disconnectWebSocket();
        _gestureTranscript =
        'Detected gestures will appear here. Tap the button below to start gesture recognition.';
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_transcriptScrollController.hasClients) {
        _transcriptScrollController.animateTo(
          _transcriptScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _connectWebSocket() {
    try {
      final wsUrl = kBackendUrl.replaceFirst('http', 'ws');
      _channel = WebSocketChannel.connect(Uri.parse('$wsUrl/gesture/live'));
      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message as String);
            final String base64Image = data['image'].split(',')[1];
            final String word = data['word'];

            if (!mounted) return;
            setState(() {
              _processedImageBytes = base64Decode(base64Image);
              if (_gestureTranscript == 'Connecting to recognition server...') {
                _gestureTranscript = '';
              }
              if (word.isNotEmpty) {
                if (_gestureTranscript.isEmpty) {
                  _gestureTranscript = word;
                } else if (!_gestureTranscript.endsWith(word)) {
                  _gestureTranscript += ' $word';
                }
                _scrollToBottom();
              }
            });
          } catch (e) {
            debugPrint('Error parsing websocket message: $e');
          }
        },

        onError: (error) {
          if (!mounted) return;
          setState(() {
            _gestureTranscript = 'Connection error. Retrying...';
          });
        },
        onDone: () {
          if (_isDetecting && mounted) {
            Future.delayed(const Duration(seconds: 2), _connectWebSocket);
          }
        },
      );

      _cameraController!.startImageStream((CameraImage image) {
        if (!_isProcessingFrame && _isDetecting && _channel != null) {
          _processFrame(image);
        }
      });
    } catch (e) {
      debugPrint('WebSocket Error: $e');
    }
  }

  void _disconnectWebSocket() {
    if (_cameraController != null && _cameraController!.value.isStreamingImages) {
      try {
        _cameraController!.stopImageStream();
      } catch (_) {}
    }
    _channel?.sink.close();
    _channel = null;
    setState(() {
      _processedImageBytes = null;
    });
  }

  Future<void> _processFrame(CameraImage image) async {
    _isProcessingFrame = true;
    try {
      if (image.format.group == ImageFormatGroup.jpeg) {
        final Uint8List jpegBytes = image.planes[0].bytes;
        final String base64Image = base64Encode(jpegBytes);
        _channel?.sink.add(jsonEncode({
          'type': 'jpeg',
          'data': base64Image,
        }));
      } else if (image.format.group == ImageFormatGroup.bgra8888 || image.format.group == ImageFormatGroup.yuv420) {
        // Send grayscale (Y-plane) to python for processing
        final Uint8List yPlane = image.planes[0].bytes;
        _channel?.sink.add(jsonEncode({
          'type': 'raw_y',
          'width': image.width,
          'height': image.height,
          'data': base64Encode(yPlane),
        }));
      }
    } catch (e) {
      debugPrint('Frame processing error: $e');
    }
    
    // Throttle frames to ~5-10 FPS
    await Future.delayed(const Duration(milliseconds: 150));
    _isProcessingFrame = false;
  }

  Future<void> _openAppSettingsForPermission() async {
    await openAppSettings();
  }

  void _onNavTap(int index) {
    setState(() => _currentIndex = index);
    context.go(_navItems[index].route);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final languageProvider = context.watch<LanguageProvider>();
    final selectedLanguage = languageProvider.selectedLanguage;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spaceLg,
            ),
            child: Column(
              children: [
                _TopBar(
                  user: user,
                  onProfileTap: () => context.go(AppConstants.routeProfile),
                ),
                const SizedBox(height: AppConstants.spaceSm),
                FadeInDown(
                  duration: const Duration(milliseconds: 400),
                  child: _Header(
                    selectedLanguage: selectedLanguage,
                    languages: _languages,
                    onLanguageChanged: (value) {
                      if (value != null) {
                        languageProvider.setLanguage(value);
                      }
                    },
                  ),
                ),
                const SizedBox(height: AppConstants.spaceMd),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(bottom: 120 + bottomInset),
                    child: Column(
                      children: [
                        // 1. Search widget (ISL video lookup)
                        FadeInUp(
                          delay: const Duration(milliseconds: 60),
                          child: const _GestureSearchWidget(),
                        ),
                        const SizedBox(height: AppConstants.spaceMd),

                        // 2. Camera preview — recognition box
                        FadeInUp(
                          delay: const Duration(milliseconds: 80),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 400),
                                    width: 8, height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _isDetecting
                                        ? Colors.greenAccent
                                        : AppColors.textMuted,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _isDetecting ? 'Recognition Active' : 'Recognition Off',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _isDetecting
                                        ? Colors.greenAccent
                                        : AppColors.textMuted,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ]),
                              ),
                              _CameraPreviewCard(
                                  isDetecting: _isDetecting,
                                  isInitializing: _isInitializingCamera,
                                  hasPermission: _isCameraPermissionGranted,
                                  controller: _cameraController,
                                  onSwitchCamera: _switchCamera,
                                  onOpenSettings: _openAppSettingsForPermission,
                                  canSwitchCamera: _cameras.length > 1,
                                  isSwitchingCamera: _isSwitchingCamera,
                                  processedImageBytes: _processedImageBytes,
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppConstants.spaceMd),

                        // 3. Caption box — sentence builder
                        FadeInUp(
                          delay: const Duration(milliseconds: 160),
                          child: Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(minHeight: 80),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D1120),
                              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                              border: Border.all(
                                color: _isDetecting
                                  ? AppColors.primary.withValues(alpha: 0.5)
                                  : AppColors.border,
                                width: _isDetecting ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Icon(Icons.closed_caption_rounded,
                                    size: 13, color: AppColors.primary),
                                  const SizedBox(width: 5),
                                  const Text('Captions',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                      letterSpacing: 0.6)),
                                ]),
                                const SizedBox(height: 8),
                                SingleChildScrollView(
                                  controller: _transcriptScrollController,
                                  child: Text(
                                    _gestureTranscript,
                                    style: TextStyle(
                                      fontSize: 15,
                                      height: 1.6,
                                      color: _isDetecting
                                        ? Colors.white
                                        : AppColors.textMuted,
                                      fontWeight: _isDetecting
                                        ? FontWeight.w500
                                        : FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: AppConstants.spaceMd),

                        // 4. Detect button
                        FadeInUp(
                          delay: const Duration(milliseconds: 220),
                          child: _DetectButton(
                            isDetecting: _isDetecting,
                            isEnabled: _isCameraPermissionGranted &&
                                _cameraController != null &&
                                _cameraController!.value.isInitialized,
                            onTap: _toggleDetection,
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
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottomInset),
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
            children: List.generate(
              _navItems.length,
                  (i) => Expanded(
                child: _NavBarItem(
                  item: _navItems[i],
                  isActive: _currentIndex == i,
                  onTap: () => _onNavTap(i),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final dynamic user;
  final VoidCallback onProfileTap;

  const _TopBar({
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
              decoration: const BoxDecoration(
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

class _Header extends StatelessWidget {
  final String selectedLanguage;
  final List<String> languages;
  final ValueChanged<String?> onLanguageChanged;

  const _Header({
    required this.selectedLanguage,
    required this.languages,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gesture Detection',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppConstants.spaceMd),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(AppConstants.radiusFull),
            border: Border.all(color: AppColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedLanguage,
              dropdownColor: AppColors.surface2,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textSecondary,
              ),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              items: languages
                  .map(
                    (lang) => DropdownMenuItem<String>(
                  value: lang,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.language_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(lang),
                    ],
                  ),
                ),
              )
                  .toList(),
              onChanged: onLanguageChanged,
            ),
          ),
        ),
      ],
    );
  }
}

class _CameraPreviewCard extends StatelessWidget {
  final bool isDetecting;
  final bool isInitializing;
  final bool hasPermission;
  final bool canSwitchCamera;
  final bool isSwitchingCamera;
  final CameraController? controller;
  final VoidCallback onSwitchCamera;
  final VoidCallback onOpenSettings;
  final Uint8List? processedImageBytes;

  const _CameraPreviewCard({
    required this.isDetecting,
    required this.isInitializing,
    required this.hasPermission,
    required this.canSwitchCamera,
    required this.isSwitchingCamera,
    required this.controller,
    required this.onSwitchCamera,
    required this.onOpenSettings,
    this.processedImageBytes,
  });

  @override
  Widget build(BuildContext context) {
    final isReady = controller != null && controller!.value.isInitialized;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Camera Preview',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppConstants.spaceMd),
          Center(
            child: Container(
              width: 220,
              height: 390,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppConstants.radiusXl),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.surface2,
                    AppColors.surface3,
                  ],
                ),
                border: Border.all(
                  color: isDetecting
                      ? AppColors.primary.withValues(alpha: 0.75)
                      : AppColors.border,
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDetecting
                        ? AppColors.primary.withValues(alpha: 0.18)
                        : Colors.black.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusXl),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _buildPreviewContent(isReady),
                    ),
                    Positioned(
                      top: 14,
                      left: 14,
                      right: 14,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isDetecting
                                  ? AppColors.primary.withValues(alpha: 0.18)
                                  : AppColors.surface1.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusFull,
                              ),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.fiber_manual_record_rounded,
                                  size: 12,
                                  color: isDetecting
                                      ? AppColors.primary
                                      : AppColors.textMuted,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isDetecting ? 'Detecting' : 'Standby',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: canSwitchCamera && !isSwitchingCamera
                                ? onSwitchCamera
                                : null,
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: AppColors.surface1.withValues(alpha: 0.9),
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Icon(
                                isSwitchingCamera
                                    ? Icons.hourglass_top_rounded
                                    : Icons.cameraswitch_rounded,
                                size: 18,
                                color: canSwitchCamera
                                    ? AppColors.textSecondary
                                    : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isReady && isDetecting)
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 72,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [].map((text) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.28),
                                borderRadius: BorderRadius.circular(
                                  AppConstants.radiusFull,
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.10),
                                ),
                              ),
                              child: Text(
                                text,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    Positioned(
                      bottom: 18,
                      left: 18,
                      right: 18,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.24),
                          borderRadius:
                          BorderRadius.circular(AppConstants.radiusLg),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Text(
                          !hasPermission
                              ? 'Camera permission required'
                              : isInitializing
                              ? 'Initializing camera...'
                              : isReady
                              ? 'Live camera preview active'
                              : 'Camera unavailable',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewContent(bool isReady) {
    if (!hasPermission) {
      return _PermissionView(onOpenSettings: onOpenSettings);
    }

    if (isInitializing) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
        ),
      );
    }

    if (!isReady) {
      return const _CameraUnavailableView();
    }

    return Stack(
      children: [
        Positioned.fill(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: 220,
              height: 220 / controller!.value.aspectRatio,
              child: (isDetecting && processedImageBytes != null)
                  ? Image.memory(
                      processedImageBytes!,
                      width: 220,
                      height: 220 / controller!.value.aspectRatio,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    )
                  : CameraPreview(controller!),
            ),
          ),
        ),
        if (isDetecting && processedImageBytes == null)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _CameraGuidePainter(),
              ),
            ),
          ),
      ],
    );
  }
}

class _PermissionView extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const _PermissionView({
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface2,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppConstants.spaceMd),
              const Text(
                'Camera permission needed',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Allow camera access to start live gesture detection.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppConstants.spaceMd),
              GestureDetector(
                onTap: onOpenSettings,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius:
                    BorderRadius.circular(AppConstants.radiusFull),
                  ),
                  child: const Text(
                    'Open Settings',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraUnavailableView extends StatelessWidget {
  const _CameraUnavailableView();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface2,
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(AppConstants.spaceLg),
          child: Text(
            'Unable to load camera preview.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraGuidePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final guidePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.65)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1;

    const padding = 38.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        padding,
        88,
        size.width - (padding * 2),
        size.height - 180,
      ),
      const Radius.circular(24),
    );

    canvas.drawRRect(rect, guidePaint);

    final thirdWidth = size.width / 3;
    final thirdHeight = size.height / 4;

    for (int i = 1; i < 3; i++) {
      final dx = thirdWidth * i;
      canvas.drawLine(
        Offset(dx, 0),
        Offset(dx, size.height),
        gridPaint,
      );
    }

    for (int i = 1; i < 4; i++) {
      final dy = thirdHeight * i;
      canvas.drawLine(
        Offset(0, dy),
        Offset(size.width, dy),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}



class _DetectButton extends StatelessWidget {
  final bool isDetecting;
  final bool isEnabled;
  final VoidCallback onTap;

  const _DetectButton({
    required this.isDetecting,
    required this.isEnabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isEnabled ? 1 : 0.55,
      child: GestureDetector(
        onTap: isEnabled ? onTap : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: isDetecting
                ? const LinearGradient(
              colors: [Color(0xFFFF6A6A), Color(0xFFFF4D88)],
            )
                : AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(AppConstants.radiusLg),
            boxShadow: [
              BoxShadow(
                color: (isDetecting
                    ? const Color(0xFFFF4D88)
                    : AppColors.primary)
                    .withValues(alpha: 0.24),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Text(
              isEnabled
                  ? (isDetecting
                  ? 'Stop Detection'
                  : 'Start Gesture Detection')
                  : 'Camera not ready',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  const _NavBarItem({
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

class _NavItem {
  final IconData icon;
  final String label;
  final String route;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
  });
}

class _GestureSearchWidget extends StatefulWidget {
  const _GestureSearchWidget();

  @override
  State<_GestureSearchWidget> createState() => _GestureSearchWidgetState();
}

class _GestureSearchWidgetState extends State<_GestureSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  VideoPlayerController? _videoPlayerController;
  bool _isLoading = false;
  String _error = '';
  List<String> _suggestions = [];
  List<String> _allPhrases = [];
  String _matchedPhrase = '';

  @override
  void initState() {
    super.initState();
    _loadAllPhrases();
  }

  Future<void> _loadAllPhrases() async {
    try {
      final res = await http.get(Uri.parse('$kBackendUrl/gesture/phrases'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          setState(() {
            _allPhrases = List<String>.from(data['phrases'] ?? []);
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _searchGesture() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = '';
      _suggestions = [];
      _matchedPhrase = '';
    });

    // Dispose old controller
    final oldController = _videoPlayerController;
    _videoPlayerController = null;
    await oldController?.dispose();

    try {
      final url = Uri.parse('$kBackendUrl/gesture/search');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': query}),
      ).timeout(const Duration(seconds: 15));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final videoFile = data['video'] as String;
          final videoUrl = '$kBackendUrl/gifs/$videoFile';

          final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
          await controller.initialize();

          if (!mounted) {
            controller.dispose();
            return;
          }

          await controller.setLooping(true);
          await controller.play();

          setState(() {
            _videoPlayerController = controller;
            _matchedPhrase = videoFile.replaceAll('.webm', '').replaceAll('-', ' ');
            _isLoading = false;
          });
        } else {
          final sug = data['suggestions'];
          setState(() {
            _error = data['message'] ?? 'No gesture found.';
            _suggestions = sug != null ? List<String>.from(sug) : [];
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Server error (${response.statusCode}).';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not connect. Make sure backend is running.';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        Row(
          children: [
            Expanded(
              child: Autocomplete<String>(
                optionsBuilder: (TextEditingValue v) {
                  if (v.text.isEmpty) return const [];
                  return _allPhrases.where(
                    (p) => p.toLowerCase().contains(v.text.toLowerCase()),
                  );
                },
                onSelected: (String phrase) {
                  _searchController.text = phrase;
                  _searchGesture();
                },
                fieldViewBuilder: (ctx, ctrl, focusNode, onFieldSubmitted) {
                  // Keep our controller in sync
                  ctrl.text = _searchController.text;
                  ctrl.addListener(() => _searchController.text = ctrl.text);
                  return TextField(
                    controller: ctrl,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      hintText: 'e.g. help me, thank you, sorry...',
                      hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.surface1,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                      ),
                    ),
                    onSubmitted: (_) => _searchGesture(),
                  );
                },
              ),
            ),
            const SizedBox(width: AppConstants.spaceSm),
            GestureDetector(
              onTap: _isLoading ? null : _searchGesture,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.search_rounded, color: Colors.white),
              ),
            ),
          ],
        ),

        // Error + suggestions
        if (_error.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.info_outline, color: AppColors.danger, size: 15),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_error,
                    style: const TextStyle(color: AppColors.danger, fontSize: 13))),
                ]),
                if (_suggestions.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Did you mean:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: _suggestions.map((s) => GestureDetector(
                      onTap: () {
                        _searchController.text = s;
                        _searchGesture();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Text(s, style: const TextStyle(
                          color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],

        // Video player
        if (_videoPlayerController != null && _videoPlayerController!.value.isInitialized) ...[
          const SizedBox(height: AppConstants.spaceMd),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              boxShadow: [BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.1),
                blurRadius: 16,
              )],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  AspectRatio(
                    aspectRatio: _videoPlayerController!.value.aspectRatio,
                    child: VideoPlayer(_videoPlayerController!),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    color: Colors.black54,
                    child: Text(
                      _matchedPhrase.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}