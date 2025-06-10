import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 추가
import 'package:tiiun/design_system/colors.dart';
import 'package:tiiun/design_system/typography.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tiiun/services/firebase_service.dart'; // 추가

class SignupPage extends ConsumerStatefulWidget { // StatefulWidget -> ConsumerStatefulWidget 변경
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState(); // State -> ConsumerState 변경
}

class _SignupPageState extends ConsumerState<SignupPage> { // State -> ConsumerState 변경
  int _currentStep = 1; // 1: 정보입력, 2: 완료

  // 컨트롤러들
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmController = TextEditingController();
  final _nicknameController = TextEditingController();
  // final _firebaseService = FirebaseService(); // 제거 - Provider를 통해 접근할 예정

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscurePasswordConfirm = true;

  // 유효성 검사 상태 추가
  bool _isEmailValid = false;
  bool _isPasswordValid = false;
  bool _isPasswordConfirmValid = false;
  bool _isNicknameValid = false;
  String? _emailError;
  String? _passwordError;
  String? _passwordConfirmError;
  String? _nicknameError;

  @override
  void initState() {
    super.initState();
    // 텍스트 변경 감지
    _emailController.addListener(_validateForm);
    _passwordController.addListener(_validateForm);
    _passwordConfirmController.addListener(_validateForm);
    _nicknameController.addListener(_validateForm);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }

  // 실시간 폼 유효성 검사
  void _validateForm() {
    setState(() {
      // 이메일 검사
      String email = _emailController.text.trim();
      if (email.isEmpty) {
        _isEmailValid = false;
        _emailError = null;
      } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
        _isEmailValid = false;
        _emailError = '이메일 형식을 확인해주세요';
      } else {
        _isEmailValid = true;
        _emailError = null;
      }

      // 비밀번호 검사
      String password = _passwordController.text;
      if (password.isEmpty) {
        _isPasswordValid = false;
        _passwordError = null;
      } else if (password.length < 8) {
        _isPasswordValid = false;
        _passwordError = '비밀번호는 최소 8자 이상이어야 합니다';
      } else if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)').hasMatch(password)) {
        _isPasswordValid = false;
        _passwordError = '영문과 숫자를 포함해야 합니다';
      } else {
        _isPasswordValid = true;
        _passwordError = null;
      }

      // 비밀번호 확인 검사
      String passwordConfirm = _passwordConfirmController.text;
      if (passwordConfirm.isEmpty) {
        _isPasswordConfirmValid = false;
        _passwordConfirmError = null;
      } else if (passwordConfirm != password) {
        _isPasswordConfirmValid = false;
        _passwordConfirmError = '비밀번호가 일치하지 않습니다';
      } else {
        _isPasswordConfirmValid = true;
        _passwordConfirmError = null;
      }

