import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:animate_do/animate_do.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../core/constants/app_constants.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/language_provider.dart';
import '../../core/theme/app_colors.dart';

const String kBackendUrl = 'http://192.168.1.102:8000';

enum MediaMode { none, audio, video }
enum UploadSource { local, youtube }
enum LocalPickType { audio, video }

class CaptionChunk {
  final double start;
  final double end;
  final String sourceText;
  final String translatedText;

  const CaptionChunk({
    required this.start,
    required this.end,
    required this.sourceText,
    required this.translatedText,
  });

  factory CaptionChunk.fromJson(Map<String, dynamic> json) {
    return CaptionChunk(
      start: (json['start'] ?? 0).toDouble(),
      end: (json['end'] ?? 0).toDouble(),
      sourceText: (json['source_text'] ?? '').toString(),
      translatedText: (json['translated_text'] ?? '').toString(),
    );
  }
}

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  VideoPlayerController? _videoController;
  YoutubePlayerController? _youtubePlayerController;

  final ScrollController _captionScrollController = ScrollController();
  final TextEditingController _youtubeController = TextEditingController();

  UploadSource _source = UploadSource.local;
  MediaMode _mediaMode = MediaMode.none;

  String? _fileName;
  String? _localFilePath;
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isYoutubeMode = false;
  bool _isUploadingToBackend = false;
  bool _isPollingCaptions = false;
  bool _autoStarted = false;

  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  Timer? _youtubePositionTimer;
  Timer? _pollingTimer;
  WebSocket? _mediaWebSocket;

  String _captionText =
      'Choose a source, prepare the media, and start live captioning.';
  String _activeCaption = '';
  String? _sessionId;
  String _jobStatus = 'idle';

  final List<CaptionChunk> _captionChunks = [];
  final Set<String> _chunkKeys = {};

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

  int _currentIndex = 1;

  @override
  void initState() {
    super.initState();
    _listenAudioStreams();
  }

  void _listenAudioStreams() {
    _audioPlayer.positionStream.listen((position) {
      if (!mounted || _mediaMode != MediaMode.audio) return;
      setState(() => _currentPosition = position);
      _updateActiveCaptionByTime();
    });

    _audioPlayer.durationStream.listen((duration) {
      if (!mounted || _mediaMode != MediaMode.audio) return;
      setState(() => _totalDuration = duration ?? Duration.zero);
    });

    _audioPlayer.playerStateStream.listen((state) {
      if (!mounted || _mediaMode != MediaMode.audio) return;

      setState(() => _isPlaying = state.playing);

      if (state.processingState == ProcessingState.completed) {
        setState(() {
          _isPlaying = false;
          _currentPosition = Duration.zero;
        });
      }
    });
  }

  void _startYoutubeTracking() {
    _youtubePositionTimer?.cancel();

    _youtubePositionTimer =
        Timer.periodic(const Duration(milliseconds: 500), (timer) async {
          if (!mounted || !_isYoutubeMode || _youtubePlayerController == null) {
            timer.cancel();
            return;
          }

          try {
            final currentSeconds = await _youtubePlayerController!.currentTime;
            final metaData = _youtubePlayerController!.metadata;

            if (!mounted) return;

            setState(() {
              _currentPosition = Duration(seconds: currentSeconds.floor());
              _totalDuration = metaData.duration;
            });

            _updateActiveCaptionByTime();
          } catch (_) {}
        });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _youtubePositionTimer?.cancel();
    _mediaWebSocket?.close();
    _audioPlayer.dispose();
    _videoController?.dispose();
    _youtubePlayerController?.close();
    _captionScrollController.dispose();
    _youtubeController.dispose();
    super.dispose();
  }

  Future<void> _showPickTypeDialog() async {
    final result = await showDialog<LocalPickType>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.60),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(AppConstants.spaceLg),
            decoration: BoxDecoration(
              color: AppColors.surface3,
              borderRadius: BorderRadius.circular(AppConstants.radiusXl),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Choose Media Type',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppConstants.spaceSm),
                const Text(
                  'Tap to choose audio or video',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppConstants.spaceLg),
                Row(
                  children: [
                    Expanded(
                      child: _DialogPickCard(
                        icon: Icons.audiotrack_rounded,
                        label: 'Audio',
                        onTap: () => Navigator.pop(context, LocalPickType.audio),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spaceMd),
                    Expanded(
                      child: _DialogPickCard(
                        icon: Icons.video_library_rounded,
                        label: 'Video',
                        onTap: () => Navigator.pop(context, LocalPickType.video),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result != null) {
      await _pickLocalMedia(result);
    }
  }

  Future<void> _pickLocalMedia(LocalPickType type) async {
    try {
      setState(() => _isLoading = true);

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: type == LocalPickType.audio
            ? ['mp3', 'wav', 'm4a', 'aac', 'ogg']
            : ['mp4', 'mov', 'mkv', 'avi', 'webm'],
      );

      if (result == null || result.files.single.path == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final path = result.files.single.path!;
      final name = result.files.single.name;

      await _stopAllPlayback(resetCaption: true);

      _localFilePath = path;
      _fileName = name;
      _source = UploadSource.local;
      _isYoutubeMode = false;
      _sessionId = null;
      _jobStatus = 'idle';
      _autoStarted = false;
      _captionChunks.clear();
      _chunkKeys.clear();
      _activeCaption = '';
      _currentPosition = Duration.zero;
      _totalDuration = Duration.zero;

      if (type == LocalPickType.audio) {
        _mediaMode = MediaMode.audio;
        await _audioPlayer.setFilePath(path);
        _totalDuration = _audioPlayer.duration ?? Duration.zero;
      } else {
        _mediaMode = MediaMode.video;
        _videoController?.dispose();
        _videoController = VideoPlayerController.file(File(path));
        await _videoController!.initialize();
        _videoController!.addListener(_videoListener);
        _totalDuration = _videoController!.value.duration;
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _captionText =
          'Media selected. Tap "Start Captions" to upload, wait briefly, and begin lively caption playback.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _captionText = 'Unable to open selected media: $e';
        });
      }
    }
  }

  void _videoListener() {
    if (!mounted || _videoController == null || _mediaMode != MediaMode.video) {
      return;
    }

    final value = _videoController!.value;

    setState(() {
      _currentPosition = value.position;
      _totalDuration = value.duration;
      _isPlaying = value.isPlaying;
    });

    _updateActiveCaptionByTime();

    if (value.isInitialized &&
        value.duration != Duration.zero &&
        value.position >= value.duration) {
      setState(() {
        _isPlaying = false;
      });
    }
  }

  Future<void> _loadYoutubeVideo() async {
    final input = _youtubeController.text.trim();
    if (input.isEmpty) return;

    final videoId = YoutubePlayerController.convertUrlToId(input);

    if (videoId == null || videoId.isEmpty) {
      setState(() {
        _captionText = 'Invalid YouTube link. Please paste a valid YouTube URL.';
      });
      return;
    }

    await _stopAllPlayback(resetCaption: true);
    _youtubePlayerController?.close();

    _youtubePlayerController = YoutubePlayerController.fromVideoId(
      videoId: videoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        strictRelatedVideos: true,
        enableCaption: true,
      ),
    );

    _isYoutubeMode = true;
    _mediaMode = MediaMode.video;
    _source = UploadSource.youtube;
    _fileName = 'YouTube Video';
    _localFilePath = null;
    _sessionId = null;
    _jobStatus = 'idle';
    _autoStarted = false;
    _captionChunks.clear();
    _chunkKeys.clear();
    _activeCaption = '';
    _currentPosition = Duration.zero;
    _totalDuration = Duration.zero;

    _startYoutubeTracking();

    if (mounted) {
      setState(() {
        _captionText =
        'YouTube video loaded. Tap "Start Captions" to send it to backend.';
      });
    }
  }

  Future<void> _uploadLocalMediaToBackend() async {
    if (_localFilePath == null || _localFilePath!.isEmpty) {
      setState(() {
        _captionText = 'Choose an audio or video file first.';
      });
      return;
    }

    try {
      setState(() {
        _isUploadingToBackend = true;
        _captionText = 'Connecting to live captioning stream...';
      });

      final preferredLanguage =
          context.read<LanguageProvider>().selectedLanguage.toLowerCase();
      
      final mediaType = _mediaMode == MediaMode.audio ? 'audio' : 'video';

      final wsUrl = kBackendUrl.replaceFirst('http', 'ws');
      _mediaWebSocket = await WebSocket.connect('$wsUrl/ws/stream-media');

      _mediaWebSocket!.add(jsonEncode({
        'target_language': preferredLanguage,
        'media_type': mediaType,
      }));

      setState(() {
        _captionText = 'Stream connected. Captions will appear live as playback starts.';
      });

      _mediaWebSocket!.listen(
        (data) {
          if (data is String) {
            final body = jsonDecode(data);
            if (body.containsKey('status') && body['status'] == 'done') {
              return;
            }
            if (body.containsKey('error')) {
              setState(() => _captionText = body['error'].toString());
              return;
            }
            
            final chunk = CaptionChunk.fromJson(body);
            final key = '${chunk.start}_${chunk.end}_${chunk.translatedText.trim()}';
            
            if (!_chunkKeys.contains(key)) {
              _chunkKeys.add(key);
              _captionChunks.add(chunk);
              
              _captionChunks.sort((a, b) => a.start.compareTo(b.start));

              if (mounted) {
                setState(() {
                  _captionText = _captionChunks
                      .map((c) => c.translatedText.trim())
                      .where((t) => t.isNotEmpty)
                      .join('\n\n');
                });
                _scrollTranscriptToBottom();
                _updateActiveCaptionByTime();
              }
            }
          }
        },
        onError: (e) {
          if (mounted) {
            setState(() => _captionText = 'Stream error: $e');
          }
        },
      );

      _scheduleAutoStartPlayback();

      final file = File(_localFilePath!);
      final stream = file.openRead(0, file.lengthSync());
      
      _streamFileChunks(stream);

    } catch (e) {
      setState(() {
        _captionText = 'Connection failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isUploadingToBackend = false);
      }
    }
  }

  Future<void> _streamFileChunks(Stream<List<int>> stream) async {
    try {
      await for (final chunk in stream) {
        if (_mediaWebSocket?.readyState == WebSocket.open) {
          _mediaWebSocket!.add(chunk);
          await Future.delayed(const Duration(milliseconds: 10));
        } else {
          break;
        }
      }
    } catch (e) {
      print('Streaming error: $e');
    }
  }

  Future<void> _sendYoutubeToBackend() async {
    final url = _youtubeController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _captionText = 'Paste a YouTube link first.';
      });
      return;
    }

    try {
      setState(() {
        _isUploadingToBackend = true;
        _captionText = 'Sending YouTube link and preparing live captions...';
      });

      final preferredLanguage =
      context.read<LanguageProvider>().selectedLanguage.toLowerCase();

      final response = await http.post(
        Uri.parse('$kBackendUrl/upload-youtube'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'url': url,
          'target_language': preferredLanguage,
        }),
      );

      final body = jsonDecode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        _sessionId = (body['session_id'] ?? '').toString();
        _jobStatus = (body['status'] ?? 'processing').toString();

        setState(() {
          _captionText =
          'YouTube processing started. Playback will begin shortly and captions will appear live.';
        });

        _startCaptionPolling();
        _scheduleAutoStartPlayback();
      } else {
        setState(() {
          _captionText =
              (body['error'] ?? 'Unable to process YouTube link').toString();
        });
      }
    } catch (e) {
      setState(() {
        _captionText = 'YouTube request failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isUploadingToBackend = false);
      }
    }
  }

  void _scheduleAutoStartPlayback() {
    if (_autoStarted) return;

    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted || _mediaMode == MediaMode.none || _autoStarted) return;
      _autoStarted = true;
      await _startPlayback();
    });
  }

  void _startCaptionPolling() {
    _pollingTimer?.cancel();

    if (_sessionId == null || _sessionId!.isEmpty) return;

    _isPollingCaptions = true;

    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      await _fetchJobStatus();
      await _fetchCaptionChunks();
    });
  }

  Future<void> _fetchJobStatus() async {
    if (_sessionId == null || _sessionId!.isEmpty) return;

    try {
      final response = await http.get(Uri.parse('$kBackendUrl/job/$_sessionId'));
      if (response.statusCode != 200) return;

      final body = jsonDecode(response.body);

      if (!mounted) return;

      setState(() {
        _jobStatus = (body['status'] ?? _jobStatus).toString();
      });
    } catch (_) {}
  }

  Future<void> _fetchCaptionChunks() async {
    if (_sessionId == null || _sessionId!.isEmpty) return;

    try {
      final response =
      await http.get(Uri.parse('$kBackendUrl/captions/$_sessionId'));

      if (response.statusCode != 200) return;

      final body = jsonDecode(response.body);
      final rawCaptions = body['captions'];

      if (rawCaptions is! List) return;

      bool addedAny = false;

      for (final item in rawCaptions) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final chunk = CaptionChunk.fromJson(map);
        final key =
            '${chunk.start}_${chunk.end}_${chunk.translatedText.trim()}';

        if (!_chunkKeys.contains(key)) {
          _chunkKeys.add(key);
          _captionChunks.add(chunk);
          addedAny = true;
        }
      }

      _captionChunks.sort((a, b) => a.start.compareTo(b.start));

      if (!mounted) return;

      if (addedAny) {
        setState(() {
          _captionText = _captionChunks
              .map((c) => c.translatedText.trim())
              .where((t) => t.isNotEmpty)
              .join('\n\n');
        });

        _scrollTranscriptToBottom();
      }

      _updateActiveCaptionByTime();

      if (_jobStatus == 'ready' && _captionChunks.isNotEmpty) {
        _isPollingCaptions = false;
      }
    } catch (_) {}
  }

  void _updateActiveCaptionByTime() {
    final seconds = _currentPosition.inMilliseconds / 1000.0;

    CaptionChunk? current;
    for (final chunk in _captionChunks) {
      if (seconds >= chunk.start && seconds <= chunk.end) {
        current = chunk;
        break;
      }
    }

    if (!mounted) return;
    final newCaption = current?.translatedText.trim() ?? '';
    if (newCaption != _activeCaption) {
      setState(() {
        _activeCaption = newCaption;
      });
    }
  }

  Future<void> _togglePlayback() async {
    if (_mediaMode == MediaMode.none) return;

    if (_isPlaying) {
      await _pausePlayback();
    } else {
      await _startPlayback();
    }
  }

  Future<void> _startPlayback() async {
    if (_mediaMode == MediaMode.audio) {
      await _audioPlayer.play();
    } else if (_isYoutubeMode && _youtubePlayerController != null) {
      await _youtubePlayerController!.playVideo();
      _startYoutubeTracking();
    } else if (_mediaMode == MediaMode.video && _videoController != null) {
      await _videoController!.play();
    }

    if (mounted) {
      setState(() => _isPlaying = true);
    }
  }

  Future<void> _pausePlayback() async {
    if (_mediaMode == MediaMode.audio) {
      await _audioPlayer.pause();
    } else if (_isYoutubeMode && _youtubePlayerController != null) {
      await _youtubePlayerController!.pauseVideo();
      _youtubePositionTimer?.cancel();
    } else if (_mediaMode == MediaMode.video && _videoController != null) {
      await _videoController!.pause();
    }

    if (mounted) {
      setState(() => _isPlaying = false);
    }
  }

  Future<void> _seekTo(Duration position) async {
    final target = _clampDuration(position, _totalDuration);

    if (_mediaMode == MediaMode.audio) {
      await _audioPlayer.seek(target);
    } else if (_isYoutubeMode && _youtubePlayerController != null) {
      await _youtubePlayerController!.seekTo(
        seconds: target.inSeconds.toDouble(),
        allowSeekAhead: true,
      );
      _startYoutubeTracking();
    } else if (_mediaMode == MediaMode.video && _videoController != null) {
      await _videoController!.seekTo(target);
    }

    if (mounted) {
      setState(() => _currentPosition = target);
    }

    _updateActiveCaptionByTime();
  }

  Future<void> _skipForward() async {
    await _seekTo(_currentPosition + const Duration(seconds: 10));
  }

  Future<void> _skipBackward() async {
    await _seekTo(_currentPosition - const Duration(seconds: 10));
  }

  Duration _clampDuration(Duration value, Duration max) {
    if (value < Duration.zero) return Duration.zero;
    if (max == Duration.zero) return value;
    if (value > max) return max;
    return value;
  }

  Future<void> _stopAllPlayback({bool resetCaption = false}) async {
    _pollingTimer?.cancel();
    _youtubePositionTimer?.cancel();
    _mediaWebSocket?.close();

    await _audioPlayer.stop();

    if (_videoController != null) {
      _videoController!.removeListener(_videoListener);
      await _videoController!.pause();
      await _videoController!.seekTo(Duration.zero);
      await _videoController!.dispose();
      _videoController = null;
    }

    if (_youtubePlayerController != null) {
      await _youtubePlayerController!.pauseVideo();
      _youtubePlayerController!.close();
      _youtubePlayerController = null;
    }

    if (mounted) {
      setState(() {
        _isPlaying = false;
        _isPollingCaptions = false;
        _currentPosition = Duration.zero;
        _totalDuration = Duration.zero;
        _activeCaption = '';
        _autoStarted = false;
        if (resetCaption) {
          _captionText =
          'Choose a source, prepare the media, and start live captioning.';
        }
      });
    }
  }

  void _scrollTranscriptToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_captionScrollController.hasClients) {
        _captionScrollController.animateTo(
          _captionScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  void _onNavTap(int index) {
    setState(() => _currentIndex = index);
    context.go(_navItems[index].route);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final language = context.watch<LanguageProvider>().selectedLanguage;
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
                  child: _Header(language: language),
                ),
                const SizedBox(height: AppConstants.spaceMd),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.only(bottom: 110 + bottomInset),
                    child: Column(
                      children: [
                        FadeInUp(
                          delay: const Duration(milliseconds: 80),
                          child: _SourceToggle(
                            source: _source,
                            onChanged: (value) {
                              setState(() => _source = value);
                            },
                            onLocalTap: _showPickTypeDialog,
                          ),
                        ),
                        const SizedBox(height: AppConstants.spaceMd),
                        if (_source == UploadSource.youtube)
                          FadeInUp(
                            delay: const Duration(milliseconds: 120),
                            child: _YoutubeInputCard(
                              controller: _youtubeController,
                              onLoad: _loadYoutubeVideo,
                              onStartCaptions: _sendYoutubeToBackend,
                              isLoading: _isUploadingToBackend,
                            ),
                          ),
                        if (_source == UploadSource.local)
                          FadeInUp(
                            delay: const Duration(milliseconds: 120),
                            child: _UploadActionCard(
                              fileName: _fileName,
                              isLoading: _isUploadingToBackend,
                              onPickAgain: _showPickTypeDialog,
                              onStartCaptions: _uploadLocalMediaToBackend,
                            ),
                          ),
                        FadeInUp(
                          delay: const Duration(milliseconds: 180),
                          child: _CompactNowPlayingCard(
                            fileName: _fileName,
                            mediaMode: _mediaMode,
                            isLoading: _isLoading,
                            isPlaying: _isPlaying,
                            isYoutube: _isYoutubeMode,
                            position: _currentPosition,
                            duration: _totalDuration,
                            activeCaption: _activeCaption,
                            jobStatus: _jobStatus,
                            isPollingCaptions: _isPollingCaptions,
                            formatDuration: _formatDuration,
                            videoController: _videoController,
                            youtubePlayerController: _youtubePlayerController,
                            onPlayPause: _togglePlayback,
                            onForward: _skipForward,
                            onBackward: _skipBackward,
                            onSeek: (value) =>
                                _seekTo(Duration(milliseconds: value.toInt())),
                          ),
                        ),
                        const SizedBox(height: AppConstants.spaceMd),
                        FadeInUp(
                          delay: const Duration(milliseconds: 240),
                          child: _CaptionBox(
                            captionText: _captionText,
                            scrollController: _captionScrollController,
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
            behavior: HitTestBehavior.opaque,
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

class _Header extends StatelessWidget {
  final String language;

  const _Header({required this.language});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'Upload Media',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(AppConstants.radiusFull),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.language_rounded,
                color: AppColors.primary,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                language,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SourceToggle extends StatelessWidget {
  final UploadSource source;
  final ValueChanged<UploadSource> onChanged;
  final VoidCallback onLocalTap;

  const _SourceToggle({
    required this.source,
    required this.onChanged,
    required this.onLocalTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleChip(
              selected: source == UploadSource.local,
              label: 'Local File',
              icon: Icons.folder_open_rounded,
              onTap: () {
                onChanged(UploadSource.local);
                onLocalTap();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ToggleChip(
              selected: source == UploadSource.youtube,
              label: 'YouTube Link',
              icon: Icons.ondemand_video_rounded,
              onTap: () => onChanged(UploadSource.youtube),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ToggleChip({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.primaryGradient : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(AppConstants.radiusFull),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? AppColors.textDark : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color:
                  selected ? AppColors.textDark : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _YoutubeInputCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onLoad;
  final VoidCallback onStartCaptions;
  final bool isLoading;

  const _YoutubeInputCard({
    required this.controller,
    required this.onLoad,
    required this.onStartCaptions,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppConstants.spaceMd),
      padding: const EdgeInsets.all(AppConstants.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Paste YouTube link',
              hintStyle: const TextStyle(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surface2,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spaceMd),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onLoad,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius:
                      BorderRadius.circular(AppConstants.radiusLg),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Center(
                      child: Text(
                        'Load Video',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spaceSm),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: isLoading ? null : onStartCaptions,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius:
                      BorderRadius.circular(AppConstants.radiusLg),
                    ),
                    child: Center(
                      child: Text(
                        isLoading ? 'Starting...' : 'Start Captions',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UploadActionCard extends StatelessWidget {
  final String? fileName;
  final bool isLoading;
  final VoidCallback onPickAgain;
  final VoidCallback onStartCaptions;

  const _UploadActionCard({
    required this.fileName,
    required this.isLoading,
    required this.onPickAgain,
    required this.onStartCaptions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppConstants.spaceMd),
      padding: const EdgeInsets.all(AppConstants.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fileName ?? 'No media selected yet.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppConstants.spaceMd),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onPickAgain,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius:
                      BorderRadius.circular(AppConstants.radiusLg),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Center(
                      child: Text(
                        'Choose File',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spaceSm),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: isLoading ? null : onStartCaptions,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius:
                      BorderRadius.circular(AppConstants.radiusLg),
                    ),
                    child: Center(
                      child: Text(
                        isLoading ? 'Starting...' : 'Start Captions',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactNowPlayingCard extends StatelessWidget {
  final String? fileName;
  final MediaMode mediaMode;
  final bool isLoading;
  final bool isPlaying;
  final bool isYoutube;
  final Duration position;
  final Duration duration;
  final String activeCaption;
  final String jobStatus;
  final bool isPollingCaptions;
  final String Function(Duration) formatDuration;
  final VideoPlayerController? videoController;
  final YoutubePlayerController? youtubePlayerController;
  final Future<void> Function() onPlayPause;
  final Future<void> Function() onForward;
  final Future<void> Function() onBackward;
  final ValueChanged<double> onSeek;

  const _CompactNowPlayingCard({
    required this.fileName,
    required this.mediaMode,
    required this.isLoading,
    required this.isPlaying,
    required this.isYoutube,
    required this.position,
    required this.duration,
    required this.activeCaption,
    required this.jobStatus,
    required this.isPollingCaptions,
    required this.formatDuration,
    required this.videoController,
    required this.youtubePlayerController,
    required this.onPlayPause,
    required this.onForward,
    required this.onBackward,
    required this.onSeek,
  });

  @override
  Widget build(BuildContext context) {
    final maxMs = duration.inMilliseconds <= 0 ? 1 : duration.inMilliseconds;
    final valueMs = position.inMilliseconds.clamp(0, maxMs).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spaceLg),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fileName ??
                (isLoading
                    ? 'Loading media...'
                    : 'No media selected. Tap Local File to choose audio or video.'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppConstants.spaceSm),
          Row(
            children: [
              Text(
                'Status: $jobStatus',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              if (isPollingCaptions)
                const Text(
                  'Live',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceMd),
          if (mediaMode == MediaMode.video &&
              isYoutube &&
              youtubePlayerController != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    YoutubePlayer(
                      controller: youtubePlayerController!,
                      aspectRatio: 16 / 9,
                    ),
                    if (activeCaption.trim().isNotEmpty)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusLg,
                            ),
                          ),
                          child: Text(
                            activeCaption,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            )
          else if (mediaMode == MediaMode.video &&
              videoController != null &&
              videoController!.value.isInitialized)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              child: AspectRatio(
                aspectRatio: videoController!.value.aspectRatio == 0
                    ? 16 / 9
                    : videoController!.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    VideoPlayer(videoController!),
                    if (activeCaption.trim().isNotEmpty)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusLg,
                            ),
                          ),
                          child: Text(
                            activeCaption,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            )
          else
            Container(
              height: 82,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              ),
              child: Center(
                child: Icon(
                  mediaMode == MediaMode.audio
                      ? Icons.audiotrack_rounded
                      : mediaMode == MediaMode.video
                      ? Icons.video_library_rounded
                      : Icons.library_music_rounded,
                  color: AppColors.primary.withValues(alpha: 0.9),
                  size: 36,
                ),
              ),
            ),
          if (activeCaption.trim().isNotEmpty && mediaMode != MediaMode.video) ...[
            const SizedBox(height: AppConstants.spaceMd),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                activeCaption,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  height: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppConstants.spaceMd),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.surface2,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.15),
            ),
            child: Slider(
              min: 0,
              max: maxMs.toDouble(),
              value: valueMs,
              onChanged: mediaMode == MediaMode.none ? null : onSeek,
            ),
          ),
          Row(
            children: [
              Text(
                formatDuration(position),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                formatDuration(duration),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ControlButton(
                icon: Icons.replay_10_rounded,
                onTap: mediaMode == MediaMode.none ? null : onBackward,
              ),
              const SizedBox(width: AppConstants.spaceMd),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: mediaMode == MediaMode.none ? null : onPlayPause,
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spaceMd),
              _ControlButton(
                icon: Icons.forward_10_rounded,
                onTap: mediaMode == MediaMode.none ? null : onForward,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final Future<void> Function()? onTap;

  const _ControlButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(
          icon,
          color: AppColors.textPrimary,
          size: 24,
        ),
      ),
    );
  }
}

class _DialogPickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DialogPickCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppConstants.spaceLg),
        decoration: BoxDecoration(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, size: 30, color: AppColors.primary),
            const SizedBox(height: AppConstants.spaceSm),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CaptionBox extends StatelessWidget {
  final String captionText;
  final ScrollController scrollController;

  const _CaptionBox({
    required this.captionText,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 290,
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Caption Output',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
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
                  child: SelectableText(
                    captionText,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.55,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
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
