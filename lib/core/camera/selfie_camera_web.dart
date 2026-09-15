import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

Future<Uint8List?> captureSelfie(BuildContext context) => showDialog<Uint8List>(
  context: context,
  builder: (_) => const _CameraDialog(),
);

class _CameraDialog extends StatefulWidget {
  const _CameraDialog();
  @override
  State<_CameraDialog> createState() => _CameraDialogState();
}

class _CameraDialogState extends State<_CameraDialog> {
  web.HTMLVideoElement? video;
  web.MediaStream? stream;
  String? error;
  bool ready = false;
  Future<void> start() async {
    try {
      final media = await web.window.navigator.mediaDevices
          .getUserMedia(
            web.MediaStreamConstraints(
              audio: false.toJS,
              video: {
                'facingMode': 'user',
                'width': {'ideal': 1000},
                'height': {'ideal': 750},
              }.jsify()!,
            ),
          )
          .toDart;
      if (!mounted) {
        for (final track in media.getTracks().toDart) {
          track.stop();
        }
        return;
      }
      stream = media;
      video!
        ..srcObject = media
        ..autoplay = true
        ..muted = true
        ..playsInline = true;
      await video!.play().toDart;
      if (mounted)
        setState(() {
          ready = true;
          error = null;
        });
    } catch (_) {
      stop();
      if (mounted)
        setState(() {
          error =
              'Kamera ochilmadi. Brauzerda kameraga ruxsat bering va HTTPS yoki localhost orqali oching.';
          ready = false;
        });
    }
  }

  void stop() {
    for (final track
        in stream?.getTracks().toDart ?? <web.MediaStreamTrack>[]) {
      track.stop();
    }
    stream = null;
  }

  void capture() {
    final source = video!;
    if (!ready || source.videoWidth == 0 || source.videoHeight == 0) return;
    final scale = source.videoWidth > 1000 ? 1000 / source.videoWidth : 1.0;
    final canvas = web.HTMLCanvasElement()
      ..width = (source.videoWidth * scale).round()
      ..height = (source.videoHeight * scale).round();
    final context2d = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    context2d.drawImage(source, 0, 0, canvas.width, canvas.height);
    final bytes = base64Decode(
      canvas.toDataURL('image/jpeg', .82.toJS).split(',').last,
    );
    stop();
    Navigator.pop(context, bytes);
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Dars uchun suratga tushing'),
    content: SizedBox(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: 4 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: HtmlElementView.fromTagName(
                tagName: 'video',
                onElementCreated: (element) {
                  video = element as web.HTMLVideoElement;
                  video!.style
                    ..width = '100%'
                    ..height = '100%'
                    ..objectFit = 'cover'
                    ..transform = 'scaleX(-1)';
                  unawaited(start());
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            error ??
                (ready
                    ? 'Yuzingiz kadrda aniq ko‘rinsin.'
                    : 'Kamera uchun brauzerdagi ruxsatni tasdiqlang.'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Bekor qilish'),
      ),
      if (error != null)
        TextButton(onPressed: start, child: const Text('Qayta urinish')),
      FilledButton.icon(
        onPressed: ready ? capture : null,
        icon: const Icon(Icons.camera_alt_outlined),
        label: const Text('Suratga olish'),
      ),
    ],
  );
}
