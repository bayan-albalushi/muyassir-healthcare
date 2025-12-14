import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {

  final PageController _controller = PageController();

  // 📌 قيمة تعتمد عليها الأنيميشن المرتبطة بين الصفحات (Parallax)
  double pageOffset = 0.0;

  bool onLastPage = false;

  // 📌 Fade Animation للعنوان والوصف فقط
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // 🔥 هذا أهم شيء — يخلي الصور والكتابات تتحرك بناءً على السحب
    _controller.addListener(() {
      setState(() {
        pageOffset = _controller.page ?? 0;
      });
    });

    // Fade Animation للكتابة لما تتغير الصفحة
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50],

      body: SafeArea(
        child: Column(
          children: [

            // -------------------------------------------------
            //                  PAGEVIEW
            // -------------------------------------------------
            Expanded(
              child: PageView(
                controller: _controller,

                onPageChanged: (index) {
                  setState(() => onLastPage = (index == 2));

                  // إعادة تشغيل Fade Animation عند تغيير الصفحة
                  _fadeController.forward(from: 0);
                },

                children: [
                  _buildPage(
                    index: 0,
                    image: "assets/onboarding1.png",
                    title: "Book from Anywhere",
                    description:
                    "Book appointments, order medicine, and access services right from your phone.",
                  ),
                  _buildPage(
                    index: 1,
                    image: "assets/onboarding2.png",
                    title: "Trusted Providers",
                    description:
                    "Connect with verified hospitals, pharmacies, and labs across Oman.",
                  ),
                  _buildPage(
                    index: 2,
                    image: "assets/onboarding3.png",
                    title: "Digital Healthcare",
                    description:
                    "Enjoy smart, secure, and simple health services — designed for you.",
                  ),
                ],
              ),
            ),

            // -------------------------------------------------
            //                INDICATOR + BUTTONS
            // -------------------------------------------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [

                  SmoothPageIndicator(
                    controller: _controller,
                    count: 3,
                    effect: ExpandingDotsEffect(
                      activeDotColor: Colors.blue,
                      dotHeight: 8,
                      dotWidth: 10,
                    ),
                  ),

                  onLastPage
                      ? ElevatedButton(
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, '/login'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Text("Get Started"),
                  )
                      : TextButton(
                    onPressed: () {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: const Text("Next"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================
  //           🔥🔥 ADVANCED ANIMATED PAGE (Parallax + Fade)
  // =========================================================
  Widget _buildPage({
    required int index,
    required String image,
    required String title,
    required String description,
  }) {
    // الفرق بين الصفحة الحالية والصفحة المطلوب عرضها
    double diff = pageOffset - index;

    return AnimatedBuilder(
      animation: _fadeAnimation,

      // ----------------------------------------------------
      //    🔥 Fade + Slide-down للانتقال بين الصفحات
      // ----------------------------------------------------
      builder: (_, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, 25 * (1 - _fadeAnimation.value)),
            child: child,
          ),
        );
      },

      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            // ----------------------------------------------------
            //      🔥🔥 صورة متصلة تتحرك مع السحب (Parallax)
            // ----------------------------------------------------
            Transform.translate(
              offset: Offset(diff * -180, 0), // ← الحركة الرئيسية
              child: Transform.scale(
                scale: 1 - (diff.abs() * 0.08), // Zoom بسيط احترافي
                child: Image.asset(image, height: 250),
              ),
            ),

            const SizedBox(height: 40),

            // ----------------------------------------------------
            //      🔥🔥 عنوان يتحرّك مع الصفحة (Connected Text)
            // ----------------------------------------------------
            Transform.translate(
              offset: Offset(0, diff * 35), // حركة للعنوان
              child: AnimatedOpacity(
                opacity: (1 - diff.abs()).clamp(0.0, 1.0),
                duration: const Duration(milliseconds: 250),
                child: Text(
                  title,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ----------------------------------------------------
            //     🔥🔥 وصف مرتبط بالعنوان (Connected Description)
            // ----------------------------------------------------
            Transform.translate(
              offset: Offset(0, diff * 22),
              child: AnimatedOpacity(
                opacity: (1 - diff.abs() * 1.1).clamp(0.0, 1.0),
                duration: const Duration(milliseconds: 250),
                child: Text(
                  description,
                  style:
                  const TextStyle(fontSize: 16, color: Colors.black54),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}
