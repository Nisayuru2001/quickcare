import 'package:flutter/material.dart';

class FirstAidScreen extends StatelessWidget {
  const FirstAidScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFFE53935);
    final Color textColor = const Color(0xFF212121);
    final bool isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: [
                  Text(
                    'First Aid Instructions',
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFirstAidItem(
                      context,
                      title: 'Cardiac Arrest',
                      steps: [
                        'Check for responsiveness',
                        'Call emergency services (911) immediately',
                        'Begin CPR with 30 chest compressions followed by 2 rescue breaths',
                        'Continue until help arrives or an AED is available',
                      ],
                      icon: Icons.favorite_border,
                      primaryColor: primaryColor,
                      isDarkMode: isDarkMode,
                    ),

                    const SizedBox(height: 20),

                    _buildFirstAidItem(
                      context,
                      title: 'Severe Bleeding',
                      steps: [
                        'Apply direct pressure to the wound using a clean cloth',
                        'If possible, raise the injured area above heart level',
                        'Apply a tight bandage but not so tight it stops circulation',
                        'Do not remove the cloth if it soaks through - add another layer',
                        'Call emergency services if bleeding doesn\'t stop',
                      ],
                      icon: Icons.bloodtype_outlined,
                      primaryColor: primaryColor,
                      isDarkMode: isDarkMode,
                    ),

                    const SizedBox(height: 20),

                    _buildFirstAidItem(
                      context,
                      title: 'Choking',
                      steps: [
                        'Encourage the person to cough',
                        'If they can\'t cough, speak or breathe, stand behind them',
                        'Place one hand under their diaphragm',
                        'Give up to 5 abdominal thrusts (Heimlich maneuver)',
                        'Call emergency services if the obstruction doesn\'t clear',
                      ],
                      icon: Icons.air,
                      primaryColor: primaryColor,
                      isDarkMode: isDarkMode,
                    ),

                    const SizedBox(height: 20),

                    _buildFirstAidItem(
                      context,
                      title: 'Burns',
                      steps: [
                        'Remove the source of the burn',
                        'Cool the burn with cool (not cold) running water for 10-15 minutes',
                        'Remove jewelry or tight items from the burned area',
                        'Cover with a sterile, non-stick bandage',
                        'Do not apply butter, oil, or ointments to the burn',
                        'Seek medical help for severe or chemical burns',
                      ],
                      icon: Icons.local_fire_department_outlined,
                      primaryColor: primaryColor,
                      isDarkMode: isDarkMode,
                    ),

                    const SizedBox(height: 20),

                    _buildFirstAidItem(
                      context,
                      title: 'Stroke',
                      steps: [
                        'Remember FAST:',
                        '- Face: Ask the person to smile (does one side droop?)',
                        '- Arms: Ask the person to raise both arms (does one drift down?)',
                        '- Speech: Ask the person to repeat a simple phrase (is speech slurred?)',
                        '- Time: If any of these signs, call emergency services immediately',
                      ],
                      icon: Icons.sync_problem_outlined,
                      primaryColor: primaryColor,
                      isDarkMode: isDarkMode,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFirstAidItem(
      BuildContext context, {
        required String title,
        required List<String> steps,
        required IconData icon,
        required Color primaryColor,
        required bool isDarkMode,
      }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDarkMode ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: primaryColor,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          const SizedBox(height: 8),
          ...steps.map((step) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    fontSize: 16,
                  ),
                ),
                Expanded(
                  child: Text(
                    step,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}