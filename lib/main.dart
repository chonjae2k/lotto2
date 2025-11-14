import 'dart:math' as math; // Pi(원주율) 사용을 위해
import 'dart:convert'; // JSON 인코딩/디코딩
import 'dart:ui' as ui; // TextDirection 사용
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // 날짜 포맷팅
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/rendering.dart'; // 렌더링용
import 'package:flutter/foundation.dart'; // ChangeNotifier
import 'package:provider/provider.dart'; // Provider 패키지
import 'package:shared_preferences/shared_preferences.dart'; // 로컬 저장소

// --- 1. 게임의 핵심 상태 관리 ---
class RouletteLottoGame extends FlameGame with ChangeNotifier {
  // 게임 상태 변수
  List<int> selectedNumbers = []; // 뽑힌 6개 숫자
  List<Map<String, dynamic>> savedNumbers = []; // 저장된 로또 번호 목록 (날짜 포함)
  bool canSpin = true; // '돌리기' 버튼 활성화 여부
  bool isSpinning = false; // 룰렛이 돌고 있는지 여부
  int? _currentTargetNumber; // 현재 목표 숫자 저장
  String? lastMessage; // 마지막 메시지 (스낵바용)
  final math.Random _random = math.Random();
  
  @override
  Color backgroundColor() => Colors.white;

  // 로또 번호에 따른 색상 반환
  static Color getLottoColor(int number) {
    if (number >= 1 && number <= 10) {
      return Colors.yellow.shade700; // 노란색
    } else if (number >= 11 && number <= 20) {
      return Colors.blue.shade700; // 파란색
    } else if (number >= 21 && number <= 30) {
      return Colors.red.shade700; // 빨간색
    } else if (number >= 31 && number <= 40) {
      return Colors.grey.shade800; // 검은색/회색
    } else if (number >= 41 && number <= 45) {
      return Colors.green.shade700; // 녹색
    }
    return Colors.grey; // 기본값
  }

  // 컴포넌트 참조
  late RouletteComponent roulette;
  late PinComponent pin; // 룰렛 상단에 고정된 핀
  late TextComponent resultText; // 룰렛 중앙에 숫자를 표시할 텍스트
  RotateEffect? _currentRotateEffect; // 현재 회전 효과 저장
  late WindEffectComponent windEffect; // 바람 효과 컴포넌트

