class PlantDisease {
  final String name;
  final List<String> treatments;
  final String description;
  final bool isUnknown; // Added to distinguish unknown conditions
  final String? imagePath; // Path to the reference image

  PlantDisease({
    required this.name,
    required this.treatments,
    required this.description,
    this.isUnknown = false,
    this.imagePath,
  });

  // Mock Repository to map model labels to data
  // Pro-Tip: For 70 classes, ensure these keys match your labels.txt exactly (after cleaning)
  static final Map<String, PlantDisease> _diseaseData = {
    'algal_leaf_spot_jackfruit': PlantDisease(
      name: "Algal Leaf Spot (Jackfruit)",
      description: "Caused by the parasitic alga 'Cephaleuros virescens'. It typically appears as circular, velvety, green-to-orange spots on the upper leaf surface. While often cosmetic, a high density of spots can block sunlight and reduce the plant's photosynthetic efficiency.",
      imagePath: "assets/images/diseases/jackfruit_algal_spot.jpg",
      treatments: [
        "Prune internal branches to improve light penetration and air circulation.",
        "Collect and destroy fallen infected leaves to reduce the source of inoculum.",
        "Apply a preventive copper-based fungicide spray during the onset of the rainy season.",
        "Maintain tree health with balanced NPK fertilization to improve natural immunity."
      ],
    ),
    'anthracnose_mango': PlantDisease(
      name: "Anthracnose (Mango)",
      description: "A major fungal disease caused by 'Colletotrichum gloeosporioides'. Symptoms include dark, irregular necrotic spots on leaves and 'blossom blight' on flowers. In wet weather, it can cause deep cracks in the fruit and post-harvest rot.",
      imagePath: "assets/images/diseases/mango_anthracnose.jpg",
      treatments: [
        "Sanitation: Prune and burn infected twigs and panicles during the dry season.",
        "Avoid overhead irrigation; keep the canopy dry to prevent spore dispersal.",
        "Spray fungicides like Mancozeb or Carbendazim at 15-day intervals during the flowering and fruit-setting stages.",
        "Post-harvest: Dip fruits in hot water (52°C) for 5 minutes to control latent infections."
      ],
    ),
    'aphids_cotton': PlantDisease(
      name: "Aphids (Cotton)",
      description: "Small, soft-bodied insects ('Aphis gossypii') that suck sap from the undersides of leaves. This causes leaves to curl downwards, turn yellow, and results in stunted plant growth. They also excrete honeydew, which leads to the growth of black sooty mold.",
      imagePath: "assets/images/diseases/cotton_aphids.jpg",
      treatments: [
        "Biological Control: Conserve natural predators like ladybugs, lacewings, and hoverflies.",
        "Apply Neem oil (1%) or insecticidal soaps directly to the undersides of the leaves.",
        "Avoid excessive nitrogen fertilization, as it attracts larger aphid populations.",
        "In case of heavy infestation, use targeted systemic insecticides such as Imidacloprid."
      ],
    ),
    'leaf_scorch_strawberry': PlantDisease(
      name: "Leaf Scorch (Strawberry)",
      description: "A fungal infection caused by 'Diplocarpon earlianum'. It begins as small, purplish spots that expand into large brown lesions. Unlike leaf spot, the centers of these lesions do not turn white, making the entire leaf appear 'scorched' or burnt.",
      imagePath: "assets/images/diseases/strawberry_scorch.jpg",
      treatments: [
        "Plant resistant cultivars and ensure proper spacing for maximum airflow.",
        "Renovate strawberry beds after harvest by mowing and removing old foliage.",
        "Mulch around plants to prevent soil-borne spores from splashing onto leaves.",
        "Apply protective fungicides (e.g., Captan or Thiophanate-methyl) early in the spring before bloom."
      ],
    ),
    'black_rot_cauliflower': PlantDisease(
      name: "Black Rot (Cauliflower)",
      description: "One of the most destructive bacterial diseases of crucifers, caused by 'Xanthomonas campestris'. It is identified by characteristic V-shaped yellow lesions starting at the leaf margins. Veins within these areas eventually turn black.",
      imagePath: "assets/images/diseases/cauliflower_black_rot.jpg",
      treatments: [
        "Seed Treatment: Use certified disease-free seeds or treat seeds with hot water (50°C for 20 mins) before planting.",
        "Practice a 3-4 year crop rotation, avoiding any plants in the cabbage family.",
        "Control weeds and insects that can act as vectors or alternative hosts.",
        "Avoid working in the fields when the plants are wet to prevent spreading the bacteria."
      ],
    ),
    'tomato_blight': PlantDisease(
      name: "Tomato Late Blight",
      description: "A fast-moving and destructive disease caused by the oomycete 'Phytophthora infestans'. It appears as water-soaked grey-green spots on leaves that quickly turn brown and papery.",
      treatments: [
        "Apply copper-based fungicides immediately upon detection.",
        "Destroy infected plants; do not compost them as spores can survive.",
        "Space plants correctly to maximize airflow.",
        "Use drip irrigation to keep water off the leaves."
      ],
    ),
    'healthy': PlantDisease(
      name: "Healthy Plant",
      description: "No signs of disease or pest infestation detected. The foliage looks vibrant and the cellular structure appears intact according to the visual scan.",
      treatments: [
        "Continue with your current watering and sunlight schedule.",
        "Inspect the undersides of leaves weekly for early signs of pests.",
        "Clean the leaves with a damp cloth occasionally to prevent dust buildup.",
        "Consider a balanced organic fertilizer during the growing season."
      ],
      isUnknown: false,
    ),
    'apple_black_rot': PlantDisease(
      name: "Apple Black Rot",
      description: "A complex fungal disease ('Botryosphaeria obtusa') that affects leaves (frog-eye leaf spot), bark, and fruit. It often enters through wounds caused by pruning or insects.",
      treatments: [
        "Prune out dead or cankered limbs during the dormant season.",
        "Remove infected fruit ('mummies') from the tree and the ground.",
        "Apply labeled fungicides during the growing season.",
        "Maintain tree health through proper fertilization and watering to limit entry points."
      ],
      isUnknown: false,
    ),
  };

  static PlantDisease getInfo(String label) {
    // Clean the label: 
    // 1. Remove indices (e.g., "0 ")
    // 2. Convert to lowercase
    // 3. Replace non-alphanumeric with underscores and trim trailing ones
    final cleanLabel = label
        .replaceAll(RegExp(r'^\d+\s+'), '') // Remove leading numbers
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_') // Replace spaces/special chars with _
        .replaceAll(RegExp(r'_+'), '_') // Collapse multiple underscores
        .replaceAll(RegExp(r'^_'), '') // Remove leading underscores
        .replaceAll(RegExp(r'_$'), '') // Remove trailing underscores
        .trim();

    // Shortcut: If the label contains 'healthy', return the generic healthy data
    if (cleanLabel.contains('healthy')) {
      return _diseaseData['healthy']!;
    }

    if (_diseaseData.containsKey(cleanLabel)) {
      return _diseaseData[cleanLabel]!;
    } else if (cleanLabel.contains('unknown')) {
      return PlantDisease(
        name: "Unknown Condition",
        description: "The scan is inconclusive. Please ensure the leaf is centered and well-lit.",
        treatments: [
          "Try adjusting the camera angle.",
          "Move to an area with brighter indirect light."
        ],
        isUnknown: true,
      );
    } else {
        return PlantDisease(
          name: label.replaceAll('_', ' '),
          description: "No specific data available for this condition.",
          treatments: ["Consult a local botanist.", "Ensure proper soil pH."],
          isUnknown: true,
        );
    }
  }
}