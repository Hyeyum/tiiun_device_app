import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tiiun/design_system/colors.dart';
import 'package:tiiun/design_system/typography.dart';
import 'package:tiiun/pages/onboarding/lgsignin_page.dart';
import 'signup_page.dart';
import 'package:flutter_svg/flutter_svg.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // 이메일/비밀번호 로그인 관련
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _showEmailLogin = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _forceLogout();
  }

  Future<void> _forceLogout() async {
    try {
      await FirebaseAuth.instance.signOut();
      print('LoginPage: Force logout completed');
    } catch (e) {
      print('LoginPage logout error: $e');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // 중앙 로고 영역 (자동 확장)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 로고
                    SvgPicture.asset(
                      'assets/images/logos/tiiun_logo.svg',
                      width: 70.21,
                      height: 35.26,
                    ),
                    const SizedBox(height: 19),
                    SvgPicture.asset(
                      'assets/images/logos/tiiun_buddy_logo.svg',
                      width: 148.32,
                      height: 27.98,
                    ),
                  ],
                ),
              ),

              // 소셜 로그인 버튼들 또는 이메일 로그인 폼 (하단 고정)
              Column(
                children: [
                  if (!_showEmailLogin) ...[
                    // 소셜 로그인 버튼들
                    _buildSocialLoginButton(
                      'LG 계정 로그인',
                      'assets/images/logos/lg_logo.png',
                      Color(0xFF97282F),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => LGSigninPage()),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildSocialLoginButton(
                      'Google 계정으로 로그인',
                      'assets/images/logos/google_logo.png',
                      Color(0xFF477BDF),
                      onTap: _handleGoogleLogin,
                    ),
                    const SizedBox(height: 10),
                    _buildSocialLoginButton(
                      'Apple 계정으로 로그인',
                      'assets/images/logos/apple_logo.png',
                      Colors.black,
                    ),
                  ] else ...[
                    // 이메일/비밀번호 로그인 폼
                    _buildEmailLoginForm(),
                  ],

                  const SizedBox(height: 24),

                  // 다른 계정으로 로그인
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showEmailLogin = !_showEmailLogin;
                      });
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _showEmailLogin ? '소셜 로그인으로 돌아가기' : '다른 계정으로 로그인',
                          style: AppTypography.mediumBtn.withColor(AppColors.grey400,),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          _showEmailLogin ? Icons.arrow_back_ios_rounded : Icons.arrow_forward_ios_rounded,
                          color: AppColors.grey300,
                          size: 10,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Google 로그인 처리
  Future<void> _handleGoogleLogin() async {
    try {
      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(
            child: CircularProgressIndicator(),
          );
        },
      );

      // Google 계정으로 로그인
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // 사용자가 로그인을 취소한 경우
        Navigator.of(context, rootNavigator: true).pop();
        return;
      }

      // Google 인증 세부정보 가져오기
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Firebase 인증 자격증명 생성
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase Auth로 로그인 (회원가입이 자동으로 처리됨)
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      // 로딩 다이얼로그 닫기
      Navigator.of(context, rootNavigator: true).pop();

      if (user != null) {
        print('Google 로그인 성공: ${user.email}');
        print('사용자 UID: ${user.uid}');
        print('표시 이름: ${user.displayName}');

        // 홈페이지로 이동
        _navigateToHome();
      } else {
        throw Exception('사용자 정보를 가져올 수 없습니다.');
      }

    } catch (e) {
      // 로딩 다이얼로그 닫기
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // 에러 처리
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google 로그인에 실패했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
      print('Google 로그인 실패: $e');
    }
  }

  // 이메일/비밀번호 로그인 처리
  Future<void> _handleEmailLogin() async {
    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('이메일과 비밀번호를 모두 입력해주세요.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Firebase Auth로 이메일/비밀번호 로그인
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final User? user = userCredential.user;

      if (user != null) {
        print('이메일 로그인 성공: ${user.email}');
        print('사용자 UID: ${user.uid}');

        // 홈페이지로 이동
        _navigateToHome();
      } else {
        throw Exception('사용자 정보를 가져올 수 없습니다.');
      }

    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = '등록되지 않은 이메일입니다.';
          break;
        case 'wrong-password':
          errorMessage = '비밀번호가 올바르지 않습니다.';
          break;
        case 'invalid-email':
          errorMessage = '이메일 형식이 올바르지 않습니다.';
          break;
        case 'too-many-requests':
          errorMessage = '너무 많은 시도가 있었습니다. 잠시 후 다시 시도해주세요.';
          break;
        default:
          errorMessage = '로그인에 실패했습니다: ${e.message}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
      print('이메일 로그인 실패: $e');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('로그인에 실패했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
      print('이메일 로그인 실패: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // 회원가입 페이지로 이동
  void _navigateToSignup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SignupPage()),
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

  // 이메일/비밀번호 로그인 폼
  Widget _buildEmailLoginForm() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // 이메일 입력 필드
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: '이메일을 입력하세요',
              hintStyle: AppTypography.mediumBtn.withColor(AppColors.grey400),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.grey300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFF477BDF), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
          const SizedBox(height: 12),

          // 비밀번호 입력 필드
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: '비밀번호를 입력하세요',
              hintStyle: AppTypography.mediumBtn.withColor(AppColors.grey400),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.grey300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Color(0xFF477BDF), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
          const SizedBox(height: 16),

          // 로그인 버튼
          Container(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleEmailLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF477BDF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(60),
                ),
                disabledBackgroundColor: AppColors.grey300,
              ),
              child: _isLoading
                  ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : Text(
                '로그인',
                style: AppTypography.largeBtn.withColor(Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 회원가입 링크
          GestureDetector(
            onTap: _navigateToSignup,
            child: Text(
              '계정이 없으신가요? 회원가입',
              style: AppTypography.mediumBtn.withColor(Color(0xFF477BDF)),
            ),
          ),
        ],
      ),
    );
  }

  // 소셜 로그인 버튼
  Widget _buildSocialLoginButton(String text, dynamic iconOrPath, Color color, {VoidCallback? onTap}) {
    return Container(
      width: double.infinity,
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton(
        onPressed: onTap ?? () {
          print('$text 버튼 클릭됨');
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(60),
          ),
          padding: EdgeInsets.zero,
        ),
        child: Row(
          children: [
            SizedBox(width: 12),
            Image.asset(
              iconOrPath,
              width: 28,
              height: 28,
            ),
            Expanded(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: AppTypography.largeBtn.withColor(Colors.white,),
              ),
            ),
            SizedBox(width: 28),
          ],
        ),
      ),
    );
  }
}