  // 게임 로드 시
  @override
  Future<void> onLoad() async {
    super.onLoad();
    camera.viewfinder.anchor = Anchor.topLeft;

    // 1. 룰렛 추가 (코드로 직접 그리기)
    roulette = RouletteComponent()
      ..position = size / 2 // 화면 중앙
      ..anchor = Anchor.center
      ..size = Vector2.all(size.x * 0.8); // 화면 너비의 80%

    // 2. 룰렛 중앙에 숫자 텍스트 추가
    resultText = TextComponent(
      text: '?',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 48,
          fontWeight: FontWeight.bold,
        ),
      ),
      anchor: Anchor.center,
      position: roulette.size / 2, // 룰렛 컴포넌트의 중앙
    );
    roulette.add(resultText); // 룰렛의 자식으로 추가 (함께 회전)
    add(roulette);

    // 3. 핀 추가 (룰렛 상단에 고정)
    final rouletteRadius = roulette.size.x / 2;
    pin = PinComponent()
      ..position = Vector2(roulette.position.x, roulette.position.y - rouletteRadius) // 룰렛 상단
      ..anchor = Anchor.center
      ..size = Vector2(30, 40); // 핀 크기
    add(pin);

    // 4. 바람 효과 추가
    windEffect = WindEffectComponent()
      ..position = roulette.position
      ..anchor = Anchor.center
      ..size = Vector2.all(roulette.size.x * 1.2); // 룰렛보다 약간 큰 영역
    add(windEffect);
  }

  // --- 2. 게임 로직 ---

  // '돌리기' 버튼 (Flutter UI)에서 호출
  void startSpin() {
    if (!canSpin || selectedNumbers.length >= 6 || isSpinning) return;
    
    resultText.text = '?'; // 숫자 숨기기
    
    // 1. (숫자 뽑기) 1~45 중 겹치지 않는 숫자 하나를 뽑음
    int targetNumber;
    do {
      targetNumber = _random.nextInt(45) + 1; // 1~45
    } while (selectedNumbers.contains(targetNumber));
    
    _currentTargetNumber = targetNumber; // 목표 숫자 저장
    isSpinning = true; // 룰렛이 돌고 있음
    canSpin = false;

    // 룰렛에 무한 회전 효과 추가 (빠르게 시작)
    _currentRotateEffect = RotateEffect.by(
      math.pi * 2,
      EffectController(
        speed: 6.0, // 빠른 회전 속도
        infinite: true,
      ),
      onComplete: () {}, // 무한이라 호출 안 됨
    );
    roulette.add(_currentRotateEffect!);
    
    // 바람 효과 시작
    windEffect.startWind();
    
    // 일정 시간 후 자동으로 자연스럽게 멈추기 (1.5~3초 사이 랜덤)
    final randomDelay = 1.5 + _random.nextDouble() * 1.5; // 1.5~3초
    Future.delayed(Duration(milliseconds: (randomDelay * 1000).toInt()), () {
      if (isSpinning && _currentTargetNumber != null) {
        _naturalStop();
      }
    });
    
    notifyListeners(); // UI(버튼 상태) 갱신
  }

  // 자연스럽게 멈추기 (자동 멈춤)
  void _naturalStop() {
    if (!isSpinning || _currentTargetNumber == null) return;
    
    // 무한 회전 효과 제거
    final effectsToRemove = roulette.children.whereType<RotateEffect>().toList();
    for (final effect in effectsToRemove) {
      effect.removeFromParent();
    }
    _currentRotateEffect = null;
    
    // 바람 효과 멈춤
    windEffect.stopWind();
    
    // 목표 각도 계산
    final double anglePerNumber = (math.pi * 2) / 45;
    final double targetAngle = (math.pi * 2 * 10) - (_currentTargetNumber! - 1) * anglePerNumber;
    
    // 현재 각도 정규화
    double currentAngle = roulette.angle % (math.pi * 2);
    if (currentAngle < 0) currentAngle += math.pi * 2;
    
    // 목표 각도 정규화
    double normalizedTargetAngle = targetAngle % (math.pi * 2);
    if (normalizedTargetAngle < 0) normalizedTargetAngle += math.pi * 2;
    
    // 현재 각도에서 목표 각도까지의 경로 계산
    double angleDiff = normalizedTargetAngle - currentAngle;
    if (angleDiff < 0) {
      angleDiff += math.pi * 2;
    }
    
    // 추가 회전 (자연스러운 감속을 위한 여유)
    angleDiff += math.pi * 2 * 8; // 8바퀴 더
    
    // 회전 속도 설정 (무한 회전과 동일한 속도)
    final baseSpeed = 6.0; // 초기 회전 속도 (rad/s)
    
    // 초기 속도로 일정하게 회전할 때 걸리는 시간
    final timeAtConstantSpeed = angleDiff / baseSpeed;
    
    // 감속을 고려한 총 시간 (초기에는 일정 속도, 후반에 감속)
    // easeOutCubic 커브를 사용하므로 약 1.2배 정도의 시간이 필요
    final totalDuration = timeAtConstantSpeed * 1.2;
    final duration = math.max(4.0, math.min(6.5, totalDuration));
    
    // 자연스러운 감속 효과
    final rouletteEffect = RotateEffect.by(
      angleDiff,
      EffectController(
        duration: duration,
        curve: Curves.easeOutCubic, // 초기에는 거의 일정 속도, 후반에 감속
      ),
      onComplete: () {
        _onSpinComplete(_currentTargetNumber!);
        _currentTargetNumber = null;
        isSpinning = false;
      },
    );
    
    roulette.add(rouletteEffect);
    _currentRotateEffect = rouletteEffect;
    
    notifyListeners(); // UI(버튼 상태) 갱신
  }

  // '멈추기' 버튼 (Flutter UI)에서 호출
  void stopSpin() {
    if (!isSpinning || _currentTargetNumber == null) return;
    
    // 현재 회전 효과 제거
    final effectsToRemove = roulette.children.whereType<RotateEffect>().toList();
    for (final effect in effectsToRemove) {
      effect.removeFromParent();
    }
    _currentRotateEffect = null;
    
    // 바람 효과 멈춤
    windEffect.stopWind();
    
    // 목표 각도 계산
    final double anglePerNumber = (math.pi * 2) / 45;
    final double targetAngle = (math.pi * 2 * 10) - (_currentTargetNumber! - 1) * anglePerNumber;
    
    // 목표 각도로 즉시 이동 (애니메이션 없이)
    roulette.angle = targetAngle;
    
    // 즉시 결과 처리
    _onSpinComplete(_currentTargetNumber!);
    _currentTargetNumber = null;
    isSpinning = false;
    
    notifyListeners(); // UI(버튼 상태) 갱신
  }

  // 4. (결과 처리) 룰렛이 멈춘 후
  void _onSpinComplete(int newNumber) {
    resultText.text = '$newNumber'; // 룰렛 중앙에 숫자 표시
    
    // 같은 숫자가 이미 뽑혔는지 확인
    if (selectedNumbers.contains(newNumber)) {
      // 중복 숫자 - 무효 처리
      lastMessage = '같은 숫자가 나와서 무효입니다. 다시 돌려주세요.';
      canSpin = true; // 다시 돌릴 수 있도록
      notifyListeners(); // UI 갱신 (스낵바 표시용)
      return;
    }
    
    // 유효한 숫자 - 추가
    selectedNumbers.add(newNumber);
    lastMessage = null; // 메시지 초기화
    
    // 숫자 선택 시 하이라이트 애니메이션
    roulette.highlightNumber(newNumber);
    // 2초 후 하이라이트 제거
    Future.delayed(const Duration(seconds: 2), () {
      roulette.highlightNumber(null);
    });

    // 6개가 안 찼으면 '돌리기' 버튼 활성화
    if (selectedNumbers.length < 6) {
      canSpin = true;
    }

    notifyListeners(); // UI(숫자 목록, 버튼 상태) 갱신
  }

  // '다시하기' (Flutter UI)에서 호출
  void resetGame() {
    selectedNumbers.clear();
    canSpin = true;
    isSpinning = false;
    _currentTargetNumber = null;
    resultText.text = '?';
    roulette.angle = 0; // 룰렛 각도 초기화
    if (_currentRotateEffect != null) {
      _currentRotateEffect!.removeFromParent();
      _currentRotateEffect = null;
    }
    windEffect.stopWind(); // 바람 효과 멈춤
    notifyListeners();
  }

  // 로또 번호 저장
  Future<bool> saveNumbers() async {
    if (selectedNumbers.length != 6) return false;
    
    final prefs = await SharedPreferences.getInstance();
    // 숫자를 낮은 순서대로 정렬하여 저장
    final sortedNumbers = List<int>.from(selectedNumbers)..sort();
    
    // 날짜와 함께 저장
    final now = DateTime.now();
    savedNumbers.add({
      'numbers': sortedNumbers,
      'date': now.toIso8601String(), // ISO 8601 형식으로 저장
    });
    
    // 날짜 역순으로 정렬 (최신이 위로)
    savedNumbers.sort((a, b) {
      final dateA = DateTime.parse(a['date']);
      final dateB = DateTime.parse(b['date']);
      return dateB.compareTo(dateA); // 역순
    });
    
    // JSON으로 변환하여 저장
    final jsonString = jsonEncode(savedNumbers);
    await prefs.setString('saved_lotto_numbers', jsonString);
    
    notifyListeners();
    return true;
  }

  // 저장된 로또 번호 불러오기
  Future<void> loadSavedNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('saved_lotto_numbers');
    
    if (jsonString != null) {
      final List<dynamic> decoded = jsonDecode(jsonString);
      
      // 기존 형식 (날짜 없음)과 새 형식 (날짜 있음) 모두 지원
      savedNumbers = decoded.map((item) {
        if (item is Map) {
          // 새 형식: 날짜 포함
          return Map<String, dynamic>.from(item);
        } else {
          // 기존 형식: 날짜 없음, 현재 날짜로 추가
          return {
            'numbers': List<int>.from(item),
            'date': DateTime.now().toIso8601String(),
          };
        }
      }).toList();
      
      // 날짜 역순으로 정렬 (최신이 위로)
      savedNumbers.sort((a, b) {
        final dateA = DateTime.parse(a['date']);
        final dateB = DateTime.parse(b['date']);
        return dateB.compareTo(dateA); // 역순
      });
      
      notifyListeners();
    }
  }

  // 저장된 로또 번호 초기화
  Future<void> clearSavedNumbers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_lotto_numbers');
    savedNumbers.clear();
    notifyListeners();
  }

  // 통계 데이터 계산
  Map<String, dynamic> getStatistics() {
    if (savedNumbers.isEmpty) {
      return {
        'totalCount': 0,
        'topNumbers': <Map<String, dynamic>>[],
        'numberFrequency': <int, int>{},
        'recentHistory': <Map<String, dynamic>>[],
      };
    }

    // 숫자별 출현 빈도 계산
    final numberFrequency = <int, int>{};
    for (final item in savedNumbers) {
      final numbers = List<int>.from(item['numbers']);
      for (final num in numbers) {
        numberFrequency[num] = (numberFrequency[num] ?? 0) + 1;
      }
    }

    // TOP 10 숫자 계산
    final sortedNumbers = numberFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final topNumbers = sortedNumbers.take(10).map((entry) {
      return {
        'number': entry.key,
        'count': entry.value,
        'percentage': (entry.value / savedNumbers.length * 100).toStringAsFixed(1),
      };
    }).toList();

    // 최근 히스토리 (최근 10개)
    final recentHistory = savedNumbers.take(10).map((item) {
      final numbers = List<int>.from(item['numbers']);
      final dateStr = item['date'] as String;
      return {
        'numbers': numbers,
        'date': dateStr,
      };
    }).toList();

    return {
      'totalCount': savedNumbers.length,
      'topNumbers': topNumbers,
      'numberFrequency': numberFrequency,
      'recentHistory': recentHistory,
    };
  }
}

