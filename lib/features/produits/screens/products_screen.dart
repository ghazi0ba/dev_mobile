import 'package:flutter/material.dart';
import 'package:dev_mobile/shared/models/models.dart';
import 'package:dev_mobile/features/produits/services/product_service.dart';
import 'package:dev_mobile/features/produits/screens/product_add_screen.dart';
import 'package:dev_mobile/features/produits/screens/product_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:dev_mobile/features/panier/widgets/cart_widgets.dart';
import 'package:dev_mobile/features/utilisateurs/widgets/current_user_scope.dart';

/// Products list screen with search and filters - CosmaPlus design
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

enum StockFilter { all, inStock, lowStock, outOfStock }

class _ProductsScreenState extends State<ProductsScreen> {
  final ProductService _productService = ProductService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  final Set<String> _selectedCategories = {};
  List<ProductCategory> _categories = [];
  bool _showFilters = false;

  // Additional filters
  RangeValues _priceRange = const RangeValues(0, 1000);
  StockFilter _stockFilter = StockFilter.all;
  final Set<String> _selectedLabels = {};

  // Available labels
  final List<String> _availableLabels = ['bio', 'vegan', 'naturel'];

  // Cache the stream
  late final Stream<List<Product>> _productsStream;

  // Colors from original
  static const Color primary = Color(0xFF8B5A47);
  static const Color background = Color(0xFFF8F6F4);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFF5F3F1);
  static const Color textPrimary = Color(0xFF3D3D3D);
  static const Color textSecondary = Color(0xFF7A7A7A);
  static const Color textLight = Color(0xFFB0B0B0);
  static const Color border = Color(0xFFD0D0D0);
  static const Color inStock = Color(0xFF5FAD56);
  static const Color lowStock = Color(0xFFE89B3C);
  static const Color outOfStock = Color(0xFFD64545);

  @override
  void initState() {
    super.initState();
    _productsStream = _productService.watchAllProducts();
    _loadCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _productService.getAllCategories();
      setState(() {
        _categories = categories;
      });
    } catch (e) {
      // Handle error silently
    }
  }

  void _navigateToAddProduct() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProductAddScreen()),
    );

    if (result == true) {
      setState(() {}); // Refresh
    }
  }

  void _navigateToProductDetail(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailScreen(product: product),
      ),
    );
  }

  List<Product> _filterProducts(List<Product> products) {
    var filtered = products;

    // Search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((p) {
        return p.name.toLowerCase().contains(query) ||
            p.description.toLowerCase().contains(query) ||
            p.brand.toLowerCase().contains(query) ||
            p.composition.toLowerCase().contains(query) ||
            p.sku.toLowerCase().contains(query);
      }).toList();
    }

    // Category filter
    if (_selectedCategories.isNotEmpty) {
      filtered = filtered
          .where((p) => _selectedCategories.contains(p.categoryId))
          .toList();
    }

    // Price range filter
    filtered = filtered.where((p) {
      return p.price >= _priceRange.start && p.price <= _priceRange.end;
    }).toList();

    // Stock filter
    if (_stockFilter != StockFilter.all) {
      filtered = filtered.where((p) {
        switch (_stockFilter) {
          case StockFilter.inStock:
            return p.stock > Product.lowStockThreshold;
          case StockFilter.lowStock:
            return p.stock > 0 && p.stock <= Product.lowStockThreshold;
          case StockFilter.outOfStock:
            return p.stock == 0;
          case StockFilter.all:
            return true;
        }
      }).toList();
    }

    // Labels filter
    if (_selectedLabels.isNotEmpty) {
      filtered = filtered.where((p) {
        return _selectedLabels.any((label) => p.labels.contains(label));
      }).toList();
    }

    return filtered;
  }

  String _getCategoryName(String categoryId) {
    try {
      return _categories.firstWhere((c) => c.id == categoryId).name;
    } catch (e) {
      return 'Sans catégorie';
    }
  }

  int get _activeFiltersCount {
    int count = 0;
    if (_searchQuery.isNotEmpty) count++;
    count += _selectedCategories.length;
    if (_priceRange.start > 0 || _priceRange.end < 1000) count++;
    if (_stockFilter != StockFilter.all) count++;
    count += _selectedLabels.length;
    return count;
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedCategories.clear();
      _priceRange = const RangeValues(0, 1000);
      _stockFilter = StockFilter.all;
      _selectedLabels.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Admin : gestion du catalogue. Client : boutique (pas d'ajout/modification).
    final isAdmin = CurrentUser.maybeOf(context)?.isAdmin ?? false;

    return Scaffold(
      backgroundColor: background,
      body: StreamBuilder<List<Product>>(
        stream: _productsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Chargement des produits...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Erreur: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          }

          final allProducts = snapshot.data ?? [];
          final filteredProducts = _filterProducts(allProducts);

          return SafeArea(
            child: Column(
              children: [
                // Header - Fixed at top
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          if (Navigator.canPop(context))
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back),
                              color: textPrimary,
                            ),
                          if (!Navigator.canPop(context))
                            const SizedBox(width: 8),
                          if (Navigator.canPop(context))
                            const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CosmaPlus',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.2,
                                  color: textSecondary,
                                ),
                              ),
                              Text(
                                isAdmin ? 'PRODUITS' : 'BOUTIQUE',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Filter toggle button
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showFilters = !_showFilters;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _showFilters ? primary : border,
                              width: _showFilters ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.tune, color: primary, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Recherche Avancée & Filtres',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                              const Spacer(),
                              if (_activeFiltersCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primary,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$_activeFiltersCount',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              const SizedBox(width: 8),
                              Icon(
                                _showFilters
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Filters panel - scrollable OR Products list - scrollable
                // KEY: Two different states based on _showFilters
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async => setState(() {}),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      slivers: [
                        if (_showFilters)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: RepaintBoundary(
                                child: _FiltersPanel(
                                  searchController: _searchController,
                                  searchQuery: _searchQuery,
                                  onSearchChanged: (value) =>
                                      setState(() => _searchQuery = value),
                                  categories: _categories,
                                  selectedCategories: _selectedCategories,
                                  onCategoryToggle: (categoryId) {
                                    setState(() {
                                      if (!_selectedCategories.remove(
                                        categoryId,
                                      )) {
                                        _selectedCategories.add(categoryId);
                                      }
                                    });
                                  },
                                  activeFiltersCount: _activeFiltersCount,
                                  onClearFilters: _clearFilters,
                                  priceRange: _priceRange,
                                  onPriceRangeChanged: (range) =>
                                      setState(() => _priceRange = range),
                                  stockFilter: _stockFilter,
                                  onStockFilterChanged: (filter) =>
                                      setState(() => _stockFilter = filter),
                                  selectedLabels: _selectedLabels,
                                  onLabelToggle: (label) {
                                    setState(() {
                                      if (!_selectedLabels.remove(label)) {
                                        _selectedLabels.add(label);
                                      }
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _ProductsCountSection(
                              count: filteredProducts.length,
                            ),
                          ),
                        ),
                        if (filteredProducts.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _activeFiltersCount > 0
                                        ? Icons.search_off
                                        : Icons.inventory_2_outlined,
                                    size: 64,
                                    color: textLight,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _activeFiltersCount > 0
                                        ? 'Aucun produit trouvé'
                                        : 'Aucun produit disponible',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 80),
                            sliver: SliverList.builder(
                              itemCount: filteredProducts.length,
                              itemBuilder: (context, index) {
                                final product = filteredProducts[index];
                                return _ProductCard(
                                  key: ValueKey(product.id),
                                  product: product,
                                  categoryName: _getCategoryName(
                                    product.categoryId,
                                  ),
                                  onTap: () =>
                                      _navigateToProductDetail(product),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: _navigateToAddProduct,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter'),
              backgroundColor: primary,
            )
          : null,
    );
  }
}

/// Products count section
class _ProductsCountSection extends StatelessWidget {
  final int count;

  const _ProductsCountSection({required this.count});

  static const Color textPrimary = Color(0xFF3D3D3D);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            '$count produits trouvés',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Filters panel widget
class _FiltersPanel extends StatefulWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final Function(String) onSearchChanged;
  final List<ProductCategory> categories;
  final Set<String> selectedCategories;
  final Function(String) onCategoryToggle;
  final int activeFiltersCount;
  final VoidCallback onClearFilters;
  final RangeValues priceRange;
  final Function(RangeValues) onPriceRangeChanged;
  final StockFilter stockFilter;
  final Function(StockFilter) onStockFilterChanged;
  final Set<String> selectedLabels;
  final Function(String) onLabelToggle;

  const _FiltersPanel({
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.categories,
    required this.selectedCategories,
    required this.onCategoryToggle,
    required this.activeFiltersCount,
    required this.onClearFilters,
    required this.priceRange,
    required this.onPriceRangeChanged,
    required this.stockFilter,
    required this.onStockFilterChanged,
    required this.selectedLabels,
    required this.onLabelToggle,
  });

  @override
  State<_FiltersPanel> createState() => _FiltersPanelState();
}

class _FiltersPanelState extends State<_FiltersPanel> {
  static const Color primary = Color(0xFF8B5A47);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFF5F3F1);
  static const Color textPrimary = Color(0xFF3D3D3D);
  static const Color textSecondary = Color(0xFF7A7A7A);
  static const Color border = Color(0xFFD0D0D0);
  static const Color inStock = Color(0xFF5FAD56);
  static const Color lowStock = Color(0xFFE89B3C);
  static const Color outOfStock = Color(0xFFD64545);

  late RangeValues _currentPriceRange;

  @override
  void initState() {
    super.initState();
    _currentPriceRange = widget.priceRange;
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'fr_FR', symbol: '€');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBackground.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search field
          Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: widget.searchController,
              onChanged: widget.onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Rosehip & Neroli',
                hintStyle: TextStyle(
                  color: textSecondary.withValues(alpha: 0.6),
                  fontSize: 15,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 22,
                  color: textSecondary.withValues(alpha: 0.7),
                ),
                suffixIcon: widget.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close,
                          size: 20,
                          color: textSecondary.withValues(alpha: 0.7),
                        ),
                        onPressed: () {
                          widget.searchController.clear();
                          widget.onSearchChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: primary, width: 2),
                ),
                filled: true,
                fillColor: surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Categories
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'GAMME & CATÉGORIE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: textPrimary,
                ),
              ),
              Text(
                '${widget.selectedCategories.length} option${widget.selectedCategories.length > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textSecondary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: border.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                childrenPadding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  bottom: 12,
                ),
                leading: Icon(
                  Icons.filter_list,
                  color: textSecondary.withValues(alpha: 0.7),
                  size: 20,
                ),
                title: Text(
                  widget.selectedCategories.isEmpty
                      ? 'Toutes les catégories'
                      : widget.selectedCategories.length == 1
                      ? widget.categories
                            .firstWhere(
                              (c) => c.id == widget.selectedCategories.first,
                            )
                            .name
                      : '${widget.selectedCategories.length} catégories sélectionnées',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                children: [
                  // "Tous" option
                  CheckboxListTile(
                    value: widget.selectedCategories.isEmpty,
                    onChanged: (bool? value) {
                      if (value == true &&
                          widget.selectedCategories.isNotEmpty) {
                        // Clear all categories
                        for (var cat in widget.categories) {
                          if (widget.selectedCategories.contains(cat.id)) {
                            widget.onCategoryToggle(cat.id);
                          }
                        }
                      }
                    },
                    title: const Text(
                      'Tous',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    activeColor: primary,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  const Divider(height: 8),
                  // Category options
                  ...widget.categories.map((category) {
                    final isSelected = widget.selectedCategories.contains(
                      category.id,
                    );
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (bool? value) {
                        widget.onCategoryToggle(category.id);
                      },
                      title: Text(
                        category.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      activeColor: primary,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Price range slider
          const Text(
            'FOURCHETTE DE PRIX',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${_currentPriceRange.start.round()} € — ${_currentPriceRange.end.round()} €',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primary,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: primary,
              inactiveTrackColor: border,
              thumbColor: primary,
              overlayColor: primary.withValues(alpha: 0.2),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              rangeThumbShape: const RoundRangeSliderThumbShape(
                enabledThumbRadius: 8,
              ),
              rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
            ),
            child: RangeSlider(
              values: _currentPriceRange,
              min: 0,
              max: 1000,
              divisions: 100,
              onChanged: (values) {
                setState(() {
                  _currentPriceRange = values;
                });
              },
              onChangeEnd: (values) {
                widget.onPriceRangeChanged(values);
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Min : ${formatter.format(0)}',
                style: TextStyle(
                  fontSize: 12,
                  color: textSecondary.withValues(alpha: 0.8),
                ),
              ),
              Text(
                'Moy : ${formatter.format(500)}',
                style: TextStyle(
                  fontSize: 12,
                  color: textSecondary.withValues(alpha: 0.8),
                ),
              ),
              Text(
                'Max : ${formatter.format(1000)}',
                style: TextStyle(
                  fontSize: 12,
                  color: textSecondary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Stock availability
          const Text(
            'DISPONIBILITÉ DU STOCK',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StockFilterOption(
                  label: 'En stock',
                  color: inStock,
                  isSelected: widget.stockFilter == StockFilter.inStock,
                  onTap: () => widget.onStockFilterChanged(
                    widget.stockFilter == StockFilter.inStock
                        ? StockFilter.all
                        : StockFilter.inStock,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _StockFilterOption(
                  label: 'Seuil alerte',
                  color: lowStock,
                  isSelected: widget.stockFilter == StockFilter.lowStock,
                  onTap: () => widget.onStockFilterChanged(
                    widget.stockFilter == StockFilter.lowStock
                        ? StockFilter.all
                        : StockFilter.lowStock,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _StockFilterOption(
                  label: 'Rupture',
                  color: outOfStock,
                  isSelected: widget.stockFilter == StockFilter.outOfStock,
                  onTap: () => widget.onStockFilterChanged(
                    widget.stockFilter == StockFilter.outOfStock
                        ? StockFilter.all
                        : StockFilter.outOfStock,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Botanical labels
          const Text(
            'LABELS BOTANIQUES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _LabelCheckbox(
                label: 'Bio certifié',
                value: 'bio',
                isChecked: widget.selectedLabels.contains('bio'),
                onChanged: () => widget.onLabelToggle('bio'),
              ),
              _LabelCheckbox(
                label: 'Vegan',
                value: 'vegan',
                isChecked: widget.selectedLabels.contains('vegan'),
                onChanged: () => widget.onLabelToggle('vegan'),
              ),
              _LabelCheckbox(
                label: '100% Naturel',
                value: 'naturel',
                isChecked: widget.selectedLabels.contains('naturel'),
                onChanged: () => widget.onLabelToggle('naturel'),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Apply and clear buttons
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Filters are applied automatically in real-time
                    // This button just provides visual feedback
                  },
                  icon: const Icon(Icons.check_circle, size: 20),
                  label: Text(
                    'Appliquer les filtres (${widget.activeFiltersCount})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    backgroundColor: primary,
                    foregroundColor: surface,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onClearFilters,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    side: BorderSide(color: border, width: 1.5),
                    backgroundColor: surface,
                    foregroundColor: textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Effacer tout',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Stock filter option widget
class _StockFilterOption extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _StockFilterOption({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF3D3D3D);
  static const Color border = Color(0xFFD0D0D0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : border.withValues(alpha: 0.5),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Label checkbox widget
class _LabelCheckbox extends StatelessWidget {
  final String label;
  final String value;
  final bool isChecked;
  final VoidCallback onChanged;

  const _LabelCheckbox({
    required this.label,
    required this.value,
    required this.isChecked,
    required this.onChanged,
  });

  static const Color primary = Color(0xFF8B5A47);
  static const Color textPrimary = Color(0xFF3D3D3D);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: isChecked ? primary : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isChecked ? primary : textPrimary.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: isChecked
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  final String categoryName;
  final VoidCallback onTap;

  const _ProductCard({
    required this.product,
    required this.categoryName,
    required this.onTap,
    required ValueKey<String> key,
  });

  static const Color primary = Color(0xFF8B5A47);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFF5F3F1);
  static const Color textPrimary = Color(0xFF3D3D3D);
  static const Color textSecondary = Color(0xFF7A7A7A);
  static const Color textLight = Color(0xFFB0B0B0);
  static const Color inStock = Color(0xFF5FAD56);
  static const Color lowStock = Color(0xFFE89B3C);
  static const Color outOfStock = Color(0xFFD64545);

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'fr_FR', symbol: '€');

    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                    ? Image.network(
                        product.imageUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 80,
                            height: 80,
                            color: cardBackground,
                            child: const Icon(
                              Icons.image_outlined,
                              color: textLight,
                              size: 32,
                            ),
                          );
                        },
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: cardBackground,
                        child: const Icon(
                          Icons.image_outlined,
                          color: textLight,
                          size: 32,
                        ),
                      ),
              ),
              const SizedBox(width: 12),

              // Product info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Brand/Category
                    Text(
                      product.brand.isNotEmpty
                          ? product.brand.toUpperCase()
                          : categoryName.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Badges
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [_StockBadge(stock: product.stock)],
                    ),
                    const SizedBox(height: 8),

                    // Product name
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Description
                    Text(
                      product.description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Price and volume
                    Row(
                      children: [
                        Text(
                          formatter.format(product.price),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: primary,
                          ),
                        ),
                        if (product.volume.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: cardBackground,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              product.volume,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Stock info and SKU reference
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 14,
                          color: _getStockColor(product.stock),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${product.stock} unités',
                          style: TextStyle(
                            fontSize: 11,
                            color: _getStockColor(product.stock),
                          ),
                        ),
                        if (product.sku.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            '•',
                            style: TextStyle(
                              fontSize: 11,
                              color: textSecondary.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Réf. ${product.sku}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Admin : flèche vers la fiche. Client : ajout rapide au panier.
              if (CurrentUser.maybeOf(context)?.isAdmin ?? false)
                const Icon(Icons.arrow_forward_ios, size: 16, color: textLight)
              else
                AddToCartButton(product: product, compact: true),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStockColor(int stock) {
    if (stock == 0) return outOfStock;
    if (stock <= Product.lowStockThreshold) return lowStock;
    return inStock;
  }
}

class _StockBadge extends StatelessWidget {
  final int stock;

  const _StockBadge({required this.stock});

  static const Color inStock = Color(0xFF5FAD56);
  static const Color lowStock = Color(0xFFE89B3C);
  static const Color outOfStock = Color(0xFFD64545);

  @override
  Widget build(BuildContext context) {
    final String text;
    final Color bgColor;
    final Color color;

    if (stock == 0) {
      text = 'Rupture';
      color = outOfStock;
      bgColor = outOfStock.withValues(alpha: 0.15);
    } else if (stock <= Product.lowStockThreshold) {
      text = 'Alerte stock';
      color = lowStock;
      bgColor = lowStock.withValues(alpha: 0.15);
    } else {
      text = 'Disponible';
      color = inStock;
      bgColor = inStock.withValues(alpha: 0.15);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF3D3D3D),
            ),
          ),
        ],
      ),
    );
  }
}
