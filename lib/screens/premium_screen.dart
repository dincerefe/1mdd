import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:digital_diary/services/payment_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> with SingleTickerProviderStateMixin {
  final PaymentService _paymentService = PaymentService();
  bool _isLoading = true;
  bool _isPurchasing = false;
  bool _isPremium = false;
  String? _errorMessage;
  DateTime? _subscriptionDate; // Subscription purchase date
  String? _subscriptionType; // 'monthly' or 'yearly'
  ProductDetails? _selectedProduct; // Currently selected product
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
    _initializePayment();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializePayment() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    // Set up callbacks
    _paymentService.onPurchaseComplete = (success, message) {
      if (!mounted) return;
      setState(() => _isPurchasing = false);
      
      if (success) {
        _showSuccessDialog();
      } else {
        _showInfoDialog(
          title: 'Purchase Status',
          message: message,
          icon: Icons.info_outline,
          iconColor: Colors.orange,
        );
      }
    };

    _paymentService.onPurchaseError = (error) {
      if (!mounted) return;
      setState(() => _isPurchasing = false);
      
      _showInfoDialog(
        title: 'Purchase Error',
        message: _getReadableErrorMessage(error),
        icon: Icons.error_outline,
        iconColor: Colors.red,
      );
    };

    try {
      // Check premium status first
      _isPremium = await _paymentService.checkPremiumStatus();
      
      // Get subscription details from Firebase
      if (_isPremium) {
        await _loadSubscriptionDetails();
      }
      
      // Initialize payment service
      await _paymentService.initialize().timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw Exception('Connection timeout');
        },
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          // Set default selected product to yearly if available
          if (_paymentService.yearlyProduct != null) {
            _selectedProduct = _paymentService.yearlyProduct;
          } else if (_paymentService.monthlyProduct != null) {
            _selectedProduct = _paymentService.monthlyProduct;
          }
          if (!_paymentService.isAvailable && !_isPremium) {
            _errorMessage = 'Store connection unavailable';
          } else if (_paymentService.products.isEmpty && !_isPremium) {
            _errorMessage = 'Products loading...';
          }
        });
        _animationController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (!_isPremium) {
            _errorMessage = 'Unable to connect to store';
          }
        });
        _animationController.forward();
      }
    }
  }

  Future<void> _loadSubscriptionDetails() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final data = doc.data();
      if (data != null) {
        final timestamp = data['premiumPurchaseDate'];
        if (timestamp != null && timestamp is Timestamp) {
          _subscriptionDate = timestamp.toDate();
        }
        _subscriptionType = data['premiumProductId'] as String?;
      }
    } catch (e) {
      print('Error loading subscription details: $e');
    }
  }

  String _getReadableErrorMessage(String error) {
    if (error.contains('BillingResponse.userCanceled')) {
      return 'Purchase was cancelled.';
    } else if (error.contains('BillingResponse.itemAlreadyOwned')) {
      return 'You already own this subscription.';
    } else if (error.contains('BillingResponse.networkError') || 
               error.contains('network')) {
      return 'Network error. Please check your internet connection.';
    } else if (error.contains('timeout')) {
      return 'Connection timed out. Please try again.';
    }
    return 'Something went wrong. Please try again later.';
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.green, Colors.teal],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Welcome to Premium!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Thank you for your purchase. Enjoy all premium features!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context, true); // Return to previous screen
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Start Exploring',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showInfoDialog({
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
  }) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 40),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: iconColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _purchase(ProductDetails product) async {
    if (_isPremium) {
      _showInfoDialog(
        title: 'Already Premium',
        message: 'You already have an active premium subscription!',
        icon: Icons.workspace_premium,
        iconColor: Colors.deepOrange,
      );
      return;
    }
    setState(() => _isPurchasing = true);
    await _paymentService.purchaseProduct(product);
  }

  Future<void> _restorePurchases() async {
    setState(() => _isPurchasing = true);
    await _paymentService.restorePurchases();
    
    await Future.delayed(const Duration(seconds: 2));
    
    final isPremium = await _paymentService.checkPremiumStatus();
    
    setState(() {
      _isPurchasing = false;
      _isPremium = isPremium;
    });
    
    if (mounted) {
      if (isPremium) {
        _showSuccessDialog();
      } else {
        _showInfoDialog(
          title: 'No Purchases Found',
          message: 'We couldn\'t find any previous purchases associated with this account.',
          icon: Icons.info_outline,
          iconColor: Colors.orange,
        );
      }
    }
  }

  Future<void> _manageSubscription() async {
    final url = Uri.parse('https://play.google.com/store/account/subscriptions');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.black : Colors.grey[50];
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final cardColor = isDark ? Colors.grey[900] : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.close, color: textColor, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Colors.deepOrange),
                    const SizedBox(height: 16),
                    Text('Loading...', style: TextStyle(color: subtextColor)),
                  ],
                ),
              )
            : _isPurchasing
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const CircularProgressIndicator(color: Colors.deepOrange),
                              const SizedBox(height: 20),
                              Text(
                                'Processing your purchase...',
                                style: TextStyle(color: textColor, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Please wait',
                                style: TextStyle(color: subtextColor, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : ScaleTransition(
                    scale: _scaleAnimation,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          // Premium Badge - Different for premium users
                          _buildPremiumBadge(isDark),
                          const SizedBox(height: 28),

                          // Title - Different for premium users
                          Text(
                            _isPremium ? 'You\'re Premium!' : 'Upgrade to Premium',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isPremium 
                                ? 'Enjoy all premium features' 
                                : 'Unlock all features and create longer memories',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: subtextColor,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Features - Only 5 Minute Videos
                          _buildFeatureItem(
                            Icons.timer_outlined,
                            '5 Minute Videos',
                            _isPremium ? 'Unlocked ✓' : 'Record up to 5 minutes instead of 1',
                            isDark,
                            isUnlocked: _isPremium,
                          ),

                          const SizedBox(height: 32),

                          // Show different content based on premium status
                          if (_isPremium) ...[
                            // Premium user view
                            _buildPremiumStatusCard(isDark, textColor, subtextColor, cardColor),
                          ] else ...[
                            // Non-premium user view
                            if (_errorMessage != null && _paymentService.products.isEmpty)
                              _buildErrorCard(isDark, cardColor),
                              
                            // Products
                            if (_paymentService.products.isNotEmpty) ...[
                              if (_paymentService.yearlyProduct != null)
                                _buildProductCard(
                                  _paymentService.yearlyProduct!,
                                  isDark,
                                  isBestValue: true,
                                ),
                              if (_paymentService.monthlyProduct != null)
                                _buildProductCard(
                                  _paymentService.monthlyProduct!,
                                  isDark,
                                ),
                              
                              const SizedBox(height: 16),
                              
                              // Upgrade Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _selectedProduct != null 
                                      ? () => _purchase(_selectedProduct!)
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepOrange,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: Colors.grey.shade400,
                                    disabledForegroundColor: Colors.white70,
                                    padding: const EdgeInsets.symmetric(vertical: 18),
                                    elevation: 4,
                                    shadowColor: Colors.deepOrange.withOpacity(0.4),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.workspace_premium, size: 22),
                                      const SizedBox(width: 10),
                                      Text(
                                        _selectedProduct != null
                                            ? 'Upgrade Now – ${_selectedProduct!.price}'
                                            : 'Select a Plan',
                                        style: const TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ] else if (_errorMessage == null) ...[
                              _buildPlaceholderCard('Premium Yearly', '\$29.99/year', isDark, true),
                              _buildPlaceholderCard('Premium Monthly', '\$4.99/month', isDark, false),
                            ],

                            const SizedBox(height: 20),

                            // Restore Purchases
                            TextButton.icon(
                              onPressed: _restorePurchases,
                              icon: const Icon(Icons.restore, color: Colors.deepOrange),
                              label: Text(
                                'Restore Purchases',
                                style: TextStyle(
                                  color: Colors.deepOrange[700],
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          // Terms
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              _isPremium
                                  ? 'Manage your subscription in Google Play Store settings.'
                                  : 'Subscription automatically renews unless canceled at least 24 hours before the end of the current period. You can manage your subscription in Google Play Store settings.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: subtextColor,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildPremiumBadge(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isPremium 
              ? [Colors.amber, Colors.orange] 
              : [Colors.orange, Colors.deepOrange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: (_isPremium ? Colors.amber : Colors.deepOrange).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Icon(
        _isPremium ? Icons.verified : Icons.workspace_premium,
        size: 64,
        color: Colors.white,
      ),
    );
  }

  Widget _buildPremiumStatusCard(bool isDark, Color textColor, Color? subtextColor, Color? cardColor) {
    // Calculate renewal date based on subscription type
    String renewalText = 'All premium features unlocked';
    if (_subscriptionDate != null) {
      DateTime renewalDate;
      if (_subscriptionType != null && _subscriptionType!.contains('yearly')) {
        renewalDate = _subscriptionDate!.add(const Duration(days: 365));
      } else {
        renewalDate = _subscriptionDate!.add(const Duration(days: 30));
      }
      renewalText = 'Renews on ${DateFormat('MMM d, yyyy').format(renewalDate)}';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.green.withOpacity(0.3), width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.verified, color: Colors.green, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Active Subscription',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      renewalText,
                      style: TextStyle(
                        fontSize: 14,
                        color: subtextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _manageSubscription,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Manage Subscription'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.deepOrange,
                side: const BorderSide(color: Colors.deepOrange),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(bool isDark, Color? cardColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.cloud_off, color: Colors.orange, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _errorMessage ?? 'Connection Issue',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Please check your connection',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _isLoading = true;
                });
                _initializePayment();
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(
    IconData icon,
    String title,
    String subtitle,
    bool isDark, {
    bool isUnlocked = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (isUnlocked ? Colors.green : Colors.deepOrange).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon, 
              color: isUnlocked ? Colors.green : Colors.deepOrange, 
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isUnlocked 
                        ? Colors.green 
                        : (isDark ? Colors.grey[400] : Colors.grey[600]),
                    fontWeight: isUnlocked ? FontWeight.w500 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            isUnlocked ? Icons.check_circle : Icons.lock_outline,
            color: isUnlocked ? Colors.green : Colors.grey,
            size: 22,
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(
    ProductDetails product,
    bool isDark, {
    bool isBestValue = false,
  }) {
    final isYearly = product.id.contains('yearly');
    final cardColor = isDark ? Colors.grey[900] : Colors.white;
    final isSelected = _selectedProduct?.id == product.id;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedProduct = product;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? Colors.deepOrange : Colors.grey.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? Colors.deepOrange.withOpacity(0.15)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            // Radio button indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? Colors.deepOrange : Colors.grey,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.deepOrange,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isYearly ? 'Yearly' : 'Monthly',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (isBestValue) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.green, Colors.teal],
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'SAVE 50%',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  product.price,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.deepOrange[700],
                  ),
                ),
                Text(
                  isYearly ? '/year' : '/month',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderCard(
    String title,
    String price,
    bool isDark,
    bool isBestValue,
  ) {
    final cardColor = isDark ? Colors.grey[900] : Colors.white;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isBestValue ? Colors.deepOrange.withOpacity(0.5) : Colors.grey.withOpacity(0.2),
          width: isBestValue ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.grey.withOpacity(0.5),
                width: 2,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: (isDark ? Colors.white : Colors.black87).withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.grey.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Loading...',
                      style: TextStyle(
                        fontSize: 13,
                        color: (isDark ? Colors.grey[400] : Colors.grey[600])?.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            price,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.deepOrange[700]?.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}
