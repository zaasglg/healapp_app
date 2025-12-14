import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_config.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Widget _roundedIcon(
    BuildContext context,
    IconData icon,
    String label, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6),
              ],
            ),
            child: Icon(icon, color: AppConfig.primaryColor, size: 34),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.firaSans(
              fontSize: 12,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _productCard(BuildContext context, String title, String price) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 96,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Icon(
                Icons.shopping_bag_outlined,
                size: 36,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.firaSans(
              fontSize: 12,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                price,
                style: GoogleFonts.firaSans(
                  fontWeight: FontWeight.w700,
                  color: Colors.grey.shade800,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppConfig.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+',
                  style: GoogleFonts.firaSans(
                    color: AppConfig.primaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: title + avatar
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'HealApp',
                          style: GoogleFonts.firaSans(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppConfig.primaryColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Забота о Вас - каждый час',
                          style: GoogleFonts.firaSans(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.person, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // icons row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _roundedIcon(
                    context,
                    Icons.account_circle,
                    'Мои роли',
                    onTap: () {},
                  ),
                  _roundedIcon(
                    context,
                    Icons.storefront,
                    'Маркет',
                    onTap: () {},
                  ),
                  _roundedIcon(
                    context,
                    Icons.calendar_today,
                    'Визиты',
                    onTap: () {},
                  ),
                  _roundedIcon(
                    context,
                    Icons.favorite,
                    'Дневник',
                    onTap: () => context.push('/diaries'),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // measurement card + health diary small tile
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Измерить артериальное\nдавление через: 00:38',
                            style: GoogleFonts.firaSans(
                              fontSize: 13,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppConfig.primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {},
                              child: Text(
                                'Записать',
                                style: GoogleFonts.firaSans(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.local_drink_outlined,
                            size: 36,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Дневник здоровья',
                            style: GoogleFonts.firaSans(
                              fontSize: 13,
                              color: Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // big view orders button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {},
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Посмотреть заказы',
                      style: GoogleFonts.firaSans(
                        fontSize: 16,
                        color: Colors.grey.shade800,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward, color: Colors.grey.shade600),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // product grid
              Text(
                'Популярные товары',
                style: GoogleFonts.firaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.78,
                children: List.generate(
                  4,
                  (i) => _productCard(
                    context,
                    'Vita Box - набор \nуходовых средств',
                    '12 000₽',
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
