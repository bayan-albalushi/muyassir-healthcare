import 'package:flutter/material.dart';

import 'package:smooth_page_indicator/smooth_page_indicator.dart';

class OnboardingScreen extends StatefulWidget {

  const OnboardingScreen({super.key});

  @override

  State<OnboardingScreen> createState() => _OnboardingScreenState();

}

class _OnboardingScreenState extends State<OnboardingScreen> {

  final PageController _controller = PageController();

  bool onLastPage = false;

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: Colors.teal[50],

      body: SafeArea(

        child: Column(

          children: [

            Expanded(

              child: PageView(

                controller: _controller,

                onPageChanged: (index) {

                  setState(() {

                    onLastPage = (index == 2);

                  });

                },

                children: [

                  _buildPage(

                    image: 'assets/onboarding1.png',

                    title: 'Book from Anywhere',

                    description:

                    'Book appointments, order medicine, and access services right from your phone.',

                  ),

                  _buildPage(

                    image: 'assets/onboarding2.png',

                    title: 'Trusted Providers',

                    description:

                    'Connect with verified hospitals, pharmacies, and labs across Oman.',

                  ),

                  _buildPage(

                    image: 'assets/onboarding3.png',

                    title: 'Digital Healthcare',

                    description:

                    'Enjoy smart, secure, and simple health services — designed for you.',

                  ),

                ],

              ),

            ),

            Padding(

              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),

              child: Row(

                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [

                  SmoothPageIndicator(

                    controller: _controller,

                    count: 3,

                    effect: ExpandingDotsEffect(

                      activeDotColor: Colors.teal,

                      dotHeight: 8,

                      dotWidth: 10,

                    ),

                  ),

                  onLastPage

                      ? ElevatedButton(

                    onPressed: () {

                      Navigator.pushReplacementNamed(context, '/login');

                    },

                    style: ElevatedButton.styleFrom(

                      backgroundColor: Colors.teal,

                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),

                    ),

                    child: const Text('Get Started'),

                  )

                      : TextButton(

                    onPressed: () {

                      _controller.nextPage(

                          duration: const Duration(milliseconds: 300), curve: Curves.easeIn);

                    },

                    child: const Text('Next'),

                  ),

                ],

              ),

            ),

          ],

        ),

      ),

    );

  }

  Widget _buildPage({

    required String image,

    required String title,

    required String description,

  }) {

    return Padding(

      padding: const EdgeInsets.all(32),

      child: Column(

        mainAxisAlignment: MainAxisAlignment.center,

        children: [

          Image.asset(image, height: 250),

          const SizedBox(height: 40),

          Text(

            title,

            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),

            textAlign: TextAlign.center,

          ),

          const SizedBox(height: 16),

          Text(

            description,

            style: const TextStyle(fontSize: 16, color: Colors.black54),

            textAlign: TextAlign.center,

          ),

        ],

      ),

    );

  }

}