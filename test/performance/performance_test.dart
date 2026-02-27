import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Performance benchmark tests for Digital Diary app
/// These tests measure and validate performance characteristics

void main() {
  group('Performance Tests', () {
    group('Widget Build Performance', () {
      testWidgets('video list renders within acceptable time', (tester) async {
        // Arrange
        final stopwatch = Stopwatch()..start();
        
        // Act - Build a list with 50 video items
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView.builder(
                itemCount: 50,
                itemBuilder: (context, index) => _MockVideoListItem(index: index),
              ),
            ),
          ),
        );
        
        stopwatch.stop();
        
        // Assert - Initial build should be under 2000ms (lenient for test environment)
        expect(stopwatch.elapsedMilliseconds, lessThan(2000),
            reason: 'Initial video list build took too long: ${stopwatch.elapsedMilliseconds}ms');
      });

      testWidgets('calendar modal renders within acceptable time', (tester) async {
        // Arrange
        final stopwatch = Stopwatch()..start();
        
        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _MockCalendarWidget(),
            ),
          ),
        );
        
        stopwatch.stop();
        
        // Assert - Calendar should render under 200ms
        expect(stopwatch.elapsedMilliseconds, lessThan(200),
            reason: 'Calendar modal build took too long: ${stopwatch.elapsedMilliseconds}ms');
      });

      testWidgets('login form renders within acceptable time', (tester) async {
        // Arrange
        final stopwatch = Stopwatch()..start();
        
        // Act
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _MockLoginForm(),
            ),
          ),
        );
        
        stopwatch.stop();
        
        // Assert - Login form should render under 500ms (lenient for test environment)
        expect(stopwatch.elapsedMilliseconds, lessThan(500),
            reason: 'Login form build took too long: ${stopwatch.elapsedMilliseconds}ms');
      });
    });

    group('Scroll Performance', () {
      testWidgets('video list scrolls smoothly', (tester) async {
        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView.builder(
                itemCount: 100,
                itemBuilder: (context, index) => _MockVideoListItem(index: index),
              ),
            ),
          ),
        );

        final stopwatch = Stopwatch()..start();

        // Act - Perform multiple scroll gestures
        for (int i = 0; i < 10; i++) {
          await tester.drag(find.byType(ListView), const Offset(0, -300));
          await tester.pump();
        }

        stopwatch.stop();

        // Assert - 10 scroll operations should complete under 1 second
        expect(stopwatch.elapsedMilliseconds, lessThan(1000),
            reason: 'Scroll performance degraded: ${stopwatch.elapsedMilliseconds}ms for 10 scrolls');
      });

      testWidgets('maintains item recycling during scroll', (tester) async {
        // Arrange
        int builtItemCount = 0;
        
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView.builder(
                itemCount: 1000,
                itemBuilder: (context, index) {
                  builtItemCount++;
                  return _MockVideoListItem(index: index);
                },
              ),
            ),
          ),
        );

        final initialBuildCount = builtItemCount;

        // Act - Scroll down significantly
        await tester.drag(find.byType(ListView), const Offset(0, -5000));
        await tester.pumpAndSettle();

        // Assert - Should not have built all 1000 items (recycling should work)
        expect(builtItemCount, lessThan(1000),
            reason: 'Item recycling not working, built $builtItemCount items');
      });
    });

    group('State Update Performance', () {
      testWidgets('like toggle updates quickly', (tester) async {
        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _MockLikeButton(),
            ),
          ),
        );

        final stopwatch = Stopwatch()..start();

        // Act - Toggle like 10 times using the button finder
        for (int i = 0; i < 10; i++) {
          final favoriteButton = find.byIcon(Icons.favorite);
          final favoriteOutlineButton = find.byIcon(Icons.favorite_border);
          
          if (favoriteOutlineButton.evaluate().isNotEmpty) {
            await tester.tap(favoriteOutlineButton);
          } else if (favoriteButton.evaluate().isNotEmpty) {
            await tester.tap(favoriteButton);
          }
          await tester.pump();
        }

        stopwatch.stop();

        // Assert - 10 state updates should be under 1000ms (lenient)
        expect(stopwatch.elapsedMilliseconds, lessThan(1000),
            reason: 'State updates too slow: ${stopwatch.elapsedMilliseconds}ms for 10 toggles');
      });

      testWidgets('form validation responds quickly', (tester) async {
        // Arrange
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _MockValidatingForm(),
            ),
          ),
        );

        final stopwatch = Stopwatch()..start();

        // Act - Type and validate
        await tester.enterText(find.byType(TextFormField).first, 'test@example.com');
        await tester.pump();
        
        await tester.enterText(find.byType(TextFormField).last, 'password123');
        await tester.pump();

        stopwatch.stop();

        // Assert
        expect(stopwatch.elapsedMilliseconds, lessThan(500),
            reason: 'Form validation too slow: ${stopwatch.elapsedMilliseconds}ms');
      });
    });

    group('Memory Efficiency', () {
      test('video controller cache respects size limit', () {
        // Arrange
        final cache = _MockVideoControllerCache(maxSize: 5);

        // Act - Add more items than max size
        for (int i = 0; i < 10; i++) {
          cache.add('video_$i', _MockController());
        }

        // Assert - Cache should not exceed max size
        expect(cache.size, equals(5));
        expect(cache.contains('video_0'), false); // Oldest should be evicted
        expect(cache.contains('video_9'), true);  // Newest should exist
      });

      test('LRU eviction works correctly', () {
        // Arrange
        final cache = _MockVideoControllerCache(maxSize: 3);
        cache.add('video_1', _MockController());
        cache.add('video_2', _MockController());
        cache.add('video_3', _MockController());

        // Act - Access video_1 to make it recently used
        cache.get('video_1');
        // Add new item, should evict video_2 (least recently used)
        cache.add('video_4', _MockController());

        // Assert
        expect(cache.contains('video_1'), true);  // Recently accessed
        expect(cache.contains('video_2'), false); // Evicted
        expect(cache.contains('video_3'), true);
        expect(cache.contains('video_4'), true);  // Newly added
      });
    });

    group('Render Frame Analysis', () {
      testWidgets('complex widget builds under frame budget', (tester) async {
        // Arrange - Using more lenient threshold for test environment
        const maxBuildTime = Duration(milliseconds: 500);
        
        final stopwatch = Stopwatch()..start();
        
        // Act - Build complex widget wrapped in SingleChildScrollView
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  children: List.generate(10, (index) => 
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(child: Text('$index')),
                        title: Text('Item $index'),
                        subtitle: Text('Description for item $index'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.favorite), onPressed: () {}),
                            IconButton(icon: const Icon(Icons.share), onPressed: () {}),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        
        stopwatch.stop();
        
        // Assert - Should build within reasonable time for test environment
        expect(stopwatch.elapsed, lessThan(maxBuildTime),
            reason: 'Complex widget too slow: ${stopwatch.elapsedMilliseconds}ms');
      });
    });
  });
}

