import '../models/metadata.dart';

/// Schema profile generator for Local Business entities.
class LocalBusinessProfile {
  const LocalBusinessProfile({
    required this.name,
    required this.streetAddress,
    required this.addressLocality,
    required this.addressRegion,
    required this.postalCode,
    required this.telephone,
    this.latitude,
    this.longitude,
    this.priceRange = '\$\$',
    this.openingHours = const ['Mo-Fr 09:00-18:00'],
    this.image,
  });

  final String name;
  final String streetAddress;
  final String addressLocality;
  final String addressRegion;
  final String postalCode;
  final String telephone;
  final double? latitude;
  final double? longitude;
  final String priceRange;
  final List<String> openingHours;
  final String? image;

  JsonLd toJsonLd({required String url}) => JsonLd({
    '@context': 'https://schema.org',
    '@type': 'LocalBusiness',
    'name': name,
    'url': url,
    if (image != null) 'image': image,
    'telephone': telephone,
    'priceRange': priceRange,
    'address': {
      '@type': 'PostalAddress',
      'streetAddress': streetAddress,
      'addressLocality': addressLocality,
      'addressRegion': addressRegion,
      'postalCode': postalCode,
    },
    if (latitude != null && longitude != null)
      'geo': {
        '@type': 'GeoCoordinates',
        'latitude': latitude,
        'longitude': longitude,
      },
    'openingHours': openingHours,
  });
}

/// Schema profile generator for Job Postings.
class JobPostingProfile {
  const JobPostingProfile({
    required this.title,
    required this.description,
    required this.datePosted,
    required this.validThrough,
    required this.hiringOrganizationName,
    required this.hiringOrganizationUrl,
    required this.jobLocationCity,
    required this.baseSalaryAmount,
    required this.baseSalaryCurrency,
    this.employmentType = 'FULL_TIME',
  });

  final String title;
  final String description;
  final String datePosted;
  final String validThrough;
  final String hiringOrganizationName;
  final String hiringOrganizationUrl;
  final String jobLocationCity;
  final double baseSalaryAmount;
  final String baseSalaryCurrency;
  final String employmentType;

  JsonLd toJsonLd({required String url}) => JsonLd({
    '@context': 'https://schema.org',
    '@type': 'JobPosting',
    'title': title,
    'description': description,
    'datePosted': datePosted,
    'validThrough': validThrough,
    'employmentType': employmentType,
    'hiringOrganization': {
      '@type': 'Organization',
      'name': hiringOrganizationName,
      'sameAs': hiringOrganizationUrl,
    },
    'jobLocation': {
      '@type': 'Place',
      'address': {'@type': 'PostalAddress', 'addressLocality': jobLocationCity},
    },
    'baseSalary': {
      '@type': 'MonetaryAmount',
      'currency': baseSalaryCurrency,
      'value': {
        '@type': 'QuantitativeValue',
        'value': baseSalaryAmount,
        'unitText': 'YEAR',
      },
    },
  });
}

/// Schema profile generator for Recipes.
class RecipeProfile {
  const RecipeProfile({
    required this.name,
    required this.description,
    required this.image,
    required this.author,
    required this.prepTimeMinutes,
    required this.cookTimeMinutes,
    required this.recipeYield,
    required this.ingredients,
    required this.instructions,
    this.calories,
  });

  final String name;
  final String description;
  final String image;
  final String author;
  final int prepTimeMinutes;
  final int cookTimeMinutes;
  final String recipeYield;
  final List<String> ingredients;
  final List<String> instructions;
  final int? calories;

  JsonLd toJsonLd({required String url}) => JsonLd({
    '@context': 'https://schema.org',
    '@type': 'Recipe',
    'name': name,
    'description': description,
    'image': image,
    'author': {'@type': 'Person', 'name': author},
    'prepTime': 'PT${prepTimeMinutes}M',
    'cookTime': 'PT${cookTimeMinutes}M',
    'recipeYield': recipeYield,
    'recipeIngredient': ingredients,
    'recipeInstructions': [
      for (final inst in instructions) {'@type': 'HowToStep', 'text': inst},
    ],
    if (calories != null)
      'nutrition': {
        '@type': 'NutritionInformation',
        'calories': '$calories calories',
      },
  });
}

/// Schema profile generator for Courses and Educational programs.
class CourseProfile {
  const CourseProfile({
    required this.name,
    required this.description,
    required this.providerName,
    required this.providerUrl,
    this.courseCode,
  });

  final String name;
  final String description;
  final String providerName;
  final String providerUrl;
  final String? courseCode;

  JsonLd toJsonLd({required String url}) => JsonLd({
    '@context': 'https://schema.org',
    '@type': 'Course',
    'name': name,
    'description': description,
    if (courseCode != null) 'courseCode': courseCode,
    'provider': {
      '@type': 'Organization',
      'name': providerName,
      'sameAs': providerUrl,
    },
  });
}
