// lib/ui/home_page.dart

import 'package:disaster_reco/ui/tabs/pasca_bencana_tab.dart';
import 'package:disaster_reco/ui/tabs/pra_bencana_tab.dart';
import 'package:disaster_reco/ui/tabs/saat_bencana_tab.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rekomendasi Bencana'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.security), text: 'Pra-Bencana'),
            Tab(icon: Icon(Icons.warning), text: 'Saat Bencana'),
            Tab(icon: Icon(Icons.healing), text: 'Pasca-Bencana'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [PraBencanaTab(), SaatBencanaTab(), PascaBencanaTab()],
      ),
    );
  }
}
