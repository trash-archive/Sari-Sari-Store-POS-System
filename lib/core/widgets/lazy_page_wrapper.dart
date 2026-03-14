import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'skeleton_loader.dart';

class LazyPageWrapper extends ConsumerStatefulWidget {
  final Widget Function() builder;
  final Widget? skeleton;
  final Duration loadDelay;
  final bool preload;

  const LazyPageWrapper({
    super.key,
    required this.builder,
    this.skeleton,
    this.loadDelay = const Duration(milliseconds: 50),
    this.preload = false,
  });

  @override
  ConsumerState<LazyPageWrapper> createState() => _LazyPageWrapperState();
}

class _LazyPageWrapperState extends ConsumerState<LazyPageWrapper>
    with AutomaticKeepAliveClientMixin {
  bool _isLoaded = false;
  Widget? _cachedWidget;
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => _isLoaded;

  @override
  void initState() {
    super.initState();
    if (widget.preload) {
      _loadPage();
    }
  }

  void _loadPage() {
    if (_isLoaded || _isLoading) return;
    
    _isLoading = true;
    
    Future.delayed(widget.loadDelay, () {
      if (mounted && !_isLoaded) {
        try {
          final widget = this.widget.builder();
          if (mounted) {
            setState(() {
              _cachedWidget = widget;
              _isLoaded = true;
              _isLoading = false;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    if (!_isLoaded) {
      _loadPage();
      return widget.skeleton ?? const SkeletonGrid();
    }

    return _cachedWidget!;
  }
}

class SmoothPageView extends StatefulWidget {
  final List<Widget> children;
  final int initialPage;
  final ValueChanged<int>? onPageChanged;
  final PageController? controller;
  final Duration transitionDuration;
  final Curve curve;

  const SmoothPageView({
    super.key,
    required this.children,
    this.initialPage = 0,
    this.onPageChanged,
    this.controller,
    this.transitionDuration = const Duration(milliseconds: 300),
    this.curve = Curves.easeInOut,
  });

  @override
  State<SmoothPageView> createState() => _SmoothPageViewState();
}

class _SmoothPageViewState extends State<SmoothPageView> {
  late PageController _controller;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? PageController(initialPage: widget.initialPage);
    _currentPage = widget.initialPage;
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void animateToPage(int page) {
    if (page == _currentPage) return;
    
    _controller.animateToPage(
      page,
      duration: widget.transitionDuration,
      curve: widget.curve,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      onPageChanged: (index) {
        setState(() => _currentPage = index);
        widget.onPageChanged?.call(index);
      },
      itemCount: widget.children.length,
      itemBuilder: (context, index) {
        return widget.children[index];
      },
    );
  }
}