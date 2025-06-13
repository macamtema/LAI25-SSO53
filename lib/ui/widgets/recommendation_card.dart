// lib/ui/widgets/recommendation_card.dart

import 'package:flutter/material.dart';

class RecommendationCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? trailing;
  final int index;
  final VoidCallback? onDetailsPressed; // Tambahkan callback ini

  const RecommendationCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
    required this.index,
    this.onDetailsPressed, // Tambahkan ini di constructor
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(child: Text('${index + 1}')),
        title: Text(title),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600])),
        trailing: onDetailsPressed != null
            ? TextButton(
                onPressed: onDetailsPressed,
                child: const Text('Detail'),
              )
            : (trailing != null ? Text(trailing!) : null),
      ),
    );
  }
}
