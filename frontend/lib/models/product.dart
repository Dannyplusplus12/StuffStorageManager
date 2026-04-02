class Variant {
  final int? id;
  final String color;
  final String size;
  final int price;
  final int stock;

  Variant({this.id, required this.color, required this.size, required this.price, required this.stock});

  factory Variant.fromJson(Map<String, dynamic> j) => Variant(
        id: j['id'],
        color: j['color'] ?? '',
        size: j['size'] ?? '',
        price: (j['price'] ?? 0) as int,
        stock: (j['stock'] ?? 0) as int,
      );

  Map<String, dynamic> toJson() => {'id': id, 'color': color, 'size': size, 'price': price, 'stock': stock};
}

class Product {
  final int id;
  final String code;
  final String name;
  final String image;
  final String priceRange;
  final List<Variant> variants;

  Product({required this.id, required this.code, required this.name, required this.image, required this.priceRange, required this.variants});

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'],
        code: j['code'] ?? '',
        name: j['name'] ?? '',
        image: j['image'] ?? '',
        priceRange: j['price_range'] ?? '',
        variants: (j['variants'] as List? ?? []).map((v) => Variant.fromJson(v)).toList(),
      );
}
