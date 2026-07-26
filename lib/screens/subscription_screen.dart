import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:junko_bodie/providers/auth_provider.dart';
import '../services/purchases_service.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final _purchasesService = PurchasesService();
  List<Package> _packages = [];
  bool _isLoading = true;
  bool _isSubscribed = false;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    setState(() => _isLoading = true);
    try {
      final isSub = await _purchasesService.isSubscribed();
      final packages = await _purchasesService.getOfferings();
      
      if (mounted) {
        setState(() {
          _isSubscribed = isSub;
          _packages = packages;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _purchasePackage(Package package) async {
    setState(() => _isLoading = true);
    final success = await _purchasesService.purchasePackage(package);
    
    if (mounted) {
      if (success) {
        _isSubscribed = true;
        // Update global auth state
        await context.read<AuthProvider>().checkSubscription();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Subscription successful! Welcome to the club.')),
          );
          context.go('/lobby');
        }
      } else {
        setState(() {
          _isLoading = false;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchase cancelled or failed.')),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium Access'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isSubscribed
              ? _buildActiveSubscriptionView()
              : _buildPackagesView(),
    );
  }

  Widget _buildActiveSubscriptionView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.star, size: 80, color: Colors.amber),
          SizedBox(height: 16),
          Text(
            'You are Premium!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text('Thank you for subscribing.'),
        ],
      ),
    );
  }

  Widget _buildPackagesView() {
    if (_packages.isEmpty) {
      return const Center(child: Text('No subscription packages available right now.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _packages.length,
      itemBuilder: (context, index) {
        final package = _packages[index];
        final isMonthly = package.packageType == PackageType.monthly;

        return Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  package.storeProduct.title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(package.storeProduct.description),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          package.storeProduct.priceString,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        if (isMonthly)
                          const Text(
                            '7 Days Free Trial!',
                            style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () => _purchasePackage(package),
                      child: const Text('Subscribe'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