// --- 4. 바람 효과 컴포넌트 ---
class WindEffectComponent extends PositionComponent with HasGameRef<RouletteLottoGame> {
  final List<WindParticle> _particles = [];
  bool _isActive = false;
  double _time = 0.0;
  
  void startWind() {
    _isActive = true;
    _particles.clear();
    // 파티클 초기화
    for (int i = 0; i < 30; i++) {
      _particles.add(WindParticle());
    }
  }
  
  void stopWind() {
    _isActive = false;
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    if (!_isActive) return;
    
    _time += dt;
    
    // 파티클 업데이트
    for (final particle in _particles) {
      particle.update(dt);
    }
    
    // 일정 시간마다 새로운 파티클 추가
    if (_time % 0.1 < dt) {
      if (_particles.length < 50) {
        _particles.add(WindParticle());
      }
    }
    
    // 화면 밖으로 나간 파티클 제거
    _particles.removeWhere((p) => p.life <= 0);
  }
  
  @override
  void render(Canvas canvas) {
    if (!_isActive) return;
    
    final center = size / 2;
    
    for (final particle in _particles) {
      final paint = Paint()
        ..color = particle.color.withOpacity(particle.opacity)
        ..style = PaintingStyle.fill;
      
      // 파티클 위치 계산 (룰렛 중심 기준)
      final angle = particle.angle;
      final distance = particle.distance;
      final x = center.x + math.cos(angle) * distance;
      final y = center.y + math.sin(angle) * distance;
      
      canvas.drawCircle(Offset(x, y), particle.size, paint);
    }
  }
}

// 바람 파티클 클래스
class WindParticle {
  double angle = 0.0; // 룰렛 중심으로부터의 각도
  double distance = 0.0; // 룰렛 중심으로부터의 거리
  double speed = 0.0; // 바깥으로 나가는 속도
  double size = 0.0; // 파티클 크기
  double life = 1.0; // 생명력 (0~1)
  double opacity = 0.0; // 투명도
  Color color = Colors.grey;
  
  WindParticle() {
    reset();
  }
  
  void reset() {
    final random = math.Random();
    angle = random.nextDouble() * math.pi * 2; // 랜덤 각도
    distance = 50 + random.nextDouble() * 100; // 룰렛 가장자리 근처
    speed = 20 + random.nextDouble() * 30; // 바깥으로 나가는 속도
    size = 2 + random.nextDouble() * 4;
    life = 1.0;
    opacity = 0.3 + random.nextDouble() * 0.4;
    
    // 색상 랜덤 (회색 계열)
    final grayValue = 100 + random.nextInt(100);
    color = Color.fromARGB(255, grayValue, grayValue, grayValue);
  }
  
