import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalendarModal extends StatefulWidget {
  final DateTime initialSelectedDay;
  final DateTime initialDisplayedMonth;
  final Map<String, List<dynamic>> markedDates;
  final Color highlightColor;
  final Color connectorColor;

  const CalendarModal({
    super.key,
    required this.initialSelectedDay,
    required this.initialDisplayedMonth,
    required this.markedDates,
    this.highlightColor = Colors.deepOrange,
    this.connectorColor = const Color(0xFFFFE082),
  });

  @override
  State<CalendarModal> createState() => _CalendarModalState();
}

class _CalendarModalState extends State<CalendarModal> {
  late DateTime _selectedDay;
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.initialSelectedDay;
    _displayedMonth = widget.initialDisplayedMonth;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.grey.shade900 : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white60 : Colors.black54;
    
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header with title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.highlightColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.calendar_month, color: widget.highlightColor, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                'Select Date',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Month navigation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left, color: widget.highlightColor),
                  onPressed: () {
                    setState(() {
                      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month - 1, 1);
                    });
                  },
                ),
                Text(
                  DateFormat.yMMMM().format(_displayedMonth),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right, color: widget.highlightColor),
                  onPressed: () {
                    setState(() {
                      _displayedMonth = DateTime(_displayedMonth.year, _displayedMonth.month + 1, 1);
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Weekday headers
          Row(
            children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                .map((d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: subtextColor,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ))
                .toList(),
          ),
          const SizedBox(height: 12),
          
          // Calendar grid
          SizedBox(
            height: 260,
            child: _buildCalendarGrid(isDark, textColor),
          ),
          const SizedBox(height: 16),
          
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: subtextColor,
                    side: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(null),
                  icon: Icon(Icons.view_list, size: 18, color: widget.highlightColor),
                  label: Text('See All', style: TextStyle(color: widget.highlightColor)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: widget.highlightColor.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(_selectedDay),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.highlightColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Select', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildCalendarGrid(bool isDark, Color textColor) {
    final firstDay = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final days = DateUtils.getDaysInMonth(_displayedMonth.year, _displayedMonth.month);
    final firstWeekday = firstDay.weekday;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: days + (firstWeekday - 1),
      itemBuilder: (context, idx) {
        final dnum = idx - (firstWeekday - 2);
        if (dnum <= 0) return const SizedBox.shrink();

        final dayDt = DateTime(_displayedMonth.year, _displayedMonth.month, dnum);
        final key = DateFormat('yyyy-MM-dd').format(dayDt);
        final isSel = DateFormat('yyyy-MM-dd').format(dayDt) ==
            DateFormat('yyyy-MM-dd').format(_selectedDay);
        final hasMarker = widget.markedDates.containsKey(key);
        final isToday = DateFormat('yyyy-MM-dd').format(dayDt) ==
            DateFormat('yyyy-MM-dd').format(DateTime.now());

        return GestureDetector(
          onTap: () => setState(() => _selectedDay = dayDt),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: isSel
                  ? widget.highlightColor
                  : hasMarker
                      ? widget.highlightColor.withOpacity(0.15)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isToday && !isSel
                  ? Border.all(color: widget.highlightColor, width: 2)
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Show emotion emoji if available
                if (hasMarker && widget.markedDates[key] != null && widget.markedDates[key]!.isNotEmpty)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Text(
                      widget.markedDates[key]!.first['emotion'] ?? '',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                Text(
                  '$dnum',
                  style: TextStyle(
                    color: isSel
                        ? Colors.white
                        : hasMarker
                            ? widget.highlightColor
                            : isDark
                                ? Colors.white70
                                : Colors.black54,
                    fontWeight: isSel || hasMarker || isToday
                        ? FontWeight.bold
                        : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
                if (hasMarker && !isSel)
                  Positioned(
                    bottom: 6,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: widget.highlightColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Future<DateTime?> showCalendarModal({
  required BuildContext context,
  required DateTime initialSelectedDay,
  required DateTime initialDisplayedMonth,
  required Map<String, List<dynamic>> markedDates,
  Color highlightColor = Colors.deepOrange,
  Color connectorColor = const Color(0xFFFFE082),
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => CalendarModal(
      initialSelectedDay: initialSelectedDay,
      initialDisplayedMonth: initialDisplayedMonth,
      markedDates: markedDates,
      highlightColor: highlightColor,
      connectorColor: connectorColor,
    ),
  );
}