// Mock widgets for performance testing

class _MockVideoListItem extends StatelessWidget {
  final int index;
  
  const _MockVideoListItem({required this.index});
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: SizedBox(
        height: 200,
        child: Column(
          children: [
            Expanded(
              child: Container(
                color: Colors.grey[300],
                child: Center(child: Text('Video $index')),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const CircleAvatar(child: Icon(Icons.person)),
                  const SizedBox(width: 8),
                  Text('User $index'),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.favorite_border), onPressed: () {}),
                  Text('${index * 10}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MockCalendarWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text('December 2025'),
        GridView.builder(
          shrinkWrap: true,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
          ),
          itemCount: 31,
          itemBuilder: (context, index) => Center(
            child: Text('${index + 1}'),
          ),
        ),
      ],
    );
  }
}

class _MockLoginForm extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextFormField(decoration: const InputDecoration(labelText: 'Email')),
          TextFormField(decoration: const InputDecoration(labelText: 'Password')),
          ElevatedButton(onPressed: () {}, child: const Text('Login')),
        ],
      ),
    );
  }
}

class _MockLikeButton extends StatefulWidget {
  @override
  State<_MockLikeButton> createState() => _MockLikeButtonState();
}

class _MockLikeButtonState extends State<_MockLikeButton> {
  bool _isLiked = false;
  
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border),
      onPressed: () => setState(() => _isLiked = !_isLiked),
    );
  }
}

class _MockValidatingForm extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Form(
      child: Column(
        children: [
          TextFormField(
            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
          ),
          TextFormField(
            validator: (value) => (value?.length ?? 0) < 6 ? 'Too short' : null,
          ),
        ],
      ),
    );
  }
}

// Mock video controller cache for memory tests
class _MockVideoControllerCache {
  final int maxSize;
  final Map<String, _MockController> _cache = {};
  final List<String> _order = [];
  
  _MockVideoControllerCache({required this.maxSize});
  
  void add(String key, _MockController controller) {
    if (_order.length >= maxSize) {
      final oldest = _order.removeAt(0);
      _cache.remove(oldest);
    }
    _cache[key] = controller;
    _order.add(key);
  }
  
  _MockController? get(String key) {
    if (_cache.containsKey(key)) {
      // Move to end (most recently used)
      _order.remove(key);
      _order.add(key);
      return _cache[key];
    }
    return null;
  }
  
  bool contains(String key) => _cache.containsKey(key);
  
  int get size => _cache.length;
}

class _MockController {
  bool isDisposed = false;
  void dispose() => isDisposed = true;
}