  void update(double dt) {
    // 바깥으로 이동
    distance += speed * dt;
    life -= dt * 0.5; // 생명력 감소
    
    // 생명력에 따라 투명도 조절
    opacity = life * 0.5;
    
    // 화면 밖으로 나가면 리셋
    if (distance > 300 || life <= 0) {
      reset();
    }
  }
}

// --- 5. 룰렛 컴포넌트 (직접 그리기) ---
class RouletteComponent extends PositionComponent with HasGameRef<RouletteLottoGame> {
  int? _highlightedNumber; // 하이라이트된 숫자
  double _glowIntensity = 0.0; // 글로우 효과 강도
  double _time = 0.0; // 시간 추적
  
  void highlightNumber(int? number) {
    _highlightedNumber = number;
    _glowIntensity = number != null ? 1.0 : 0.0;
    _time = 0.0; // 하이라이트 시작 시 시간 초기화
  }
  
  @override
  void update(double dt) {
    super.update(dt);
    // 글로우 효과 펄스 애니메이션
    if (_glowIntensity > 0) {
      _time += dt;
      _glowIntensity = (math.sin(_time * 3) + 1) / 2 * 0.5 + 0.5;
    }
  }
  
  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final radius = size.x / 2;
    
    // 글로우 효과 (룰렛 주변)
    if (_glowIntensity > 0) {
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.yellow.withOpacity(0.3 * _glowIntensity)
        ..strokeWidth = 8
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
      
      canvas.drawCircle(center, radius + 5, glowPaint);
    }
    
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.grey.shade800;
    
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white
      ..strokeWidth = 2;
    
    // 외곽 원 그리기
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(center, radius, strokePaint);
    
    // 45개의 구간으로 나누기
    // 룰렛 상단(12시 방향)이 0도 기준
    final anglePerNumber = (math.pi * 2) / 45;
    for (int i = 0; i < 45; i++) {
      // Flutter 좌표계: 위쪽이 0도, 시계방향
      // 1번이 상단(0도)에서 시작
      final startAngle = i * anglePerNumber - math.pi / 2;
      final endAngle = (i + 1) * anglePerNumber - math.pi / 2;
      
      // 구간 색상 (무지개 색상)
      // 무지개 색상: 빨강, 주황, 노랑, 초록, 파랑, 남색, 보라
      final rainbowColors = [
        Colors.red.shade600,
        Colors.orange.shade600,
        Colors.yellow.shade600,
        Colors.green.shade600,
        Colors.blue.shade600,
        Colors.indigo.shade600,
        Colors.purple.shade600,
      ];
      
      // 구간 그리기 (호를 사용)
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..lineTo(
          center.dx + radius * math.cos(startAngle),
          center.dy + radius * math.sin(startAngle),
        )
        ..arcTo(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          endAngle - startAngle,
          false,
        )
        ..close();
      
      // 하이라이트 효과 (선택된 숫자)
      final isHighlighted = _highlightedNumber != null && (i + 1) == _highlightedNumber;
      final baseColor = rainbowColors[i % rainbowColors.length];
      final segmentPaint = Paint()
        ..style = PaintingStyle.fill
        ..color = isHighlighted 
            ? baseColor.withOpacity(1.0)
            : baseColor;
      
      // 하이라이트된 구간에 글로우 효과
      if (isHighlighted) {
        final highlightGlow = Paint()
          ..style = PaintingStyle.stroke
          ..color = Colors.yellow.withOpacity(0.8 * _glowIntensity)
          ..strokeWidth = 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
        canvas.drawPath(path, highlightGlow);
      }
      
      canvas.drawPath(path, segmentPaint);
      
      // 구간 경계선 그리기
      canvas.drawLine(
        center,
        Offset(
          center.dx + radius * math.cos(startAngle),
          center.dy + radius * math.sin(startAngle),
        ),
        strokePaint,
      );
      
      // 숫자 표시 (작은 숫자)
      final numberAngle = startAngle + anglePerNumber / 2;
      final numberRadius = radius * 0.7;
      final numberX = center.dx + numberRadius * math.cos(numberAngle);
      final numberY = center.dy + numberRadius * math.sin(numberAngle);
      
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          numberX - textPainter.width / 2,
          numberY - textPainter.height / 2,
        ),
      );
    }
    
    // 중앙 원 그리기
    final centerPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;
    canvas.drawCircle(center, radius * 0.15, centerPaint);
    canvas.drawCircle(center, radius * 0.15, strokePaint);
  }
}

// --- 5. 핀 컴포넌트 (룰렛 상단에 고정) ---
class PinComponent extends PositionComponent with HasGameRef<RouletteLottoGame> {
  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.yellow.shade600;
    
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.orange.shade900
      ..strokeWidth = 2;
    
    // 핀 몸통 (삼각형 - 위쪽을 향한 화살표 모양, 방향 반대)
    final pinPath = Path()
      ..moveTo(size.x / 2, size.y) // 아래쪽 중앙 (뾰족한 끝)
      ..lineTo(size.x * 0.2, size.y * 0.3) // 왼쪽 위
      ..lineTo(size.x * 0.8, size.y * 0.3) // 오른쪽 위
      ..close();
    
    canvas.drawPath(pinPath, paint);
    canvas.drawPath(pinPath, strokePaint);
    
    // 핀 기둥 (사각형)
    final baseRect = Rect.fromLTWH(
      size.x * 0.35,
      size.y * 0.0,
      size.x * 0.3,
      size.y * 0.3,
    );
    canvas.drawRect(baseRect, paint);
    canvas.drawRect(baseRect, strokePaint);
    
