import 'package:flutter/material.dart';
import 'auth_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  late final List<OnboardingPage> _pages = [
    OnboardingPage(
      image: Icons.flight_takeoff,
      title: 'Condividi il Taxi dall\'Aeroporto',
      description:
          'Trova altri viaggiatori del tuo stesso volo e risparmia fino al 75% sul costo del taxi.',
      color: Colors.blue,
    ),
    OnboardingPage(
      image: Icons.people,
      title: 'Matching Intelligente',
      description:
          'L’algoritmo ti abbina con persone che vanno nella tua direzione.',
      color: Colors.green,
    ),
    OnboardingPage(
      image: Icons.chat,
      title: 'Chat con Traduzione',
      description:
          'Parla con viaggiatori internazionali grazie alla traduzione automatica.',
      color: Colors.orange,
    ),
    OnboardingPage(
      image: Icons.verified_user,
      title: 'Sistema di Reputazione',
      description:
          'Utenti verificati e valutazioni affidabili per viaggiare in sicurezza.',
      color: Colors.purple,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header con Skip / Indietro
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    IconButton(
                      tooltip: 'Indietro',
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOut,
                      ),
                    )
                  else
                    const SizedBox(width: 48),
                  const Spacer(),
                  TextButton(
                    onPressed: _goToAuth,
                    child: const Text('Salta'),
                  ),
                ],
              ),
            ),

            // PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemCount: _pages.length,
                itemBuilder: (context, index) => _buildPage(_pages[index]),
              ),
            ),

            // Dots indicator
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (i) => _buildDot(i == _currentPage),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // CTA
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed:
                      _currentPage == _pages.length - 1 ? _goToAuth : _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pages[_currentPage].color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (w, a) =>
                        FadeTransition(opacity: a, child: w),
                    child: Text(
                      _currentPage == _pages.length - 1 ? 'Inizia ora' : 'Avanti',
                      key: ValueKey(_currentPage == _pages.length - 1),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Link Accedi (opzionale)
            TextButton(
              onPressed: _goToAuth,
              child: Text(
                'Hai già un account? Accedi',
                style: TextStyle(color: cs.primary),
              ),
            ),

            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxIcon = (constraints.maxWidth * 0.28).clamp(96, 140).toDouble();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Semantics(
                label: page.title,
                child: Icon(page.image, size: maxIcon, color: page.color),
              ),
              const SizedBox(height: 36),
              Text(
                page.title,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: page.color,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                page.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.8),
                      height: 1.5,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDot(bool isActive) {
    final color = isActive
        ? _pages[_currentPage].color
        : Colors.grey.withOpacity(0.35);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  void _goToAuth() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

class OnboardingPage {
  final IconData image;
  final String title;
  final String description;
  final Color color;

  OnboardingPage({
    required this.image,
    required this.title,
    required this.description,
    required this.color,
  });
}