      // 닉네임 검사
      String nickname = _nicknameController.text.trim();
      if (nickname.isEmpty) {
        _isNicknameValid = false;
        _nicknameError = null;
      } else if (nickname.length < 2) {
        _isNicknameValid = false;
        _nicknameError = '닉네임은 최소 2자 이상이어야 합니다';
      } else {
        _isNicknameValid = true;
        _nicknameError = null;
      }
    });
  }

  // 가입하기 버튼 활성화 여부
  bool get _isFormValid => _isEmailValid && _isPasswordValid && _isPasswordConfirmValid && _isNicknameValid;

  // 다음 단계로 이동
  void _nextStep() {
    setState(() {
      _currentStep++;
    });
  }

  // 이전 단계로 이동
  void _previousStep() {
    if (_currentStep > 1) {
      setState(() {
        _currentStep--;
      });
    } else {
      Navigator.pop(context); // 로그인 페이지로 돌아가기
    }
  }

  // Firebase 회원가입 처리 - 수정된 부분
  Future<void> _handleSignUp() async {
    if (!_isFormValid) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Provider를 통해 FirebaseService 접근
      final firebaseService = ref.read(firebaseServiceProvider);

      final userModel = await firebaseService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        userName: _nicknameController.text.trim(), // nickname → userName
      );

      if (userModel != null) {
        // 회원가입 성공 - Step 2로 이동
        if (mounted) {
          _nextStep();
        }
      } else {
        // 회원가입 실패
        if (mounted) {
          _showErrorSnackBar('회원가입에 실패했습니다. 다시 시도해주세요.');
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = _getErrorMessage(e.code);
      if (mounted) {
        _showErrorSnackBar(errorMessage);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('회원가입 중 오류가 발생했습니다: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 에러 메시지 변환
  String _getErrorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return '이미 사용 중인 이메일입니다.';
      case 'weak-password':
        return '비밀번호가 너무 약합니다. 더 강한 비밀번호를 사용해주세요.';
      case 'invalid-email':
        return '유효하지 않은 이메일 형식입니다.';
      case 'operation-not-allowed':
        return '이메일/비밀번호 계정이 비활성화되었습니다.';
      default:
        return '회원가입 중 오류가 발생했습니다.';
    }
  }

  // 에러 스낵바 표시
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppTypography.b2),
        backgroundColor: AppColors.point900,
      ),
    );
  }

  // HomePage로 이동
  void _navigateToHome() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home',
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: _buildCurrentStep(),
      ),
    );
  }

  // 현재 단계에 맞는 위젯 반환
  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      default:
        return _buildStep1();
    }
  }

  // Step 1: 정보 입력 화면
  Widget _buildStep1() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 헤더 (고정)
            _buildHeaderWithTitle(),

            // 입력 필드들 (자동 확장)
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 중앙 정렬을 위한 여백
                    SizedBox(height: MediaQuery.of(context).size.height * 0.1),

                    // 이메일 라벨
                    Text(
                      '이메일',
                      style: AppTypography.b2.withColor(AppColors.grey800,),
                    ),
                    const SizedBox(height: 4),

                    // 이메일 입력 필드
                    _buildTextFormField(
                      controller: _emailController,
                      hintText: '이메일 입력',
                      keyboardType: TextInputType.emailAddress,
                      hasError: _emailError != null,
                      isValid: _isEmailValid,
                    ),

                    // 이메일 에러 메시지
                    if (_emailError != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _emailError!,
                        style: AppTypography.c1.withColor(AppColors.point900,),
                      ),
                    ],

                    const SizedBox(height: 28),

                    // 비밀번호 라벨
                    Text(
                      '비밀번호',
                      style: AppTypography.b2.withColor(AppColors.grey900,),
                    ),
                    const SizedBox(height: 4),

                    // 비밀번호 입력 필드
                    _buildPasswordField(),

                    // 비밀번호 에러 메시지
                    if (_passwordError != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _passwordError!,
                        style: AppTypography.c1.withColor(AppColors.point900,),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // 비밀번호 확인 라벨
                    Text(
                      '비밀번호 확인',
                      style: AppTypography.b2.withColor(AppColors.grey900,),
                    ),
                    const SizedBox(height: 4),

                    // 비밀번호 확인 입력 필드
                    _buildPasswordConfirmField(),

                    // 비밀번호 확인 에러 메시지
                    if (_passwordConfirmError != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _passwordConfirmError!,
                        style: AppTypography.c1.withColor(AppColors.point900,),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // 닉네임 라벨
                    Text(
                      '닉네임',
                      style: AppTypography.b2.withColor(AppColors.grey900,),
                    ),
                    const SizedBox(height: 4),

                    // 닉네임 입력 필드
                    _buildTextFormField(
                      controller: _nicknameController,
                      hintText: '닉네임 입력 (한글, 영문, 숫자)',
                      hasError: _nicknameError != null,
                      isValid: _isNicknameValid,
                    ),

                    // 닉네임 에러 메시지
                    if (_nicknameError != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _nicknameError!,
                        style: AppTypography.c1.withColor(AppColors.point900,),
                      ),
                    ],

                    // 하단 여백
                    SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                  ],
                ),
              ),
            ),

            // 하단 가입하기 버튼 (고정)
            _buildSignUpButton(),
          ],
        ),
      ),
    );
  }

  // Step 2: 완료 화면
  Widget _buildStep2() {
    return Stack(
      children: [
        // 환영 문구 (절대 위치로 고정)
        Positioned(
          top: 80,
          left: 20,
          child: Text(
            "환영해요!\n틔운버디와 추억을 만들어요",
            style: AppTypography.h4.copyWith(
              color: AppColors.grey900,
              height: 1.5,
            ),
            textAlign: TextAlign.left,
          ),
        ),

        // 나머지 콘텐츠 (중앙 이미지와 하단 버튼)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              // 상단 여백 (자동 조절)
              Expanded(flex: 1, child: SizedBox()),

              // 환영 이미지 (고정)
              Center(
                child: Image.asset(
                  'assets/images/logos/illust_welcome.png',
                  width: 200,
                  height: 200,
                ),
              ),

              // 이미지와 버튼 사이 여백 (자동 조절)
              Expanded(flex: 1, child: SizedBox()),

              // 시작하기 버튼 (고정)
              _buildStartButton(),

              const SizedBox(height: 36),
            ],
          ),
        ),
      ],
    );
  }

  // 헤더 + 타이틀
  Widget _buildHeaderWithTitle() {
    return Container(
      height: 56,
      child: Stack(
        children: [
          // 뒤로가기 버튼 (왼쪽)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: IconButton(
              onPressed: _previousStep,
              icon: SvgPicture.asset(
                'assets/icons/functions/back.svg',
                width: 24,
                height: 24,
                color: AppColors.grey700,
              ),
            ),
          ),
          // 제목 (가운데)
          Center(
            child: Text(
              '회원가입',
              style: AppTypography.b2.withColor(AppColors.grey900,),
            ),
          ),
        ],
      ),
    );
  }

  // 일반 텍스트 필드
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    bool hasError = false,
    bool isValid = false,
  }) {
    Color getBorderColor() {
      if (hasError) return AppColors.point800;
      if (isValid) return AppColors.main700;
      return AppColors.grey300;
    }

    return Container(
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: AppTypography.b1,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTypography.b1.withColor(AppColors.grey400,),
          border: UnderlineInputBorder(
            borderSide: BorderSide(
              color: getBorderColor(),
              width: 1.5,
            ),
          ),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: getBorderColor(),
              width: 1.5,
            ),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(
              color: getBorderColor(), // 동적으로 색상 결정
              width: 1.5,
            ),
          ),
          contentPadding: EdgeInsets.only(left: 8),
        ),
      ),
    );
  }

  // 비밀번호 필드
  Widget _buildPasswordField() {
    Color getBorderColor() {
      if (_passwordError != null) return AppColors.point800;
      if (_isPasswordValid) return AppColors.main700;
      return AppColors.grey300;
    }

    return Container(
      height: 48,
      child: Stack(
        children: [
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: AppTypography.b2,
            decoration: InputDecoration(
              hintText: '비밀번호 입력 (숫자, 영문 포함 8자 이상)',
              hintStyle: AppTypography.b1.withColor(AppColors.grey400,),
              border: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: getBorderColor(),
                  width: 1.5,
                ),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: getBorderColor(),
                  width: 1.5,
                ),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: getBorderColor(), // 동적으로 색상 결정
                  width: 1.5,
                ),
              ),
              contentPadding: EdgeInsets.only(left: 8),
            ),
          ),

          // 비밀번호 표시/숨김 아이콘
          Positioned(
            right: 0,
            top: 12,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
              child: SvgPicture.asset(
                _obscurePassword
                    ? 'assets/icons/functions/icon_dontshow.svg'
                    : 'assets/icons/functions/icon_show.svg',
                width: 24,
                height: 24,
                color: AppColors.grey500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 비밀번호 확인 필드
  Widget _buildPasswordConfirmField() {
    Color getBorderColor() {
      if (_passwordConfirmError != null) return AppColors.point800;
      if (_isPasswordConfirmValid) return AppColors.main700;
      return AppColors.grey300;
    }

    return Container(
      height: 48,
      child: Stack(
        children: [
          TextFormField(
            controller: _passwordConfirmController,
            obscureText: _obscurePasswordConfirm,
            style: AppTypography.b2,
            decoration: InputDecoration(
              hintText: '동일한 비밀번호 입력',
              hintStyle: AppTypography.b1.withColor(AppColors.grey400,),
              border: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: getBorderColor(),
                  width: 1.5,
                ),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: getBorderColor(),
                  width: 1.5,
                ),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: getBorderColor(), // 동적으로 색상 결정
                  width: 1.5,
                ),
              ),
              contentPadding: EdgeInsets.only(left: 8),
            ),
          ),

          // 비밀번호 표시/숨김 아이콘
          Positioned(
            right: 0,
            top: 12,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _obscurePasswordConfirm = !_obscurePasswordConfirm;
                });
              },
              child: SvgPicture.asset(
                _obscurePasswordConfirm
                    ? 'assets/icons/functions/icon_dontshow.svg'
                    : 'assets/icons/functions/icon_show.svg',
                width: 24,
                height: 24,
                color: AppColors.grey500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 가입하기 버튼
  Widget _buildSignUpButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: (_isFormValid && !_isLoading) ? _handleSignUp : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isFormValid ? AppColors.main700 : AppColors.grey400,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          overlayColor: AppColors.main200,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
            : Text(
          '가입하기',
          style: AppTypography.s2.withColor(
            _isFormValid ? Colors.white : AppColors.grey500,
          ),
        ),
      ),
    );
  }

  // 시작하기 버튼
  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _navigateToHome,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.main700,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          overlayColor: AppColors.main200,
        ),
        child: Text(
          '시작하기',
          style: AppTypography.s2.withColor(Colors.white,),
        ),
      ),
    );
  }
}