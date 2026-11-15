import 'package:flutter/material.dart';
import 'package:dev_mobile/shared/models/models.dart';
import 'package:dev_mobile/features/produits/services/product_service.dart';
import 'package:dev_mobile/features/produits/screens/product_edit_screen.dart';
import 'package:intl/intl.dart';

/// Product detail screen with actions
class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final ProductService _productService = ProductService();
  late Product _product;
  String _categoryName = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _loadCategory();
  }

  Future<void> _loadCategory() async {
    try {
      final categories = await _productService.getAllCategories();
      final category =
          categories.where((c) => c.id == _product.categoryId).firstOrNull;
      setState(() {
        _categoryName = category?.name ?? 'Sans catégorie';
      });
    } catch (e) {
      setState(() {
        _categoryName = 'Sans catégorie';
      });
    }
  }

  Future<void> _deleteProduct() async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer "${_product.name}" ?\n\nCette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _productService.deleteProduct(_product.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produit supprimé avec succès')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _adjustStock() async {
    final controller = TextEditingController(text: _product.stock.toString());

    final newStock = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajuster le stock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_product.name),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Nouvelle quantité',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value >= 0) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (newStock == null) return;

    try {
      await _productService.updateStock(_product.id, newStock);
      setState(() {
        _product = _product.copyWith(stock: newStock);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock mis à jour')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _navigateToEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductEditScreen(product: _product),
      ),
    );

    if (result is Product) {
      setState(() {
        _product = result;
      });
      _loadCategory();
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'fr_FR', symbol: '€');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du produit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _navigateToEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _isLoading ? null : _deleteProduct,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product image
                  if (_product.imageUrl != null &&
                      _product.imageUrl!.isNotEmpty)
                    Image.network(
                      _product.imageUrl!,
                      width: double.infinity,
                      height: 300,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: double.infinity,
                          height: 300,
                          color: Colors.grey[300],
                          child: const Icon(Icons.image_not_supported, size: 64),
                        );
                      },
                    )
                  else
                    Container(
                      width: double.infinity,
                      height: 300,
                      color: Colors.grey[300],
                      child: const Icon(Icons.inventory_2_outlined, size: 64),
                    ),

                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category
                        Text(
                          _categoryName.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Product name
                        Text(
                          _product.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Price and volume
                        Row(
                          children: [
                            Text(
                              formatter.format(_product.price),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            if (_product.volume.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Chip(
                                label: Text(_product.volume),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Stock info
                        _StockInfo(stock: _product.stock),
                        const SizedBox(height: 24),

                        // Brand
                        if (_product.brand.isNotEmpty) ...[
                          const Text(
                            'Marque',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _product.brand,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // SKU
                        if (_product.sku.isNotEmpty) ...[
                          const Text(
                            'Référence (SKU)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _product.sku,
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Description
                        if (_product.description.isNotEmpty) ...[
                          const Text(
                            'Description',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _product.description,
                            style: const TextStyle(fontSize: 16, height: 1.5),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Composition
                        if (_product.composition.isNotEmpty) ...[
                          const Text(
                            'Composition',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _product.composition,
                            style: const TextStyle(fontSize: 16, height: 1.5),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Labels
                        if (_product.labels.isNotEmpty) ...[
                          const Text(
                            'Labels',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _product.labels
                                .map((label) => Chip(label: Text(label)))
                                .toList(),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Created at
                        if (_product.createdAt != null) ...[
                          Text(
                            'Ajouté le ${DateFormat('dd/MM/yyyy').format(_product.createdAt!)}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Action buttons
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _adjustStock,
                            icon: const Icon(Icons.add_circle_outline),
                            label: const Text('Ajuster le stock'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _navigateToEdit,
                            icon: const Icon(Icons.edit),
                            label: const Text('Modifier le produit'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                            onPressed: _isLoading ? null : _deleteProduct,
                            icon: const Icon(Icons.delete, color: Colors.red),
                            label: const Text(
                              'Supprimer le produit',
                              style: TextStyle(color: Colors.red),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _StockInfo extends StatelessWidget {
  final int stock;

  const _StockInfo({required this.stock});

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String text;
    final IconData icon;

    if (stock == 0) {
      color = Colors.red;
      text = 'Rupture de stock';
      icon = Icons.close;
    } else if (stock <= Product.lowStockThreshold) {
      color = Colors.orange;
      text = 'Stock faible';
      icon = Icons.warning;
    } else {
      color = Colors.green;
      text = 'En stock';
      icon = Icons.check_circle;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$stock unités disponibles',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
