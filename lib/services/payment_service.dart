import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Debug print helper - only prints in debug mode
void _log(String message) {
  if (kDebugMode) {
    print(message);
  }
}

class PaymentService {
  static final PaymentService _instance = PaymentService._internal();
  factory PaymentService() => _instance;
  PaymentService._internal();

  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  
  // Product IDs - Google Play Console'da oluşturacağın ID'ler
  static const String premiumMonthlyId = 'premium_monthly';
  static const String premiumYearlyId = 'premium_yearly';
  
  static const Set<String> _productIds = {
    premiumMonthlyId,
    premiumYearlyId,
  };

  List<ProductDetails> products = [];
  bool isAvailable = false;
  bool isPremium = false;

  // Callbacks
  Function(bool success, String message)? onPurchaseComplete;
  Function(String error)? onPurchaseError;

  /// Initialize the payment service
  Future<void> initialize() async {
    _log('PaymentService: Starting initialization...');
    
    try {
      // Check if billing is available
      // Increased timeout for slower networks
      isAvailable = await _inAppPurchase.isAvailable().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _log('PaymentService: isAvailable timeout - check network connection');
          return false;
        },
      );
      
      _log('PaymentService: isAvailable = $isAvailable');
      
      if (!isAvailable) {
        _log('In-app purchases not available - This may be because:');
        _log('  1. Running on an emulator without Play Store');
        _log('  2. App not signed with release keystore');
        _log('  3. App not uploaded to Play Console (at least internal test track)');
        _log('  4. Google Play Store app not installed or not logged in');
        return;
      }

      // Listen to purchase updates
      _subscription = _inAppPurchase.purchaseStream.listen(
        _onPurchaseUpdated,
        onError: (error) {
          _log('Purchase stream error: $error');
          onPurchaseError?.call(error.toString());
        },
      );

      // Load products with retry logic
      await loadProducts();
      
      // Check existing purchases
      try {
        await checkPremiumStatus();
      } catch (e) {
        _log('PaymentService: Check premium warning: $e');
      }
      
      _log('PaymentService: Initialization complete. Products: ${products.length}');
    } catch (e) {
      _log('PaymentService: Initialization error: $e');
      isAvailable = false;
      // Do NOT rethrow, allow app to continue without payments
    }
  }

  /// Load available products from store with retry logic
  Future<void> loadProducts() async {
    if (!isAvailable) {
      _log('PaymentService: Store not available, skipping loadProducts');
      return;
    }

    const int maxRetries = 3;
    int attempt = 0;
    
    while (attempt < maxRetries) {
      attempt++;
      _log('PaymentService: Loading products... (attempt $attempt/$maxRetries)');
      _log('PaymentService: Querying product IDs: $_productIds');
      
      try {
        // Extended timeout for better reliability
        final ProductDetailsResponse response = await _inAppPurchase
            .queryProductDetails(_productIds)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                _log('PaymentService: queryProductDetails timeout on attempt $attempt');
                throw Exception('Product loading timeout');
              },
            );
        
        if (response.notFoundIDs.isNotEmpty) {
          _log('⚠️ Products NOT FOUND: ${response.notFoundIDs}');
          _log('   This usually means:');
          _log('   1. Product IDs in code don\'t match Play Console exactly');
          _log('   2. Subscriptions are not "Active" in Play Console');
          _log('   3. App version not published to any test track');
          _log('   4. Using wrong account (test account required)');
        }
        
        if (response.error != null) {
          _log('❌ Error loading products: ${response.error}');
          if (attempt < maxRetries) {
            await Future.delayed(const Duration(seconds: 2));
            continue;
          }
          return;
        }
        
        products = response.productDetails;
        _log('✅ Loaded ${products.length} products successfully');
        
        for (var product in products) {
          _log('   Product: ${product.id}');
          _log('     Title: ${product.title}');
          _log('     Description: ${product.description}');
          _log('     Price: ${product.price}');
        }
        
        // Success, exit retry loop
        return;
      } catch (e) {
        _log('❌ Error loading products (attempt $attempt): $e');
        if (attempt < maxRetries) {
          _log('   Retrying in 2 seconds...');
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }
    
    _log('❌ Failed to load products after $maxRetries attempts');
  }

  /// Handle purchase updates
  void _onPurchaseUpdated(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      _log('Purchase update: ${purchase.productID} - ${purchase.status}');
      
      switch (purchase.status) {
        case PurchaseStatus.pending:
          // Show loading indicator
          _log('Purchase pending...');
          break;
          
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          // Verify and deliver the product
          final valid = await _verifyPurchase(purchase);
          if (valid) {
            await _deliverProduct(purchase);
            onPurchaseComplete?.call(true, 'Purchase successful!');
          } else {
            onPurchaseComplete?.call(false, 'Purchase verification failed');
          }
          break;
          
        case PurchaseStatus.error:
          _log('Purchase error: ${purchase.error}');
          onPurchaseError?.call(purchase.error?.message ?? 'Unknown error');
          break;
          
        case PurchaseStatus.canceled:
          _log('Purchase canceled');
          onPurchaseComplete?.call(false, 'Purchase canceled');
          break;
      }

      // Complete pending purchases
      if (purchase.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchase);
      }
    }
  }

  /// Verify purchase (basic verification - for production, use server-side verification)
  Future<bool> _verifyPurchase(PurchaseDetails purchase) async {
    // For production, you should verify the purchase on your server
    // using the purchase token and Google Play Developer API
    
    // Basic client-side check
    if (purchase.verificationData.localVerificationData.isEmpty) {
      return false;
    }
    
    return true;
  }

  /// Deliver the product to the user
  Future<void> _deliverProduct(PurchaseDetails purchase) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Update Firebase
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'isPremium': true,
            'premiumProductId': purchase.productID,
            'premiumPurchaseDate': FieldValue.serverTimestamp(),
            'premiumPurchaseToken': purchase.verificationData.serverVerificationData,
          });
      
      isPremium = true;
      _log('Product delivered: ${purchase.productID}');
    } catch (e) {
      _log('Error delivering product: $e');
    }
  }

  /// Purchase a product
  Future<bool> purchaseProduct(ProductDetails product) async {
    if (!isAvailable) {
      onPurchaseError?.call('Store not available');
      return false;
    }

    try {
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: product,
      );

      // For subscriptions
      if (product.id.contains('monthly') || product.id.contains('yearly')) {
        return await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        return await _inAppPurchase.buyConsumable(purchaseParam: purchaseParam);
      }
    } catch (e) {
      _log('Error purchasing: $e');
      onPurchaseError?.call(e.toString());
      return false;
    }
  }

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    if (!isAvailable) {
      onPurchaseError?.call('Store not available');
      return;
    }

    try {
      await _inAppPurchase.restorePurchases();
    } catch (e) {
      _log('Error restoring purchases: $e');
      onPurchaseError?.call(e.toString());
    }
  }

  /// Check if user has premium status
  Future<bool> checkPremiumStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      isPremium = false;
      return false;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      isPremium = doc.data()?['isPremium'] ?? false;
      return isPremium;
    } catch (e) {
      _log('Error checking premium status: $e');
      return false;
    }
  }

  /// Get product by ID
  ProductDetails? getProduct(String productId) {
    try {
      return products.firstWhere((p) => p.id == productId);
    } catch (e) {
      return null;
    }
  }

  /// Get monthly subscription product
  ProductDetails? get monthlyProduct => getProduct(premiumMonthlyId);
  
  /// Get yearly subscription product
  ProductDetails? get yearlyProduct => getProduct(premiumYearlyId);

  /// Dispose
  void dispose() {
    _subscription?.cancel();
  }
}
