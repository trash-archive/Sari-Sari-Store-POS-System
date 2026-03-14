import 'package:flutter/material.dart';
import 'skeleton_loader.dart';

class PosSkeletonScreen extends StatelessWidget {
  const PosSkeletonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: SkeletonLoader(
          isLoading: true,
          width: 120,
          height: 20,
          child: const SizedBox(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SkeletonLoader(
              isLoading: true,
              width: 40,
              height: 40,
              borderRadius: BorderRadius.circular(20),
              child: const SizedBox(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: SkeletonLoader(
              isLoading: true,
              width: 40,
              height: 40,
              borderRadius: BorderRadius.circular(20),
              child: const SizedBox(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: SkeletonLoader(
                    isLoading: true,
                    height: 48,
                    borderRadius: BorderRadius.circular(24),
                    child: const SizedBox(),
                  ),
                ),
                const SizedBox(width: 12),
                SkeletonLoader(
                  isLoading: true,
                  width: 48,
                  height: 48,
                  borderRadius: BorderRadius.circular(24),
                  child: const SizedBox(),
                ),
              ],
            ),
          ),
          Expanded(child: SkeletonGrid()),
        ],
      ),
    );
  }
}

class ProductsSkeletonScreen extends StatelessWidget {
  const ProductsSkeletonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: SkeletonLoader(
          isLoading: true,
          width: 100,
          height: 20,
          child: const SizedBox(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: SkeletonLoader(
              isLoading: true,
              width: 40,
              height: 40,
              borderRadius: BorderRadius.circular(20),
              child: const SizedBox(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: SkeletonLoader(
                    isLoading: true,
                    height: 48,
                    borderRadius: BorderRadius.circular(24),
                    child: const SizedBox(),
                  ),
                ),
                const SizedBox(width: 12),
                SkeletonLoader(
                  isLoading: true,
                  width: 48,
                  height: 48,
                  borderRadius: BorderRadius.circular(24),
                  child: const SizedBox(),
                ),
              ],
            ),
          ),
          Expanded(child: SkeletonGrid()),
        ],
      ),
      floatingActionButton: SkeletonLoader(
        isLoading: true,
        width: 56,
        height: 56,
        borderRadius: BorderRadius.circular(28),
        child: const SizedBox(),
      ),
    );
  }
}

class InvoicesSkeletonScreen extends StatelessWidget {
  const InvoicesSkeletonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: SkeletonLoader(
          isLoading: true,
          width: 80,
          height: 20,
          child: const SizedBox(),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: SkeletonLoader(
              isLoading: true,
              height: 48,
              borderRadius: BorderRadius.circular(24),
              child: const SizedBox(),
            ),
          ),
          Expanded(child: SkeletonList()),
        ],
      ),
    );
  }
}

class UtangSkeletonScreen extends StatelessWidget {
  const UtangSkeletonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: SkeletonLoader(
          isLoading: true,
          width: 60,
          height: 20,
          child: const SizedBox(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: SkeletonLoader(
              isLoading: true,
              width: 40,
              height: 40,
              borderRadius: BorderRadius.circular(20),
              child: const SizedBox(),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: SkeletonLoader(
              isLoading: true,
              height: 48,
              borderRadius: BorderRadius.circular(24),
              child: const SizedBox(),
            ),
          ),
          Expanded(child: SkeletonList()),
        ],
      ),
      floatingActionButton: SkeletonLoader(
        isLoading: true,
        width: 56,
        height: 56,
        borderRadius: BorderRadius.circular(28),
        child: const SizedBox(),
      ),
    );
  }
}

class ReportsSkeletonScreen extends StatelessWidget {
  const ReportsSkeletonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: SkeletonLoader(
          isLoading: true,
          width: 80,
          height: 20,
          child: const SizedBox(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: SkeletonLoader(
              isLoading: true,
              width: 40,
              height: 40,
              borderRadius: BorderRadius.circular(20),
              child: const SizedBox(),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              height: 48,
              margin: const EdgeInsets.only(bottom: 20),
              child: Row(
                children: List.generate(4, (index) => Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: index < 3 ? 8 : 0),
                    child: SkeletonLoader(
                      isLoading: true,
                      height: 48,
                      borderRadius: BorderRadius.circular(24),
                      child: const SizedBox(),
                    ),
                  ),
                )),
              ),
            ),
            ...List.generate(4, (index) => Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(
                    isLoading: true,
                    width: 120,
                    height: 16,
                    borderRadius: BorderRadius.circular(4),
                    child: const SizedBox(),
                  ),
                  const SizedBox(height: 12),
                  SkeletonLoader(
                    isLoading: true,
                    width: 80,
                    height: 24,
                    borderRadius: BorderRadius.circular(4),
                    child: const SizedBox(),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}