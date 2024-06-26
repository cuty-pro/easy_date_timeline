import 'dart:collection';

import 'package:easy_date_timeline/easy_date_timeline.dart';
import 'package:flutter/material.dart';

import '../../utils/utils.dart';
import '../../widgets/easy_day_widget/easy_day_widget.dart';
import 'web_scroll_behavior.dart';

part 'easy_infinite_date_timeline_controller.dart';

typedef MarkerBuilder<T> = Widget Function(
    BuildContext context, DateTime day, List<T> events);

typedef Markers<T> = LinkedHashMap<DateTime, List<T>>;

class InfiniteTimeLineWidget<T> extends StatefulWidget {
  InfiniteTimeLineWidget({
    super.key,
    this.inactiveDates,
    this.dayProps = const EasyDayProps(),
    this.locale = "en_US",
    this.timeLineProps = const EasyTimeLineProps(),
    this.onDateChange,
    this.itemBuilder,
    this.physics,
    this.controller,
    required this.firstDate,
    required this.focusedDate,
    required this.activeDayTextColor,
    required this.activeDayColor,
    required this.lastDate,
    required this.selectionMode,
    this.markerBuilder,
    this.markers,
    this.weekends = const [],
    this.onDayAppearInScroll,
  })  : assert(timeLineProps.hPadding > -1,
            "Can't set timeline hPadding less than zero."),
        assert(timeLineProps.separatorPadding > -1,
            "Can't set timeline separatorPadding less than zero."),
        assert(timeLineProps.vPadding > -1,
            "Can't set timeline vPadding less than zero."),
        assert(
          !lastDate.isBefore(firstDate),
          'lastDate $lastDate must be on or after firstDate $firstDate.',
        );

  /// Represents the initial date for the timeline widget.
  /// This is the date that will be displayed as the first day in the timeline.
  final DateTime firstDate;

  /// Represents the last date for the timeline widget.
  /// This is the date that will be displayed as the last day in the timeline.
  final DateTime lastDate;

  /// The currently focused date in the timeline.
  final DateTime? focusedDate;

  /// The color of the text for the selected day.
  final Color activeDayTextColor;

  /// The background color of the selected day.
  final Color activeDayColor;

  /// Represents a list of inactive dates for the timeline widget.
  /// Note that all the dates defined in the inactiveDates list will be deactivated.
  final List<DateTime>? inactiveDates;

  /// Contains properties for configuring the appearance and behavior of the timeline widget.
  /// This object includes properties such as the height of the timeline, the color of the selected day,
  /// and the animation duration for scrolling.
  final EasyTimeLineProps timeLineProps;

  /// Contains properties for configuring the appearance and behavior of the day widgets in the timeline.
  /// This object includes properties such as the width and height of each day widget,
  /// the color of the text and background, and the font size.
  final EasyDayProps dayProps;

  /// Called when the selected date in the timeline changes.
  /// This function takes a `DateTime` object as its parameter, which represents the new selected date.
  final OnDateChangeCallBack? onDateChange;

  /// Called for each day in the timeline, allowing the developer to customize the appearance and behavior of each day widget.
  /// This function takes a `BuildContext` and a `DateTime` object as its parameters, and should return a `Widget` that represents the day.
  final ItemBuilderCallBack? itemBuilder;

  /// A `String` that represents the locale code to use for formatting the dates in the timeline.
  final String locale;

  /// Determines the selection mode of the infinite date timeline.
  ///
  /// The [selectionMode] specifies how the timeline should behave when the selected date changes.
  /// It can be set to one of the following values:
  /// - [SelectionMode.none]: The timeline does not animate the selection.
  /// - [SelectionMode.autoCenter]: The timeline automatically centers the selected date.
  /// - [SelectionMode.alwaysFirst]: The timeline always positions the selected date at the first visible day of the timeline.
  ///
  /// By default, the selection mode is set to [SelectionMode.autoCenter].
  ///
  /// This property is used to customize the behavior of the timeline when the selected date changes.
  /// For example, if you set it to `SelectionMode.alwaysFirst()`, the timeline will always position the selected date at the first visible day of the timeline.
  final SelectionMode selectionMode;

  /// The controller to manage the EasyInfiniteDateTimeline. Allows programmatic control over the timeline,
  /// such as scrolling to a specific date or scrolling to the focus date.
  final EasyInfiniteDateTimelineController? controller;

  final ScrollPhysics? physics;

  final Markers<T>? markers;

  final MarkerBuilder<T>? markerBuilder;

  final List<DateTime> weekends;

  final Function(DateTime day)? onDayAppearInScroll;

  @override
  State<InfiniteTimeLineWidget<T>> createState() =>
      _InfiniteTimeLineWidgetState<T>();
}

class _InfiniteTimeLineWidgetState<T> extends State<InfiniteTimeLineWidget<T>> {
  /// Returns the [EasyDayProps] associated with the widget.
  EasyDayProps get _dayProps => widget.dayProps;

