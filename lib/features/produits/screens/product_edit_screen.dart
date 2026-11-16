import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dev_mobile/shared/models/models.dart';
import 'package:dev_mobile/features/produits/services/product_service.dart';
import 'package:dev_mobile/features/produits/services/cloudinary_service.dart';

/// Screen for editing an existing product
class ProductEditScreen extends StatefulWidget {
  final Product product;

  const ProductEditScreen({super.key, required this.product});

  @override
  State<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends State<ProductEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final ProductService _productService = ProductService();
  final CloudinaryService _cloudinaryService = CloudinaryService();
  final ImagePicker _picker = ImagePicker();

  // Form controllers
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  late TextEditingController _skuController;
  late TextEditingController _brandController;
  late TextEditingController _compositionController;
  late TextEditingController _volumeController;
  late TextEditingController _imageUrlController;

  List<ProductCategory> _categories = [];
  String? _selectedCategoryId;
  File? _selectedImageFile;
  bool _isLoading = false;
  bool _isUploadingImage = false;
  late List<String> _labels;

  final List<String> _availableLabels = [
    'bio',
    'vegan',
    'naturel',
    'cruelty-free',
  ];

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing product data
    _nameController = TextEditingController(text: widget.product.name);
    _descriptionController = TextEditingController(
      text: widget.product.description,
    );
    _priceController = TextEditingController(
      text: widget.product.price.toString(),
    );
    _stockController = TextEditingController(
      text: widget.product.stock.toString(),
    );
    _skuController = TextEditingController(text: widget.product.sku);
    _brandController = TextEditingController(text: widget.product.brand);
    _compositionController = TextEditingController(
      text: widget.product.composition,
    );
    _volumeController = TextEditingController(text: widget.product.volume);
    _imageUrlController = TextEditingController(
      text: widget.product.imageUrl ?? '',
    );

    _selectedCategoryId = widget.product.categoryId;
    _labels = List<String>.from(widget.product.labels);

    _loadCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _skuController.dispose();
    _brandController.dispose();
    _compositionController.dispose();
    _volumeController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _productService.getAllCategories();

      // Ensure we have a default category
      if (categories.isEmpty) {
        final defaultCategoryId = await _productService.addCategory(
          'Non catégorisé',
        );
        final defaultCategory = ProductCategory(
          id: defaultCategoryId,
          name: 'Non catégorisé',
        );
        setState(() {
          _categories = [defaultCategory];
          if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
            _selectedCategoryId = defaultCategoryId;
          }
        });
      } else {
        setState(() {
          _categories = categories;
          // Ensure selected category still exists
          if (_selectedCategoryId != null &&
              !categories.any((c) => c.id == _selectedCategoryId)) {
            _selectedCategoryId = categories.first.id;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1080,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImageFile = File(image.path);
        });
        await _uploadImage();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sélection: $e')),
        );
      }
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImageFile == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      final imageUrl = await _cloudinaryService.uploadImage(
        _selectedImageFile!,
      );
      setState(() {
        _imageUrlController.text = imageUrl;
        _isUploadingImage = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image téléchargée avec succès')),
        );
      }
    } catch (e) {
      setState(() {
        _isUploadingImage = false;
        _selectedImageFile = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Caméra'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Auto-assign default category if none selected
    if (_selectedCategoryId == null || _selectedCategoryId!.isEmpty) {
      if (_categories.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur: aucune catégorie disponible')),
        );
        return;
      }
      _selectedCategoryId = _categories.first.id;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final updatedProduct = widget.product.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text),
        stock: int.parse(_stockController.text),
        categoryId: _selectedCategoryId!,
        sku: _skuController.text.trim(),
        brand: _brandController.text.trim(),
        composition: _compositionController.text.trim(),
        volume: _volumeController.text.trim(),
        imageUrl: _imageUrlController.text.trim().isEmpty
            ? null
            : _imageUrlController.text.trim(),
        labels: _labels,
      );

      await _productService.updateProduct(updatedProduct);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produit modifié avec succès')),
        );
        Navigator.pop(context, updatedProduct);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier le produit')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image section
                    _buildSectionTitle('Image du produit'),
                    const SizedBox(height: 12),
                    _buildImagePicker(),
                    const SizedBox(height: 24),

                    // Basic information
                    _buildSectionTitle('Informations principales'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom du produit *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Le nom est requis';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Category dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Catégorie',
                        hintText: 'Sélectionner une catégorie',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category.id,
                          child: Text(category.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategoryId = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _brandController,
                      decoration: const InputDecoration(
                        labelText: 'Marque',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Price and inventory
                    _buildSectionTitle('Prix & Inventaire'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _priceController,
                            decoration: const InputDecoration(
                              labelText: 'Prix (€) *',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Le prix est requis';
                              }
                              if (double.tryParse(value) == null) {
                                return 'Prix invalide';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _volumeController,
                            decoration: const InputDecoration(
                              labelText: 'Volume (ex: 30 ml)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _stockController,
                      decoration: const InputDecoration(
                        labelText: 'Quantité en stock *',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Le stock est requis';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Stock invalide';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Description
                    _buildSectionTitle('Description'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description *',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'La description est requise';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _compositionController,
                      decoration: const InputDecoration(
                        labelText: 'Composition / Ingrédients',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 24),

                    // Additional info
                    _buildSectionTitle('Informations additionnelles'),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _skuController,
                      decoration: const InputDecoration(
                        labelText: 'SKU / Référence',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Labels
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
                      children: _availableLabels.map((label) {
                        final isSelected = _labels.contains(label);
                        return FilterChip(
                          label: Text(label),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _labels.add(label);
                              } else {
                                _labels.remove(label);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),

                    // Action buttons
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveProduct,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Enregistrer les modifications'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Annuler'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildImagePicker() {
    final hasImage =
        _selectedImageFile != null || _imageUrlController.text.isNotEmpty;

    return GestureDetector(
      onTap: _isUploadingImage ? null : _showImageSourcePicker,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[400]!),
        ),
        child: _isUploadingImage
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Téléchargement en cours...'),
                  ],
                ),
              )
            : hasImage
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _selectedImageFile != null
                    ? Image.file(_selectedImageFile!, fit: BoxFit.cover)
                    : Image.network(
                        _imageUrlController.text,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Icon(Icons.broken_image, size: 64),
                          );
                        },
                      ),
              )
            : const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 8),
                    Text('Toucher pour changer l\'image'),
                  ],
                ),
              ),
      ),
    );
  }
}