    // 핀 상단 원형 장식
    canvas.drawCircle(
      Offset(size.x / 2, 0),
      size.x * 0.15,
      paint,
    );
    canvas.drawCircle(
      Offset(size.x / 2, 0),
      size.x * 0.15,
      strokePaint,
    );
  }
}

// --- 6. Flutter UI (메인 앱) ---
void main() async {
  // Flutter 바인딩 초기화 (플러그인 사용 전 필수)
  WidgetsFlutterBinding.ensureInitialized();
  
  // FlameGame을 ChangeNotifier로 사용하기 위해 전역 변수로 생성
  final game = RouletteLottoGame();
  
  // 저장된 로또 번호 불러오기
  await game.loadSavedNumbers();

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: _MainTabView(game: game),
      ),
    ),
  );
}

// --- 7. 메인 탭 뷰 (하단 탭) ---
class _MainTabView extends StatefulWidget {
  final RouletteLottoGame game;
  
  const _MainTabView({required this.game});

  @override
  State<_MainTabView> createState() => _MainTabViewState();
}

class _MainTabViewState extends State<_MainTabView> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // --- 탭 1: 룰렛 게임 ---
          Column(
            children: [
              // --- 6A. Flutter UI 오버레이 (숫자 목록, 버튼) ---
              ChangeNotifierProvider.value(
                value: widget.game,
                child: const GameUIOverlay(),
              ),
              // --- 6B. Flame 게임 위젯 (룰렛, 핀) ---
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: GameWidget(
                    game: widget.game,
                  ),
                ),
              ),
            ],
          ),
          // --- 탭 2: 풍선 게임 ---
          ChangeNotifierProvider.value(
            value: widget.game,
            child: const BalloonGameView(),
          ),
          // --- 탭 3: 저장된 번호 목록 ---
          ChangeNotifierProvider.value(
            value: widget.game,
            child: const SavedNumbersView(),
          ),
          // --- 탭 4: 통계 대시보드 ---
          ChangeNotifierProvider.value(
            value: widget.game,
            child: const StatisticsView(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.casino),
            label: '룰렛',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.celebration),
            label: '풍선',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: '저장된 번호',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: '통계',
          ),
        ],
      ),
    );
  }
}

// --- 8. Flutter UI (게임 상단 UI) ---
class GameUIOverlay extends StatefulWidget {
  const GameUIOverlay({super.key});

  @override
  State<GameUIOverlay> createState() => _GameUIOverlayState();
}

class _GameUIOverlayState extends State<GameUIOverlay> {
  String? _lastShownMessage;