  /// Returns the [EasyTimeLineProps] associated with this [InfiniteTimeLineWidget].
  EasyTimeLineProps get _timeLineProps => widget.timeLineProps;

  /// Returns a boolean value indicating whether the widget is in landscape mode.
  bool get _isLandscapeMode => _dayProps.landScapeMode;

  /// Returns the width of a single day in the timeline.
  double get _dayWidth => _dayProps.width;

  /// Returns the height of a single day in the timeline.
  double get _dayHeight => _dayProps.height;

  /// The number of days in the timeline.
  late int _daysCount;

  /// Scroll controller for the infinite timeline widget.
  late ScrollController _controller;

  /// Returns the focus date of the timeline widget.
  /// If the `focusedDate` property is not set, it returns the `firstDate` property.
  DateTime get _focusDate => widget.focusedDate ?? widget.firstDate;

  /// The extent of each item in the infinite timeline widget.
  double _itemExtend = 0.0;

  @override
  void initState() {
    super.initState();
    _initItemExtend();
    _attachEasyController();
    _daysCount =
        EasyDateUtils.calculateDaysCount(widget.firstDate, widget.lastDate);
    _controller = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToInitialOffset());
    _controller.addListener(() {
      final day = calculateDateFromOffset(
        firstDate: widget.firstDate,
        dayWidth: _itemExtend,
        controller: _controller,
      );
      widget.onDayAppearInScroll?.call(day);
    });
  }

  void _jumpToInitialOffset() {
    final initialScrollOffset = _getScrollOffset();
    if (_controller.hasClients) {
      _controller.jumpTo(initialScrollOffset);
    }
  }

  @override
  void didUpdateWidget(covariant InfiniteTimeLineWidget<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _attachEasyController();
    } else if (widget.timeLineProps != oldWidget.timeLineProps ||
        widget.dayProps != oldWidget.dayProps) {
      _initItemExtend();
    } else if (widget.selectionMode != oldWidget.selectionMode) {
      _jumpToInitialOffset();
    }
  }

  /// Attaches the [EasyInfiniteDateTimelineController] to the [InfiniteTimeLineWidget].
  ///
  /// This method is responsible for attaching the [EasyInfiniteDateTimelineController] provided by the widget to the [InfiniteTimeLineWidget].
  /// It calls the `_attachEasyDateState` method on the [EasyInfiniteDateTimelineController] to establish the connection.
  ///
  /// If the [EasyInfiniteDateTimelineController] is not provided, this method does nothing.
  void _attachEasyController() => widget.controller?._attachEasyDateState(this);

  /// Detaches the [EasyInfiniteDateTimelineController] from the [InfiniteTimeLineWidget].
  ///
  /// This method is responsible for detaching the [EasyInfiniteDateTimelineController] provided by the widget from the [InfiniteTimeLineWidget].
  /// It calls the `_detachEasyDateState` method on the [EasyInfiniteDateTimelineController] to remove the connection.
  ///
  /// If the [EasyInfiniteDateTimelineController] is not provided, this method does nothing.
  void _detachEasyController() => widget.controller?._detachEasyDateState();

  @override
  void dispose() {
    _controller.dispose();
    _detachEasyController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _isLandscapeMode ? _dayWidth : _dayHeight,
      margin: _timeLineProps.margin,
      color: _timeLineProps.decoration == null
          ? _timeLineProps.backgroundColor
          : null,
      decoration: _timeLineProps.decoration,
      child: ClipRRect(
        borderRadius:
            _timeLineProps.decoration?.borderRadius ?? BorderRadius.zero,
        child: CustomScrollView(
          scrollDirection: Axis.horizontal,
          scrollBehavior: EasyCustomScrollBehavior(),
          controller: _controller,
          physics: widget.physics,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: _timeLineProps.hPadding,
                vertical: _timeLineProps.vPadding,
              ),
              sliver: SliverFixedExtentList.builder(
                itemExtent: _itemExtend,
                itemBuilder: (context, index) {
                  /// Adds a duration of [index] days to the [firstDate] and assigns the result to [currentDate].
                  ///
                  /// The [firstDate] is the starting date from which the duration is added.
                  /// The [index] represents the number of days to be added to the [firstDate].
                  final currentDate =
                      widget.firstDate.add(Duration(days: index));

                  /// Checks if the [_focusDate] is the same day as [currentDate].
                  bool isSelected =
                      EasyDateUtils.isSameDay(_focusDate, currentDate);

                  /// Flag indicating whether the day is disabled or not.
                  bool isDisabledDay = false;

                  /// Checks if the current date [currentDate] is present in the list of inactive dates [widget.inactiveDates].
                  /// If it is found, sets the [isDisabledDay] flag to true, indicating that the day should be disabled.
                  /// Returns void.
                  if (widget.inactiveDates != null) {
                    for (DateTime inactiveDate in widget.inactiveDates!) {
                      if (EasyDateUtils.isSameDay(currentDate, inactiveDate)) {
                        isDisabledDay = true;
                        break;
                      }
                    }
                  }

                  final now = DateTime.now();
                  final dayNow = DateTime(now.year, now.month, now.day);
                  final dayCurrent = DateTime(
                      currentDate.year, currentDate.month, currentDate.day);

                  final isWeekendOrCompleted = dayNow.isAfter(dayCurrent) ||
                      widget.weekends
                          .where((e) =>
                              e.year == currentDate.year &&
                              e.month == currentDate.month &&
                              e.day == currentDate.day)
                          .isNotEmpty;

                  final List<T> events = (widget.markers?[currentDate] ?? []);
                  return Padding(
                    key: ValueKey<DateTime>(currentDate),
                    padding: EdgeInsetsDirectional.only(
                      end: _timeLineProps.separatorPadding,
                    ),
                    child: Column(
                      children: [
                        EasyDayWidget(
                          easyDayProps: _dayProps,
                          date: currentDate,
                          locale: widget.locale,
                          isSelected: isSelected,
                          isDisabled: isDisabledDay,
                          onDayPressed: () =>
                              _onDayChanged(isSelected, currentDate),
                          activeTextColor: widget.activeDayTextColor,
                          activeDayColor: widget.activeDayColor,
                          weekend: isWeekendOrCompleted,
                        ),
                        if (widget.markerBuilder != null &&
                            events.isNotEmpty) ...[
                          const SizedBox(height: 5),
                          widget.markerBuilder!
                              .call(context, currentDate, events)
                        ],
                      ],
                    ),
                  );
                },
                itemCount: _daysCount,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds an [InkWell] widget for a day item in the infinite timeline.
  ///
  /// The [context] is the build context.
  /// The [isSelected] indicates whether the day item is selected.
  /// The [date] is the date associated with the day item.
  ///
  /// Returns an [InkWell] widget with the specified properties.
  InkWell _dayItemBuilder(
    BuildContext context,
    bool isSelected,
    DateTime date,
  ) {
    return InkWell(
      onTap: () => _onDayChanged(isSelected, date),
      borderRadius: BorderRadius.circular(_dayProps.activeBorderRadius),
      child: widget.itemBuilder!(
        context,
        date.day.toString(),
        EasyDateFormatter.shortDayName(date, widget.locale).toUpperCase(),
        EasyDateFormatter.shortMonthName(date, widget.locale).toUpperCase(),
        date,
        isSelected,
      ),
    );
  }

  /// Callback function that is called when a day is changed.
  ///
  /// The [isSelected] parameter indicates whether the day is selected or not.
  /// The [currentDate] parameter represents the current selected date.
  void _onDayChanged(bool isSelected, DateTime currentDate) {
    // A date is selected
    widget.onDateChange?.call(currentDate);
    final selectionMode = widget.selectionMode;
    if (selectionMode.isAutoCenter || selectionMode.isAlwaysFirst) {
      final offset = _getScrollOffset(currentDate);
      _controller.animateTo(
        offset,
        duration: selectionMode.duration ??
            EasyConstants.selectionModeAnimationDuration,
        curve: selectionMode.curve ?? Curves.linear,
      );
    }
  }

  /// Calculates the scroll offset for the specified [lastDate].
  ///
  /// If [lastDate] is not provided, it falls back to [widget.focusedDate].
  ///
  /// Returns the calculated scroll offset.
  double _getScrollOffset([DateTime? lastDate]) {
    // Get the last date to use, defaulting to widget.focusedDate if not provided
    final effectiveLastDate = lastDate ?? widget.focusedDate;
    // Check if a date is provided
    if (effectiveLastDate != null) {
      // Use a switch expression to determine the scroll offset based on the selection mode
      return switch (widget.selectionMode) {
        // If the selection mode is none or always first
        SelectionModeNone() ||
        SelectionModeAlwaysFirst() =>
          // Calculate the scroll offset between the first date and the last date
          calculateDateOffsetBetweenDates(
            firstDate: widget.firstDate, // Use the widget's first date
            lastDate: effectiveLastDate, // Use the effective last date
            dayWidth: _itemExtend, // Use the item extend calculated earlier
            controller: _controller, // Use the scroll controller
          ),
        // If the selection mode is auto center
        SelectionModeAutoCenter() =>
          // Calculate the scroll offset for center mode
          calculateDateOffsetForCenter(
            firstDate: widget.firstDate, // Use the widget's first date
            lastDate: effectiveLastDate, // Use the effective last date
            dayWidth: _itemExtend, // Use the item extend calculated earlier
            controller: _controller, // Use the scroll controller
          ),
      };
    } else {
      // If no date is provided, return 0.0 as the scroll offset
      return 0.0;
    }
  }

  /// Initializes the item extend value based on the current orientation and timeline properties.
  /// The item extend value is calculated by adding the day height or day width (depending on the landscape mode)
  /// with the separator padding from the timeline properties.
  void _initItemExtend() {
    _itemExtend = (_isLandscapeMode ? _dayHeight : _dayWidth) +
        _timeLineProps.separatorPadding;
  }
}
