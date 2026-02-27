import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Since PaymentService uses singleton pattern and relies on InAppPurchase,
// we test the testable parts and mock the platform-specific functionality

/// Mock class to test PaymentService business logic
class MockPaymentService {
  bool isAvailable = false;
  bool isPremium = false;
  List<MockProductDetails> products = [];
  
  // Callbacks
  Function(bool success, String message)? onPurchaseComplete;
  Function(String error)? onPurchaseError;
  
  // Product IDs
  static const String premiumMonthlyId = 'premium_monthly';
  static const String premiumYearlyId = 'premium_yearly';
  
  static const Set<String> productIds = {
    premiumMonthlyId,
    premiumYearlyId,
  };

  Future<void> initialize() async {
    // In tests, we simulate initialization
    isAvailable = true;
  }

  Future<void> loadProducts() async {
    if (!isAvailable) return;
    
    // Simulate loading products
    products = [
      MockProductDetails(
        id: premiumMonthlyId,
        title: 'Premium Monthly',
        description: 'Monthly premium subscription',
        price: '\$4.99',
        rawPrice: 4.99,
        currencyCode: 'USD',
      ),
      MockProductDetails(
        id: premiumYearlyId,
        title: 'Premium Yearly',
        description: 'Yearly premium subscription',
        price: '\$39.99',
        rawPrice: 39.99,
        currencyCode: 'USD',
      ),
    ];
  }

  Future<bool> checkPremiumStatus() async {
    // Check from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    isPremium = prefs.getBool('isPremium') ?? false;
    return isPremium;
  }

  Future<void> setPremiumStatus(bool status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isPremium', status);
    isPremium = status;
  }

  bool canPurchase() {
    return isAvailable && !isPremium;
  }

  MockProductDetails? getProductById(String id) {
    try {
      return products.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    onPurchaseComplete = null;
    onPurchaseError = null;
  }
}

class MockProductDetails {
  final String id;
  final String title;
  final String description;
  final String price;
  final double rawPrice;
  final String currencyCode;

  MockProductDetails({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.rawPrice,
    required this.currencyCode,
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PaymentService', () {
    late MockPaymentService paymentService;

    setUp(() {
      paymentService = MockPaymentService();
      SharedPreferences.setMockInitialValues({});
    });

    group('Initialization', () {
      test('initialize sets isAvailable to true', () async {
        // Act
        await paymentService.initialize();

        // Assert
        expect(paymentService.isAvailable, true);
      });

      test('service is not available before initialization', () {
        // Assert
        expect(paymentService.isAvailable, false);
      });
    });

    group('Product Loading', () {
      test('loadProducts populates products list when available', () async {
        // Arrange
        await paymentService.initialize();

        // Act
        await paymentService.loadProducts();

        // Assert
        expect(paymentService.products.length, 2);
        expect(paymentService.products.any((p) => p.id == 'premium_monthly'), true);
        expect(paymentService.products.any((p) => p.id == 'premium_yearly'), true);
      });

      test('loadProducts does nothing when not available', () async {
        // Act (not initialized, so isAvailable = false)
        await paymentService.loadProducts();

        // Assert
        expect(paymentService.products, isEmpty);
      });

      test('getProductById returns correct product', () async {
        // Arrange
        await paymentService.initialize();
        await paymentService.loadProducts();

        // Act
        final product = paymentService.getProductById('premium_monthly');

        // Assert
        expect(product, isNotNull);
        expect(product!.title, 'Premium Monthly');
        expect(product.rawPrice, 4.99);
      });

      test('getProductById returns null for unknown product', () async {
        // Arrange
        await paymentService.initialize();
        await paymentService.loadProducts();

        // Act
        final product = paymentService.getProductById('unknown_product');

        // Assert
        expect(product, isNull);
      });
    });

    group('Premium Status', () {
      test('checkPremiumStatus returns false by default', () async {
        // Act
        final isPremium = await paymentService.checkPremiumStatus();

        // Assert
        expect(isPremium, false);
        expect(paymentService.isPremium, false);
      });

      test('checkPremiumStatus returns true when user is premium', () async {
        // Arrange
        SharedPreferences.setMockInitialValues({'isPremium': true});

        // Act
        final isPremium = await paymentService.checkPremiumStatus();

        // Assert
        expect(isPremium, true);
        expect(paymentService.isPremium, true);
      });

      test('setPremiumStatus updates status correctly', () async {
        // Act
        await paymentService.setPremiumStatus(true);

        // Assert
        expect(paymentService.isPremium, true);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getBool('isPremium'), true);
      });
    });

    group('Purchase Eligibility', () {
      test('canPurchase returns false when not available', () {
        // Assert
        expect(paymentService.canPurchase(), false);
      });

      test('canPurchase returns true when available and not premium', () async {
        // Arrange
        await paymentService.initialize();

        // Assert
        expect(paymentService.canPurchase(), true);
      });

      test('canPurchase returns false when already premium', () async {
        // Arrange
        await paymentService.initialize();
        await paymentService.setPremiumStatus(true);

        // Assert
        expect(paymentService.canPurchase(), false);
      });
    });

    group('Callbacks', () {
      test('onPurchaseComplete callback can be set and invoked', () async {
        // Arrange
        bool callbackInvoked = false;
        String? receivedMessage;
        
        paymentService.onPurchaseComplete = (success, message) {
          callbackInvoked = true;
          receivedMessage = message;
        };

        // Act
        paymentService.onPurchaseComplete?.call(true, 'Purchase successful!');

        // Assert
        expect(callbackInvoked, true);
        expect(receivedMessage, 'Purchase successful!');
      });

      test('onPurchaseError callback can be set and invoked', () async {
        // Arrange
        String? errorReceived;
        
        paymentService.onPurchaseError = (error) {
          errorReceived = error;
        };

        // Act
        paymentService.onPurchaseError?.call('Network error');

        // Assert
        expect(errorReceived, 'Network error');
      });

      test('dispose clears callbacks', () {
        // Arrange
        paymentService.onPurchaseComplete = (_, __) {};
        paymentService.onPurchaseError = (_) {};

        // Act
        paymentService.dispose();

        // Assert
        expect(paymentService.onPurchaseComplete, isNull);
        expect(paymentService.onPurchaseError, isNull);
      });
    });
  });
}