  @override
  Widget build(BuildContext context) {
    // game 상태가 변경(notifyListeners)되면 이 UI도 다시 빌드됨
    final game = context.watch<RouletteLottoGame>();
    
    // 메시지가 있고 아직 표시하지 않았으면 스낵바 표시
    if (game.lastMessage != null && game.lastMessage != _lastShownMessage) {
      _lastShownMessage = game.lastMessage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && game.lastMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(game.lastMessage!),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.orange,
            ),
          );
        }
      });
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 1. 뽑힌 6개 숫자 목록
          Text(
            game.selectedNumbers.length >= 6 ? '로또 번호 완성!' : '숫자를 뽑아주세요',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (index) {
              final String numberText = (index < game.selectedNumbers.length)
                  ? game.selectedNumbers[index].toString()
                  : '?';
              final int? number = (index < game.selectedNumbers.length)
                  ? game.selectedNumbers[index]
                  : null;
              final Color bgColor = number != null
                  ? RouletteLottoGame.getLottoColor(number)
                  : Colors.grey.shade300;
              final Color textColor = number != null
                  ? (number >= 31 && number <= 40 ? Colors.white : Colors.white)
                  : Colors.grey.shade600;
              return CircleAvatar(
                radius: 20,
                backgroundColor: bgColor,
                child: Text(
                  numberText,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          // 2. '돌리기' 또는 '멈추기' 버튼
          game.isSpinning
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: game.stopSpin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('멈추기'),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '자동으로 멈춥니다',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                )
              : ElevatedButton(
                  // 이미 6개를 다 뽑았으면 '돌리기' 비활성화
                  onPressed: game.canSpin ? game.startSpin : null,
                  child: const Text('룰렛 돌리기'),
                ),
          // 3. 저장/초기화 버튼 (로또 번호가 완성되었을 때만 표시)
          if (game.selectedNumbers.length >= 6) ...[
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final success = await game.saveNumbers();
                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('저장되었습니다'),
                          duration: Duration(seconds: 2),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('저장'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: game.resetGame,
                  icon: const Icon(Icons.refresh),
                  label: const Text('초기화'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text(
            game.selectedNumbers.length >= 6 
                ? '로또 번호가 완성되었습니다!' 
                : game.isSpinning
                    ? '멈추기 버튼을 눌러주세요!'
                    : '룰렛을 돌려 숫자를 뽑아주세요.',
            style: TextStyle(
              color: game.selectedNumbers.length >= 6 
                  ? Colors.green 
                  : game.isSpinning
                      ? Colors.orange
                      : Colors.blue,
            ),
          ),
        ],
      ),
    );
  }
}

// --- 8. 저장된 번호 목록 화면 ---
class SavedNumbersView extends StatelessWidget {
  const SavedNumbersView({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<RouletteLottoGame>();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // 헤더
          Text(
            '저장된 로또 번호',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          // 저장된 번호가 없을 때
          if (game.savedNumbers.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '저장된 번호가 없습니다',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '룰렛 탭에서 번호를 뽑고 저장해주세요',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            )
          // 저장된 번호 목록
          else
            Expanded(
              child: Column(
                children: [
                  // 저장된 번호 개수 표시
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '총 ${game.savedNumbers.length}개 저장됨',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 저장된 번호 리스트
                  Expanded(
                    child: ListView.builder(
                      itemCount: game.savedNumbers.length,
                      itemBuilder: (context, index) {
                        final item = game.savedNumbers[index];
                        final numbers = List<int>.from(item['numbers']);
                        final dateStr = item['date'] as String;
                        final date = DateTime.parse(dateStr);
                        final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(date);
                        
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          elevation: 2,
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: numbers.map((num) {
                                final bgColor = RouletteLottoGame.getLottoColor(num);
                                final textColor = (num >= 31 && num <= 40) 
                                    ? Colors.white 
                                    : Colors.white;
                                return Container(
                                  width: 35,
                                  height: 35,
                                  decoration: BoxDecoration(
                                    color: bgColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$num',
                                      style: TextStyle(
                                        color: textColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                formattedDate,
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  // 삭제 버튼
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: game.clearSavedNumbers,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('저장된 번호 모두 삭제'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
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

// --- 9. 통계 대시보드 화면 ---
class StatisticsView extends StatelessWidget {
  const StatisticsView({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<RouletteLottoGame>();
    final stats = game.getStatistics();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Text(
                '통계 대시보드',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              
              // 전체 뽑기 횟수
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '총 뽑기 횟수',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${stats['totalCount']}회',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        Icons.analytics,
                        size: 48,
                        color: Colors.blue.shade300,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // 가장 많이 뽑힌 숫자 TOP 10
              Text(
                '가장 많이 뽑힌 숫자 TOP 10',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if ((stats['topNumbers'] as List).isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        '저장된 번호가 없습니다',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                )
              else
                ...(stats['topNumbers'] as List<Map<String, dynamic>>).asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final number = item['number'] as int;
                  final count = item['count'] as int;
                  final percentage = item['percentage'] as String;
                  final color = RouletteLottoGame.getLottoColor(number);
                  final maxCount = (stats['topNumbers'] as List).first['count'] as int;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '$number',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            '${index + 1}위',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: index < 3 ? Colors.orange : Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: LinearProgressIndicator(
                              value: count / maxCount,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(color),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        '$count회 ($percentage%)',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Text(
                        '$count',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: color,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              
              const SizedBox(height: 24),
              
              // 숫자별 출현 빈도 차트
              Text(
                '숫자별 출현 빈도',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if ((stats['numberFrequency'] as Map).isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        '데이터가 없습니다',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                )
              else
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildFrequencyChart(
                      stats['numberFrequency'] as Map<int, int>,
                      stats['totalCount'] as int,
                    ),
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // 최근 뽑기 히스토리
              Text(
                '최근 뽑기 히스토리',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              if ((stats['recentHistory'] as List).isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Center(
                      child: Text(
                        '히스토리가 없습니다',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                )
              else
                ...(stats['recentHistory'] as List<Map<String, dynamic>>).map((item) {
                  final numbers = List<int>.from(item['numbers']);
                  final dateStr = item['date'] as String;
                  final date = DateTime.parse(dateStr);
                  final formattedDate = DateFormat('yyyy-MM-dd HH:mm').format(date);
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.history, color: Colors.blue),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: numbers.map((num) {
                          final bgColor = RouletteLottoGame.getLottoColor(num);
                          return Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: bgColor,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '$num',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      subtitle: Text(
                        formattedDate,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFrequencyChart(Map<int, int> frequency, int totalCount) {
    if (frequency.isEmpty) return const SizedBox.shrink();
    
    final maxCount = frequency.values.reduce((a, b) => a > b ? a : b);
    
    return Column(
      children: [
        // 숫자 범위별로 그룹화 (1-10, 11-20, 21-30, 31-40, 41-45)
        for (int range = 0; range < 5; range++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${range * 10 + 1}~${range == 4 ? 45 : (range + 1) * 10}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: List.generate(
                    range == 4 ? 5 : 10,
                    (index) {
                      final num = range * 10 + index + 1;
                      final count = frequency[num] ?? 0;
                      final height = maxCount > 0 ? (count / maxCount * 60) : 0.0;
                      
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            children: [
                              Container(
                                height: 60,
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  height: height,
                                  decoration: BoxDecoration(
                                    color: RouletteLottoGame.getLottoColor(num),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$num',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              if (count > 0)
                                Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: RouletteLottoGame.getLottoColor(num),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// --- 10. 풍선 게임 화면 ---
class BalloonGameView extends StatelessWidget {
  const BalloonGameView({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<RouletteLottoGame>();
    return _BalloonGameViewContent(game: game);
  }
}

class _BalloonGameViewContent extends StatefulWidget {
  final RouletteLottoGame game;
  
  const _BalloonGameViewContent({required this.game});

  @override
  State<_BalloonGameViewContent> createState() => _BalloonGameViewState();
}

class _BalloonGameViewState extends State<_BalloonGameViewContent> with TickerProviderStateMixin {
  // 45개의 풍선 상태: null = 안 터짐, int = 터진 후 나온 숫자
  List<int?> balloons = List.filled(45, null);
  List<int> balloonNumbers = [];
  List<int> selectedNumbers = []; // 터진 풍선의 숫자들 (최대 6개)
  bool _initialized = false;
  
  // 파티클 효과를 위한 상태
  Map<int, List<Particle>> _particles = {}; // index -> particles
  Map<int, AnimationController> _sparkleControllers = {}; // 반짝임 애니메이션
  String? _celebrationMessage; // 축하 메시지
  OverlayEntry? _celebrationOverlay; // 축하 메시지 오버레이

  @override
  void initState() {
    super.initState();
    _initializeBalloons();
  }

  void _initializeBalloons() {
    if (_initialized) return;
    _initialized = true;
    
    // 1~45 숫자를 랜덤하게 섞기
    balloonNumbers = List.generate(45, (index) => index + 1);
    balloonNumbers.shuffle();
  }

  void _popBalloon(int index) {
    if (balloons[index] != null) return; // 이미 터진 풍선
    if (selectedNumbers.length >= 6) return; // 이미 6개를 다 뽑음
    
    final number = balloonNumbers[index];
    final popCount = selectedNumbers.length + 1;
    
    setState(() {
      balloons[index] = number;
      selectedNumbers.add(number);
    });
    
    // 파티클 효과 시작
    _startParticleEffect(index);
    
    // 반짝임 애니메이션 시작
    _startSparkleAnimation(index);
    
    // 축하 메시지 표시
    _showCelebrationMessage(popCount, number);
    
    // 6개가 다 터지면 다이얼로그 표시
    if (selectedNumbers.length >= 6) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _showCompleteDialog();
      });
    }
  }
  
  // 파티클 효과 시작
  void _startParticleEffect(int index) {
    final random = math.Random();
    final particles = <Particle>[];
    
    // 풍선 색상 가져오기
    final number = balloonNumbers[index];
    final color = RouletteLottoGame.getLottoColor(number);
    
    // 20개의 파티클 생성
    for (int i = 0; i < 20; i++) {
      final angle = random.nextDouble() * math.pi * 2;
      final speed = 50 + random.nextDouble() * 100;
      particles.add(Particle(
        angle: angle,
        speed: speed,
        color: color,
        size: 3 + random.nextDouble() * 5,
      ));
    }
    
    setState(() {
      _particles[index] = particles;
    });
    
    // 파티클 애니메이션
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _particles.remove(index);
        });
      }
    });
  }
  
  // 반짝임 애니메이션 시작
  void _startSparkleAnimation(int index) {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _sparkleControllers[index] = controller;
    controller.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && _sparkleControllers.containsKey(index)) {
          _sparkleControllers[index]?.dispose();
          _sparkleControllers.remove(index);
        }
      });
    });
  }
  
  // 축하 메시지 표시
  void _showCelebrationMessage(int popCount, int number) {
    String message;
    
    switch (popCount) {
      case 1:
        message = '첫 번째 숫자!';
        break;
      case 2:
        message = '두 번째 숫자!';
        break;
      case 3:
        message = '세 번째 숫자!';
        break;
      case 4:
        message = '네 번째 숫자!';
        break;
      case 5:
        message = '다섯 번째 숫자!';
        break;
      case 6:
        message = '완성! 🎉';
        break;
      default:
        message = '좋아요!';
    }
    
    setState(() {
      _celebrationMessage = message;
    });
    
    // 1.5초 후 메시지 제거
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _celebrationMessage = null;
        });
      }
    });
  }
  
  void _showCompleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로또 번호 완성!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('6개의 숫자를 모두 뽑았습니다.'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: selectedNumbers.map((num) {
                final bgColor = RouletteLottoGame.getLottoColor(num);
                return CircleAvatar(
                  radius: 20,
                  backgroundColor: bgColor,
                  child: Text(
                    '$num',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetBalloons();
            },
            child: const Text('초기화'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // selectedNumbers를 정렬하여 game에 복사하고 저장
              final sortedNumbers = List<int>.from(selectedNumbers)..sort();
              widget.game.selectedNumbers = sortedNumbers;
              final success = await widget.game.saveNumbers();
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('저장되었습니다'),
                    duration: Duration(seconds: 2),
                    backgroundColor: Colors.green,
                  ),
                );
              }
              _resetBalloons();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _resetBalloons() {
    // 모든 애니메이션 컨트롤러 정리
    for (final controller in _sparkleControllers.values) {
      controller.dispose();
    }
    _sparkleControllers.clear();
    
    setState(() {
      balloons = List.filled(45, null);
      selectedNumbers.clear();
      _particles.clear();
      _celebrationMessage = null;
      balloonNumbers.shuffle();
      _initialized = false;
      _initializeBalloons();
    });
  }
  
  @override
  void dispose() {
    // 모든 애니메이션 컨트롤러 정리
    for (final controller in _sparkleControllers.values) {
      controller.dispose();
    }
    _sparkleControllers.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Column(
                children: [
              // 헤더
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    selectedNumbers.length >= 6 ? '로또 번호 완성!' : '숫자를 뽑아주세요',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  ElevatedButton.icon(
                    onPressed: _resetBalloons,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('다시하기', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 뽑힌 숫자 표시
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (index) {
                  final String numberText = (index < selectedNumbers.length)
                      ? selectedNumbers[index].toString()
                      : '?';
                  final int? number = (index < selectedNumbers.length)
                      ? selectedNumbers[index]
                      : null;
                  final Color bgColor = number != null
                      ? RouletteLottoGame.getLottoColor(number)
                      : Colors.grey.shade300;
                  final Color textColor = number != null
                      ? Colors.white
                      : Colors.grey.shade600;
                  return CircleAvatar(
                    radius: 18,
                    backgroundColor: bgColor,
                    child: Text(
                      numberText,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              // 풍선 그리드
              Expanded(
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 9,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: 45,
                  itemBuilder: (context, index) {
                    final isPopped = balloons[index] != null;
                    final number = balloons[index];
                    final color = isPopped 
                        ? Colors.grey.shade300 
                        : _getBalloonColor(index);
                    
                    // 파티클 효과가 있는지 확인
                    final hasParticles = _particles.containsKey(index);
                    final sparkleController = _sparkleControllers[index];
                    
                    return Stack(
                      children: [
                        GestureDetector(
                          onTap: () => _popBalloon(index),
                          child: CustomPaint(
                            painter: BalloonPainter(
                              color: color,
                              isPopped: isPopped,
                              number: number,
                              sparkleProgress: sparkleController?.value ?? 0.0,
                            ),
                            child: Container(),
                          ),
                        ),
                        // 파티클 효과
                        if (hasParticles)
                          CustomPaint(
                            painter: ParticlePainter(
                              particles: _particles[index]!,
                            ),
                            child: Container(),
                          ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              // 터진 풍선 개수 표시
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '터진 풍선: ${balloons.where((b) => b != null).length} / 45',
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
                ],
              ),
            ),
            // 축하 메시지 표시 (오버레이)
            if (_celebrationMessage != null)
              Positioned(
                top: 100,
                left: 0,
                right: 0,
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 300),
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: Opacity(
                          opacity: value,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Text(
                              _celebrationMessage!,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: _getCelebrationColor(),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Color _getCelebrationColor() {
    final count = selectedNumbers.length;
    switch (count) {
      case 1:
        return Colors.blue;
      case 2:
        return Colors.green;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.purple;
      case 5:
        return Colors.pink;
      case 6:
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  Color _getBalloonColor(int index) {
    // 무지개 색상으로 풍선 색상 지정
    final colors = [
      Colors.red.shade300,
      Colors.orange.shade300,
      Colors.yellow.shade300,
      Colors.green.shade300,
      Colors.blue.shade300,
      Colors.indigo.shade300,
      Colors.purple.shade300,
    ];
    return colors[index % colors.length];
  }
}

// 풍선 모양 커스텀 페인터
// 파티클 클래스
class Particle {
  double angle;
  double speed;
  Color color;
  double size;
  double life = 1.0;
  double distance = 0.0;
  
  Particle({
    required this.angle,
    required this.speed,
    required this.color,
    required this.size,
  });
  
  void update(double dt) {
    distance += speed * dt;
    life -= dt * 1.5;
  }
}

// 파티클 페인터
class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  
  ParticlePainter({required this.particles});
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    
    for (final particle in particles) {
      if (particle.life <= 0) continue;
      
      final x = center.dx + math.cos(particle.angle) * particle.distance;
      final y = center.dy + math.sin(particle.angle) * particle.distance;
      
      final paint = Paint()
        ..color = particle.color.withOpacity(particle.life)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(Offset(x, y), particle.size * particle.life, paint);
    }
  }
  
  @override
  bool shouldRepaint(covariant ParticlePainter oldDelegate) => true;
}

class BalloonPainter extends CustomPainter {
  final Color color;
  final bool isPopped;
  final int? number;
  final double sparkleProgress; // 반짝임 진행도 (0.0 ~ 1.0)

  BalloonPainter({
    required this.color,
    required this.isPopped,
    this.number,
    this.sparkleProgress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (isPopped) {
      // 터진 풍선: 회색 배경에 숫자만 표시
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      
      canvas.drawOval(
        Rect.fromLTWH(0, 0, size.width, size.height * 0.8),
        paint,
      );
      
      if (number != null) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: '$number',
            style: TextStyle(
              fontSize: size.width * 0.4,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            (size.width - textPainter.width) / 2,
            (size.height * 0.8 - textPainter.height) / 2,
          ),
        );
      }
    } else {
      // 살아있는 풍선: 실제 풍선 모양
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      
      final strokePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      
      // 풍선 본체 (타원형)
      final balloonRect = Rect.fromLTWH(
        size.width * 0.1,
        size.height * 0.05,
        size.width * 0.8,
        size.height * 0.7,
      );
      canvas.drawOval(balloonRect, paint);
      canvas.drawOval(balloonRect, strokePaint);
      
      // 반짝임 효과 (터질 때)
      if (sparkleProgress > 0) {
        final sparklePaint = Paint()
          ..color = Colors.white.withOpacity(sparkleProgress * 0.8)
          ..style = PaintingStyle.fill
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * sparkleProgress);
        
        // 중심에서 퍼지는 별 모양
        final center = Offset(size.width / 2, size.height / 2);
        final sparklePath = Path();
        
        for (int i = 0; i < 8; i++) {
          final angle = (i * math.pi / 4) - math.pi / 2;
          final distance = 15 * sparkleProgress;
          final x = center.dx + math.cos(angle) * distance;
          final y = center.dy + math.sin(angle) * distance;
          
          if (i == 0) {
            sparklePath.moveTo(x, y);
          } else {
            sparklePath.lineTo(x, y);
          }
        }
        sparklePath.close();
        
        canvas.drawPath(sparklePath, sparklePaint);
        
        // 중심 원형 반짝임
        canvas.drawCircle(
          center,
          8 * sparkleProgress,
          sparklePaint,
        );
      }
      
      // 풍선 하단의 매듭 부분
      final knotPaint = Paint()
        ..color = color.withOpacity(0.6)
        ..style = PaintingStyle.fill;
      
      canvas.drawOval(
        Rect.fromLTWH(
          size.width * 0.45,
          size.height * 0.75,
          size.width * 0.1,
          size.height * 0.1,
        ),
        knotPaint,
      );
      
      // 풍선의 하이라이트 (반사광 효과)
      final highlightPaint = Paint()
        ..color = Colors.white.withOpacity(0.4)
        ..style = PaintingStyle.fill;
      
      canvas.drawOval(
        Rect.fromLTWH(
          size.width * 0.25,
          size.height * 0.15,
          size.width * 0.3,
          size.height * 0.25,
        ),
        highlightPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}