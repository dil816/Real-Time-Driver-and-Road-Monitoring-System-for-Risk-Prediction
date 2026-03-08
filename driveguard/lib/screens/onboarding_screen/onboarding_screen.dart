import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import 'package:driveguard/provider/splash_provider/splash_provider.dart';
import 'package:driveguard/screens/main_navigation_screen/main_navigation_screen.dart';

class ProfessionalOnboarding extends StatefulWidget {
  const ProfessionalOnboarding({super.key});

  @override
  State<ProfessionalOnboarding> createState() =>
      _ProfessionalOnboardingState();
}

class _ProfessionalOnboardingState
    extends State<ProfessionalOnboarding> {

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    Provider.of<SplashProvider>(context,listen: false).checkFirstTimeUser().then((onValue){
      if(onValue??false){
        Navigator.pushReplacement(context, PageTransition(type: PageTransitionType.leftToRight,child: MainNavigationScreen()));
      }else{
        return;
      }
    });
  }

  final PageController _controller = PageController();
  int currentIndex = 0;

  final pages = const [
    OnboardContent(
      title: "Real-Time Driver Monitoring",
      description:
      "Continuously analyzes driver health to detect fatigue and drowsiness instantly.",
      icon: Icons.health_and_safety,
      color: Colors.green,
    ),
    OnboardContent(
      title: "Smart Road Prediction",
      description:
      "Predicts road conditions using real-time data to improve safety and awareness.",
      icon: Icons.route,
      color: Colors.orange,
    ),
    OnboardContent(
      title: "Instant Safety Alerts",
      description:
      "Triggers real-time warnings, sound alerts, and visual notifications for protection.",
      icon: Icons.warning_amber_rounded,
      color: Colors.red,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 60),
          SafeArea(
            child: Text("Road Predict", style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (index) {
                setState(() => currentIndex = index);
              },
              itemCount: pages.length,
              itemBuilder: (context, index) {
                return pages[index];
              },
            ),
          ),
          currentIndex == 2?SizedBox(
            width: 200,
            child: ElevatedButton(
                style: ButtonStyle(
                    foregroundColor: WidgetStatePropertyAll(Colors.white),
                    backgroundColor: MaterialStateProperty.all(Colors.green),
                    padding: MaterialStateProperty.all(const EdgeInsets.symmetric(horizontal: 40, vertical: 12)
                    )),
                onPressed: (){
                  Provider.of<SplashProvider>(context,listen: false).setFirstTimeUser(true);
                  Navigator.pushReplacement(context, PageTransition(type: PageTransitionType.leftToRight,child: MainNavigationScreen()));
                },
                child: Text("Next")
            ),
          ):SizedBox(),
          SizedBox(height: 20,),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              pages.length,
                  (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 6),
                height: 10,
                width: currentIndex == index ? 20 : 10,
                decoration: BoxDecoration(
                  color: currentIndex == index
                      ? Colors.blue
                      : Colors.grey,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class OnboardContent extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const OnboardContent({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 110, color: color,),
          const SizedBox(height: 30),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}