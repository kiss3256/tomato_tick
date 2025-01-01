import 'dart:async';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _CircularProgressPainter({
    required this.progress,
    required this.color,
    this.strokeWidth = 10.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - strokeWidth / 2;

    // 绘制背景圆环
    final backgroundPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, backgroundPaint);

    // 绘制进度圆弧
    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // 从12点钟方向开始
      2 * pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: '极简番茄钟',
      theme: CupertinoThemeData(
        primaryColor: CupertinoColors.systemRed,
      ),
      home: PomodoroTimer(),
    );
  }
}

class PomodoroTimer extends StatefulWidget {
  const PomodoroTimer({super.key});

  @override
  State<PomodoroTimer> createState() => _PomodoroTimerState();
}

class _PomodoroTimerState extends State<PomodoroTimer> {
  int _workDuration = 25 * 60;
  int _breakDuration = 5 * 60;
  late int _currentSeconds;
  bool _isRunning = false;
  bool _isWorkTime = true;
  Timer? _timer;
  bool _autoStartNextPhase = true;

  @override
  void initState() {
    super.initState();
    _currentSeconds = _workDuration;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _showNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'tomato_tick_channel',
      '番茄钟通知',
      channelDescription: '番茄钟计时结束通知',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);

    await flutterLocalNotificationsPlugin.show(
      0,
      _isWorkTime ? '休息时间到！' : '工作时间到！',
      _isWorkTime ? '该休息一下了' : '开始专注工作吧',
      platformChannelSpecifics,
    );

    setState(() {
      _isWorkTime = !_isWorkTime;
      _currentSeconds = _isWorkTime ? _workDuration : _breakDuration;
    });

    if (_autoStartNextPhase) {
      _startTimer();
    } else {
      setState(() {
        _isRunning = false;
      });
    }
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = true;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_currentSeconds > 0) {
          _currentSeconds--;
        } else {
          timer.cancel();
          _isRunning = false;
          _showNotification();
        }
      });
    });
  }

  void _toggleTimer() {
    if (_isRunning) {
      _timer?.cancel();
      setState(() {
        _isRunning = false;
      });
    } else {
      _startTimer();
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
      _isWorkTime = true;
      _currentSeconds = _workDuration;
    });
  }

  String _formatTime() {
    int minutes = _currentSeconds ~/ 60;
    int seconds = _currentSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final totalSeconds = _isWorkTime ? _workDuration : _breakDuration;
    final progress = 1 - (_currentSeconds / totalSeconds);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('极简番茄钟'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.settings),
          onPressed: () {
            showCupertinoModalPopup(
              context: context,
              builder: (context) => CupertinoActionSheet(
                title: const Text('设置'),
                message: StatefulBuilder(
                  builder: (context, setState) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoListSection(
                        children: [
                          CupertinoListTile(
                            title: const Text('自动开始下一阶段'),
                            trailing: CupertinoSwitch(
                              value: _autoStartNextPhase,
                              onChanged: (value) {
                                setState(() {
                                  _autoStartNextPhase = value;
                                });
                                this.setState(() {});
                              },
                            ),
                          ),
                          CupertinoListTile(
                            title: const Text('工作时长(分钟)'),
                            trailing: SizedBox(
                              width: 60,
                              child: CupertinoTextField(
                                controller: TextEditingController(
                                  text: (_workDuration ~/ 60).toString(),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  final minutes = int.tryParse(value) ?? 25;
                                  this.setState(() {
                                    _workDuration = minutes * 60;
                                    if (_isWorkTime) {
                                      _currentSeconds = _workDuration;
                                    }
                                  });
                                },
                              ),
                            ),
                          ),
                          CupertinoListTile(
                            title: const Text('休息时长(分钟)'),
                            trailing: SizedBox(
                              width: 60,
                              child: CupertinoTextField(
                                controller: TextEditingController(
                                  text: (_breakDuration ~/ 60).toString(),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  final minutes = int.tryParse(value) ?? 5;
                                  this.setState(() {
                                    _breakDuration = minutes * 60;
                                    if (!_isWorkTime) {
                                      _currentSeconds = _breakDuration;
                                    }
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  CupertinoActionSheetAction(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('完成'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final circleSize = constraints.maxWidth > constraints.maxHeight ? constraints.maxHeight * 0.6 : constraints.maxWidth * 0.8;

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isWorkTime ? '工作时间' : '休息时间',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: circleSize,
                      height: circleSize,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: Size(circleSize, circleSize),
                            painter: _CircularProgressPainter(
                              progress: progress,
                              color: _isWorkTime ? CupertinoColors.systemRed : CupertinoColors.systemGreen,
                            ),
                          ),
                          Text(
                            _formatTime(),
                            style: TextStyle(
                              fontSize: circleSize * 0.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CupertinoButton.filled(
                          onPressed: _toggleTimer,
                          child: Text(_isRunning ? '暂停' : '开始'),
                        ),
                        const SizedBox(width: 20),
                        CupertinoButton(
                          onPressed: _resetTimer,
                          child: const Text('重置'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
