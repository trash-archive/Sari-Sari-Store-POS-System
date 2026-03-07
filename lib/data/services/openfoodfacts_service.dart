import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class OpenFoodFactsProduct {
  final String barcode;
  final String name;
  final String? imageUrl;
  final String? brand;
  final String? category;

  OpenFoodFactsProduct({
    required this.barcode,
    required this.name,
    this.imageUrl,
    this.brand,
    this.category,
  });

  factory OpenFoodFactsProduct.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>?;
    if (product == null) {
      throw Exception('No product data');
    }

    // Try multiple image fields
    String? imageUrl = product['image_front_url']?.toString() ?? 
                      product['image_url']?.toString() ?? 
                      product['image_front_small_url']?.toString();
    
    // Fix HTTP to HTTPS
    if (imageUrl != null && imageUrl.startsWith('http://')) {
      imageUrl = imageUrl.replaceFirst('http://', 'https://');
    }

    return OpenFoodFactsProduct(
      barcode: json['code']?.toString() ?? '',
      name: product['product_name']?.toString() ?? 'Unknown Product',
      imageUrl: imageUrl,
      brand: product['brands']?.toString(),
      category: product['categories']?.toString()?.split(',').first.trim(),
    );
  }
}

class OpenFoodFactsService {
  static const String _baseUrl = 'https://world.openfoodfacts.org';
  static const Duration _timeout = Duration(seconds: 10);

  /// Fetch product by barcode
  static Future<OpenFoodFactsProduct?> getProductByBarcode(String barcode) async {
    try {
      final url = Uri.parse('$_baseUrl/api/v2/product/$barcode.json');
      final response = await http.get(url).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['status'] == 1) {
          return OpenFoodFactsProduct.fromJson(data);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Search products by name with improved matching
  static Future<List<OpenFoodFactsProduct>> searchByName(String query) async {
    try {
      final searchTerms = query.toLowerCase().trim();
      
      final url = Uri.parse('$_baseUrl/cgi/search.pl').replace(queryParameters: {
        'search_terms': searchTerms,
        'search_simple': '1',
        'action': 'process',
        'json': '1',
        'page_size': '30',
        'fields': 'code,product_name,brands,categories,image_url,image_front_url,image_front_small_url',
      });

      print('🔍 Searching Open Food Facts: $searchTerms');
      final response = await http.get(url).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final products = data['products'] as List<dynamic>?;
        print('📦 Found ${products?.length ?? 0} raw products');

        if (products != null && products.isNotEmpty) {
          final results = <OpenFoodFactsProduct>[];
          
          for (var p in products) {
            try {
              final product = p as Map<String, dynamic>;
              final name = product['product_name']?.toString();
              final code = product['code']?.toString();
              
              // Try multiple image fields with HTTPS fix
              String? imageUrl = product['image_front_url']?.toString() ?? 
                                product['image_url']?.toString() ?? 
                                product['image_front_small_url']?.toString();
              
              // Fix HTTP to HTTPS
              if (imageUrl != null && imageUrl.startsWith('http://')) {
                imageUrl = imageUrl.replaceFirst('http://', 'https://');
              }
              
              if (name != null && name.isNotEmpty && imageUrl != null && imageUrl.isNotEmpty && code != null) {
                print('✅ Valid product: $name - $imageUrl');
                results.add(OpenFoodFactsProduct(
                  barcode: code,
                  name: name,
                  imageUrl: imageUrl,
                  brand: product['brands']?.toString(),
                  category: product['categories']?.toString()?.split(',').first.trim(),
                ));
              } else {
                print('❌ Skipped: name=$name, imageUrl=$imageUrl, code=$code');
              }
            } catch (e) {
              print('⚠️ Error parsing product: $e');
            }
          }
          
          print('🎯 Filtered to ${results.length} products with valid images');
          
          // Sort by relevance
          results.sort((a, b) {
            final aName = a.name.toLowerCase();
            final bName = b.name.toLowerCase();
            final queryLower = query.toLowerCase();
            
            final aExact = aName.contains(queryLower) ? 0 : 1;
            final bExact = bName.contains(queryLower) ? 0 : 1;
            
            return aExact.compareTo(bExact);
          });
          
          return results;
        }
      }
      print('❌ No products found or API error (status: ${response.statusCode})');
      return [];
    } catch (e) {
      print('❌ Search error: $e');
      return [];
    }
  }

  /// Download and save image locally
  static Future<String?> downloadAndSaveImage(String imageUrl, String productId) async {
    try {
      final response = await http.get(Uri.parse(imageUrl)).timeout(_timeout);
      if (response.statusCode != 200) return null;

      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(path.join(appDir.path, 'product_images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final fileName = '$productId.jpg';
      final filePath = path.join(imagesDir.path, fileName);
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);

      return filePath;
    } catch (e) {
      return null;
    }
  }
}
