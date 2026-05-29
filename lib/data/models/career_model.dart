class CareerBranch {
  final String name;
  final String description;

  CareerBranch({required this.name, required this.description});

  factory CareerBranch.fromJson(Map<String, dynamic> json) {
    return CareerBranch(
      name: json['name'] ?? '',
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
  };
}

class RoadmapNode {
  final String id;
  final String label;
  final List<String> nextSteps; 

  RoadmapNode({
    required this.id, 
    required this.label, 
    this.nextSteps = const []
  });

  factory RoadmapNode.fromJson(Map<String, dynamic> json) {
    return RoadmapNode(
      id: json['id']?.toString() ?? '',
      label: json['label'] ?? 'Unknown Step',
      nextSteps: List<String>.from(json['nextSteps'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'nextSteps': nextSteps,
  };
}

class CareerModel {
  final String id;
  final String name;
  final String expectedIncome;
  final int baseGraduationAge;
  final String description;
  final List<String> requiredStreams;
  final String examsNeeded;
  final String examLink;
  final String examLinkName;
  final List<RoadmapNode> roadmapSteps; 
  final String salaryBeginner;
  final String salaryMid;
  final String salaryHigh;
  final List<String> topCompanies;
  final List<CareerBranch> branches;
  final bool isTemporary; 

  // 🚀 NEW FIELDS: RPG Gamification
  final List<String> pros;
  final List<String> cons;
  final List<String> coreSkills;

  CareerModel({
    this.id = '',
    required this.name,
    required this.expectedIncome,
    required this.baseGraduationAge,
    required this.description,
    required this.requiredStreams,
    required this.examsNeeded,
    required this.examLink,
    required this.examLinkName,
    required this.roadmapSteps,
    required this.salaryBeginner,
    required this.salaryMid,
    required this.salaryHigh,
    required this.topCompanies,
    required this.branches,
    required this.pros,
    required this.cons,
    required this.coreSkills,
    this.isTemporary = false,
  });

  factory CareerModel.fromJson(Map<String, dynamic> json, {String id = '', bool isTemporary = false}) {
    return CareerModel(
      id: id,
      isTemporary: isTemporary,
      name: json['name'] ?? 'Unknown Career',
      expectedIncome: json['expectedIncome'] ?? 'Variable',
      baseGraduationAge: json['baseGraduationAge'] ?? 22,
      description: json['description'] ?? 'No description available.',
      requiredStreams: List<String>.from(json['requiredStreams'] ?? []),
      examsNeeded: json['examsNeeded'] ?? 'None specified',
      examLink: json['examLink'] ?? '',
      examLinkName: json['examLinkName'] ?? 'Search Online',
      roadmapSteps: (json['roadmapSteps'] as List<dynamic>?)
              ?.map((e) => RoadmapNode.fromJson(e as Map<String, dynamic>))
              .toList() ?? [],
      salaryBeginner: json['salaryBeginner'] ?? 'TBD',
      salaryMid: json['salaryMid'] ?? 'TBD',
      salaryHigh: json['salaryHigh'] ?? 'TBD',
      topCompanies: List<String>.from(json['topCompanies'] ?? []),
      branches: (json['branches'] as List<dynamic>?)
              ?.map((e) => CareerBranch.fromJson(e as Map<String, dynamic>))
              .toList() ?? [],
      // 🚀 Parse the new fields safely
      pros: List<String>.from(json['pros'] ?? []),
      cons: List<String>.from(json['cons'] ?? []),
      coreSkills: List<String>.from(json['coreSkills'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'expectedIncome': expectedIncome,
    'baseGraduationAge': baseGraduationAge,
    'description': description,
    'requiredStreams': requiredStreams,
    'examsNeeded': examsNeeded,
    'examLink': examLink,
    'examLinkName': examLinkName,
    'roadmapSteps': roadmapSteps.map((e) => e.toJson()).toList(), 
    'salaryBeginner': salaryBeginner,
    'salaryMid': salaryMid,
    'salaryHigh': salaryHigh,
    'topCompanies': topCompanies,
    'branches': branches.map((e) => e.toJson()).toList(),
    'pros': pros,
    'cons': cons,
    'coreSkills': coreSkills,
  };
}