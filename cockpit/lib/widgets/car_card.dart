import 'package:cockpit/models/f1car.dart';
import 'package:cockpit/utils/app_colors.dart';
import 'package:flutter/material.dart';

class CarCard extends StatefulWidget {
  final F1Car car;
  final Function(F1Car car) onConnect;
  final bool isSelected;
  final bool isConnecting;

  const CarCard({
    super.key,
    required this.car,
    required this.onConnect,
    required this.isSelected,
    required this.isConnecting,
  });

  @override
  State<CarCard> createState() => _CarCardState();
}

class _CarCardState extends State<CarCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late ScrollController _scrollController;
  bool _shouldScroll = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkIfScrollNeeded();
    });
  }

  void _checkIfScrollNeeded() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll > 0) {
        setState(() {
          _shouldScroll = true;
        });
        _startAutoScroll();
      }
    }
  }

  void _startAutoScroll() {
    if (!_shouldScroll) return;

    _animationController.addListener(() {
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final progress = _animationController.value;
        double scrollPosition;

        if (progress <= 0.5) {
          scrollPosition = (progress * 2) * maxScroll;
        } else {
          scrollPosition = (2 - progress * 2) * maxScroll;
        }

        _scrollController.jumpTo(scrollPosition);
      }
    });

    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final List<String> driverNameParts = widget.car.driverName.split(' ');
    final String firstName = driverNameParts.first;
    final String lastName = driverNameParts.sublist(1).join(' ');

    return GestureDetector(
      onTap: () {},
      child: Container(
        height: 200,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: widget.isSelected
                ? AppColors.cardBorderSelected
                : AppColors.cardBorder,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          firstName,
                          style: textTheme.headlineMedium?.copyWith(
                            fontSize: 40,
                            fontStyle: FontStyle.italic,
                            height: 1.0,
                            color: AppColors.white,
                          ),
                        ),
                        SingleChildScrollView(
                          controller: _scrollController,
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            lastName.toUpperCase(),
                            style: textTheme.displayLarge?.copyWith(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Text(
                    '${widget.car.number}',
                    style: textTheme.headlineSmall,
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                  ),
                ),
              ],
            ),
            _buildConnectButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectButton(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final bool isDisabled = widget.isConnecting;
    final String buttonText;

    if (widget.isSelected && widget.isConnecting) {
      buttonText = 'Connecting...';
    } else if (widget.isSelected) {
      buttonText = 'Connected';
    } else {
      buttonText = 'Connect';
    }

    return GestureDetector(
      onTap: isDisabled ? null : () => widget.onConnect(widget.car),
      child: Container(
        margin: const EdgeInsets.only(top: 24),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDisabled
              ? AppColors.disabledButtonBackground
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isDisabled
                ? AppColors.disabledButtonBorder
                : AppColors.buttonBorder,
          ),
        ),
        child: Text(
          buttonText,
          textAlign: TextAlign.center,
          style: textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
            color: isDisabled ? AppColors.disabledButtonText : AppColors.white,
          ),
        ),
      ),
    );
  }
}
