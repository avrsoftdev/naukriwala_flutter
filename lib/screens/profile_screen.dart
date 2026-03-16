// ignore_for_file: unrelated_type_equality_checks

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:image_picker/image_picker.dart';
import 'package:naukariwala/services/auth_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:naukariwala/widgets/address_autocomplete_field.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:developer' as dev;

Future<List<String>> _loadSkillsFromAsset() async {
  final raw = await rootBundle.loadString('assets/data/skills.json');
  final decoded = jsonDecode(raw);

  if (decoded is List) {
    final skills = decoded
        .map((e) {
          if (e is String) return e;
          if (e is Map && e['skill'] is String) return e['skill'] as String;
          return null;
        })
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    skills.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return skills;
  }

  return const <String>[];
}

// Map old skills to new skills.json format for backward compatibility
Map<String, String> _getOldToNewSkillsMapping() {
  return {
    'Java': 'Java Development',
    'Python': 'Python Development',
    'C++': 'C++ Development',
    'C#': 'C# Development',
    'Dart': 'Dart Development',
    'Flutter': 'Flutter Development',
    'Android': 'Android Development',
    'iOS': 'iOS Development',
    'React': 'React Development',
    'Angular': 'Angular Development',
    'Vue.js': 'Vue.js Development',
    'Node.js': 'Node.js Development',
    'Firebase': 'Firebase Development',
    'MongoDB': 'MongoDB Development',
    'MySQL': 'MySQL Development',
    'PostgreSQL': 'PostgreSQL Development',
    'AWS': 'AWS Development',
    'Azure': 'Azure Development',
    'GCP': 'GCP Development',
    'Docker': 'Docker Development',
    'Kubernetes': 'Kubernetes Development',
    'Jenkins': 'Jenkins Development',
    'Git': 'Git Development',
    'Linux': 'Linux Development',
    'Ubuntu': 'Ubuntu Development',
    'Windows': 'Windows Development',
    'macOS': 'macOS Development',
    'Machine Learning': 'Machine Learning Development',
    'Data Science': 'Data Science Development',
    'Deep Learning': 'Deep Learning Development',
    'AI': 'AI Development',
    'TensorFlow': 'TensorFlow Development',
    'PyTorch': 'PyTorch Development',
    'HTML': 'HTML Development',
    'CSS': 'CSS Development',
    'JavaScript': 'JavaScript Development',
    'TypeScript': 'TypeScript Development',
    'PHP': 'PHP Development',
    'Ruby': 'Ruby Development',
    'Go': 'Go Development',
    'Rust': 'Rust Development',
    'Swift': 'Swift Development',
    'Kotlin': 'Kotlin Development',
    'Scala': 'Scala Development',
    'R': 'R Development',
    'MATLAB': 'MATLAB Development',
    'Salesforce': 'Salesforce Development',
    'SAP': 'SAP Development',
    'Oracle': 'Oracle Development',
    'SharePoint': 'SharePoint Development',
    'Testing': 'Testing Development',
    'QA': 'QA Development',
    'Agile': 'Agile Development',
    'Scrum': 'Scrum Development',
    'DevOps': 'DevOps Development',
    'CI/CD': 'CI/CD Development',
    'UI/UX': 'UI/UX Development',
    'UX': 'UX Development',
    'UI': 'UI Development',
    'Figma': 'Figma Development',
    'Sketch': 'Sketch Development',
    'Adobe XD': 'Adobe XD Development',
    'Photoshop': 'Photoshop Development',
    'Illustrator': 'Illustrator Development',
    'InDesign': 'InDesign Development',
    'Premiere Pro': 'Premiere Pro Development',
    'After Effects': 'After Effects Development',
    'Final Cut Pro': 'Final Cut Pro Development',
    'Video Editing': 'Video Editing Development',
    'Audio Editing': 'Audio Editing Development',
    'Content Writing': 'Content Writing Development',
    'Copywriting': 'Copywriting Development',
    'Technical Writing': 'Technical Writing Development',
    'Blog Writing': 'Blog Writing Development',
    'SEO': 'SEO Development',
    'SEM': 'SEM Development',
    'SMM': 'SMM Development',
    'Email Marketing': 'Email Marketing Development',
    'Social Media Marketing': 'Social Media Marketing Development',
    'Digital Marketing': 'Digital Marketing Development',
    'Marketing': 'Marketing Development',
    'Sales': 'Sales Development',
    'Business Development': 'Business Development Development',
    'Product Management': 'Product Management Development',
    'Project Management': 'Project Management Development',
    'Program Management': 'Program Management Development',
    'Portfolio Management': 'Portfolio Management Development',
    'Risk Management': 'Risk Management Development',
    'Financial Management': 'Financial Management Development',
    'Accounting': 'Accounting Development',
    'Finance': 'Finance Development',
    'Banking': 'Banking Development',
    'Insurance': 'Insurance Development',
    'Investment': 'Investment Development',
    'Tax': 'Tax Development',
    'Audit': 'Audit Development',
    'Compliance': 'Compliance Development',
    'Legal': 'Legal Development',
    'HR': 'HR Development',
    'Recruitment': 'Recruitment Development',
    'Training': 'Training Development',
    'Learning': 'Learning Development',
    'Education': 'Education Development',
    'Teaching': 'Teaching Development',
    'Research': 'Research Development',
    'Analytics': 'Analytics Development',
    'Business Intelligence': 'Business Intelligence Development',
    'Data Warehousing': 'Data Warehousing Development',
    'Data Mining': 'Data Mining Development',
    'Data Visualization': 'Data Visualization Development',
    'Reporting': 'Reporting Development',
    'Dashboard': 'Dashboard Development',
    'KPI': 'KPI Development',
    'Metrics': 'Metrics Development',
    'Performance': 'Performance Development',
    'Optimization': 'Optimization Development',
    'Automation': 'Automation Development',
    'Integration': 'Integration Development',
    'Migration': 'Migration Development',
    'Upgradation': 'Upgradation Development',
    'Maintenance': 'Maintenance Development',
    'Support': 'Support Development',
    'Troubleshooting': 'Troubleshooting Development',
    'Monitoring': 'Monitoring Development',
    'Alerting': 'Alerting Development',
    'Logging': 'Logging Development',
    'Debugging': 'Debugging Development',
    'Testing': 'Testing Development',
    'Documentation': 'Documentation Development',
    'Deployment': 'Deployment Development',
    'Configuration': 'Configuration Development',
    'Installation': 'Installation Development',
    'Setup': 'Setup Development',
    'Implementation': 'Implementation Development',
    'Customization': 'Customization Development',
    'Enhancement': 'Enhancement Development',
    'Modification': 'Modification Development',
    'Improvement': 'Improvement Development',
    'Innovation': 'Innovation Development',
    'Strategy': 'Strategy Development',
    'Planning': 'Planning Development',
    'Architecture': 'Architecture Development',
    'Design': 'Design Development',
    'Analysis': 'Analysis Development',
    'Consulting': 'Consulting Development',
    'Advisory': 'Advisory Development',
    'Mentoring': 'Mentoring Development',
    'Coaching': 'Coaching Development',
    'Leadership': 'Leadership Development',
    'Management': 'Management Development',
    'Administration': 'Administration Development',
    'Operations': 'Operations Development',
    'Process': 'Process Development',
    'Workflow': 'Workflow Development',
    'Quality': 'Quality Development',
    'Standards': 'Standards Development',
    'Best Practices': 'Best Practices Development',
    'Guidelines': 'Guidelines Development',
    'Policies': 'Policies Development',
    'Procedures': 'Procedures Development',
    'Protocols': 'Protocols Development',
    'Standards': 'Standards Development',
    'Frameworks': 'Frameworks Development',
    'Methodologies': 'Methodologies Development',
    'Tools': 'Tools Development',
    'Technologies': 'Technologies Development',
    'Platforms': 'Platforms Development',
    'Systems': 'Systems Development',
    'Applications': 'Applications Development',
    'Software': 'Software Development',
    'Hardware': 'Hardware Development',
    'Networking': 'Networking Development',
    'Security': 'Security Development',
    'Cloud': 'Cloud Development',
    'Edge': 'Edge Development',
    'IoT': 'IoT Development',
    'Mobile': 'Mobile Development',
    'Web': 'Web Development',
    'Desktop': 'Desktop Development',
    'Embedded': 'Embedded Development',
    'Gaming': 'Gaming Development',
    'AR': 'AR Development',
    'VR': 'VR Development',
    'MR': 'MR Development',
    'Blockchain': 'Blockchain Development',
    'Cryptocurrency': 'Cryptocurrency Development',
    'NFT': 'NFT Development',
    'Metaverse': 'Metaverse Development',
    'Robotics': 'Robotics Development',
    'Drones': 'Drones Development',
    '3D Printing': '3D Printing Development',
    'Biometrics': 'Biometrics Development',
    'Quantum': 'Quantum Development',
    '5G': '5G Development',
    '6G': '6G Development',
    'WiFi': 'WiFi Development',
    'Bluetooth': 'Bluetooth Development',
    'GPS': 'GPS Development',
    'RFID': 'RFID Development',
    'NFC': 'NFC Development',
    'Sensors': 'Sensors Development',
    'Actuators': 'Actuators Development',
    'Microcontrollers': 'Microcontrollers Development',
    'Microprocessors': 'Microprocessors Development',
    'FPGA': 'FPGA Development',
    'ASIC': 'ASIC Development',
    'SoC': 'SoC Development',
    'Embedded Systems': 'Embedded Systems Development',
    'Real-time Systems': 'Real-time Systems Development',
    'Distributed Systems': 'Distributed Systems Development',
    'Parallel Systems': 'Parallel Systems Development',
    'Grid Computing': 'Grid Computing Development',
    'Supercomputing': 'Supercomputing Development',
    'HPC': 'HPC Development',
    'Big Data': 'Big Data Development',
    'Data Engineering': 'Data Engineering Development',
    'Data Pipeline': 'Data Pipeline Development',
    'ETL': 'ETL Development',
    'ELT': 'ELT Development',
    'Data Lake': 'Data Lake Development',
    'Data Warehouse': 'Data Warehouse Development',
    'Data Mart': 'Data Mart Development',
    'Data Governance': 'Data Governance Development',
    'Data Quality': 'Data Quality Development',
    'Data Security': 'Data Security Development',
    'Data Privacy': 'Data Privacy Development',
    'Data Compliance': 'Data Compliance Development',
    'Data Analytics': 'Data Analytics Development',
    'Business Analytics': 'Business Analytics Development',
    'Predictive Analytics': 'Predictive Analytics Development',
    'Prescriptive Analytics': 'Prescriptive Analytics Development',
    'Descriptive Analytics': 'Descriptive Analytics Development',
    'Diagnostic Analytics': 'Diagnostic Analytics Development',
    'Statistical Analysis': 'Statistical Analysis Development',
    'Quantitative Analysis': 'Quantitative Analysis Development',
    'Qualitative Analysis': 'Qualitative Analysis Development',
    'Financial Analysis': 'Financial Analysis Development',
    'Risk Analysis': 'Risk Analysis Development',
    'Market Analysis': 'Market Analysis Development',
    'Competitive Analysis': 'Competitive Analysis Development',
    'SWOT Analysis': 'SWOT Analysis Development',
    'PEST Analysis': 'PEST Analysis Development',
    'Gap Analysis': 'Gap Analysis Development',
    'Root Cause Analysis': 'Root Cause Analysis Development',
    'Trend Analysis': 'Trend Analysis Development',
    'Sentiment Analysis': 'Sentiment Analysis Development',
    'Text Analysis': 'Text Analysis Development',
    'Image Analysis': 'Image Analysis Development',
    'Video Analysis': 'Video Analysis Development',
    'Audio Analysis': 'Audio Analysis Development',
    'Speech Analysis': 'Speech Analysis Development',
    'Voice Analysis': 'Voice Analysis Development',
    'Facial Recognition': 'Facial Recognition Development',
    'Object Detection': 'Object Detection Development',
    'Pattern Recognition': 'Pattern Recognition Development',
    'Anomaly Detection': 'Anomaly Detection Development',
    'Fraud Detection': 'Fraud Detection Development',
    'Threat Detection': 'Threat Detection Development',
    'Intrusion Detection': 'Intrusion Detection Development',
    'Malware Detection': 'Malware Detection Development',
    'Spam Detection': 'Spam Detection Development',
    'Phishing Detection': 'Phishing Detection Development',
    'Network Security': 'Network Security Development',
    'Application Security': 'Application Security Development',
    'Cloud Security': 'Cloud Security Development',
    'Endpoint Security': 'Endpoint Security Development',
    'Mobile Security': 'Mobile Security Development',
    'Web Security': 'Web Security Development',
    'Database Security': 'Database Security Development',
    'API Security': 'API Security Development',
    'Identity Management': 'Identity Management Development',
    'Access Control': 'Access Control Development',
    'Authentication': 'Authentication Development',
    'Authorization': 'Authorization Development',
    'Encryption': 'Encryption Development',
    'Decryption': 'Decryption Development',
    'Cryptography': 'Cryptography Development',
    'Blockchain Security': 'Blockchain Security Development',
    'Cybersecurity': 'Cybersecurity Development',
    'Information Security': 'Information Security Development',
    'IT Security': 'IT Security Development',
    'OT Security': 'OT Security Development',
    'ICS Security': 'ICS Security Development',
    'SCADA Security': 'SCADA Security Development',
    'IoT Security': 'IoT Security Development',
    'Industrial Security': 'Industrial Security Development',
    'Critical Infrastructure': 'Critical Infrastructure Development',
    'Disaster Recovery': 'Disaster Recovery Development',
    'Business Continuity': 'Business Continuity Development',
    'Incident Response': 'Incident Response Development',
    'Forensics': 'Forensics Development',
    'Penetration Testing': 'Penetration Testing Development',
    'Vulnerability Assessment': 'Vulnerability Assessment Development',
    'Security Audit': 'Security Audit Development',
    'Compliance Audit': 'Compliance Audit Development',
    'Risk Assessment': 'Risk Assessment Development',
    'Threat Assessment': 'Threat Assessment Development',
    'Security Assessment': 'Security Assessment Development',
    'Security Testing': 'Security Testing Development',
    'Security Monitoring': 'Security Monitoring Development',
    'Security Operations': 'Security Operations Development',
    'Security Intelligence': 'Security Intelligence Development',
    'Threat Intelligence': 'Threat Intelligence Development',
    'Security Analytics': 'Security Analytics Development',
    'Security Automation': 'Security Automation Development',
    'Security Orchestration': 'Security Orchestration Development',
    'Security Response': 'Security Response Development',
    'Security Management': 'Security Management Development',
    'Security Governance': 'Security Governance Development',
    'Security Strategy': 'Security Strategy Development',
    'Security Architecture': 'Security Architecture Development',
    'Security Design': 'Security Design Development',
    'Security Implementation': 'Security Implementation Development',
    'Security Deployment': 'Security Deployment Development',
    'Security Configuration': 'Security Configuration Development',
    'Security Maintenance': 'Security Maintenance Development',
    'Security Support': 'Security Support Development',
    'Security Troubleshooting': 'Security Troubleshooting Development',
    'Security Documentation': 'Security Documentation Development',
    'Security Training': 'Security Training Development',
    'Security Awareness': 'Security Awareness Development',
    'Security Compliance': 'Security Compliance Development',
    'Security Policies': 'Security Policies Development',
    'Security Procedures': 'Security Procedures Development',
    'Security Standards': 'Security Standards Development',
    'Security Best Practices': 'Security Best Practices Development',
    'Security Guidelines': 'Security Guidelines Development',
    'Security Frameworks': 'Security Frameworks Development',
    'Security Methodologies': 'Security Methodologies Development',
    'Security Tools': 'Security Tools Development',
    'Security Technologies': 'Security Technologies Development',
    'Security Platforms': 'Security Platforms Development',
    'Security Systems': 'Security Systems Development',
    'Security Applications': 'Security Applications Development',
    'Security Software': 'Security Software Development',
    'Security Hardware': 'Security Hardware Development',
    'Security Networking': 'Security Networking Development',
    'Security Cloud': 'Security Cloud Development',
    'Security Edge': 'Security Edge Development',
    'Security IoT': 'Security IoT Development',
    'Security Mobile': 'Security Mobile Development',
    'Security Web': 'Security Web Development',
    'Security Desktop': 'Security Desktop Development',
    'Security Embedded': 'Security Embedded Development',
    'Security Gaming': 'Security Gaming Development',
    'Security AR': 'Security AR Development',
    'Security VR': 'Security VR Development',
    'Security MR': 'Security MR Development',
    'Security Blockchain': 'Security Blockchain Development',
    'Security Cryptocurrency': 'Security Cryptocurrency Development',
    'Security NFT': 'Security NFT Development',
    'Security Metaverse': 'Security Metaverse Development',
    'Security Robotics': 'Security Robotics Development',
    'Security Drones': 'Security Drones Development',
    'Security 3D Printing': 'Security 3D Printing Development',
    'Security Biometrics': 'Security Biometrics Development',
    'Security Quantum': 'Security Quantum Development',
    'Security 5G': 'Security 5G Development',
    'Security 6G': 'Security 6G Development',
    'Security WiFi': 'Security WiFi Development',
    'Security Bluetooth': 'Security Bluetooth Development',
    'Security GPS': 'Security GPS Development',
    'Security RFID': 'Security RFID Development',
    'Security NFC': 'Security NFC Development',
    'Security Sensors': 'Security Sensors Development',
    'Security Actuators': 'Security Actuators Development',
    'Security Microcontrollers': 'Security Microcontrollers Development',
    'Security Microprocessors': 'Security Microprocessors Development',
    'Security FPGA': 'Security FPGA Development',
    'Security ASIC': 'Security ASIC Development',
    'Security SoC': 'Security SoC Development',
    'Security Embedded Systems': 'Security Embedded Systems Development',
    'Security Real-time Systems': 'Security Real-time Systems Development',
    'Security Distributed Systems': 'Security Distributed Systems Development',
    'Security Parallel Systems': 'Security Parallel Systems Development',
    'Security Grid Computing': 'Security Grid Computing Development',
    'Security Supercomputing': 'Security Supercomputing Development',
    'Security HPC': 'Security HPC Development',
    'Security Big Data': 'Security Big Data Development',
    'Security Data Engineering': 'Security Data Engineering Development',
    'Security Data Pipeline': 'Security Data Pipeline Development',
    'Security ETL': 'Security ETL Development',
    'Security ELT': 'Security ELT Development',
    'Security Data Lake': 'Security Data Lake Development',
    'Security Data Warehouse': 'Security Data Warehouse Development',
    'Security Data Mart': 'Security Data Mart Development',
    'Security Data Governance': 'Security Data Governance Development',
    'Security Data Quality': 'Security Data Quality Development',
    'Security Data Security': 'Security Data Security Development',
    'Security Data Privacy': 'Security Data Privacy Development',
    'Security Data Compliance': 'Security Data Compliance Development',
    'Security Data Analytics': 'Security Data Analytics Development',
    'Security Business Analytics': 'Security Business Analytics Development',
    'Security Predictive Analytics': 'Security Predictive Analytics Development',
    'Security Prescriptive Analytics': 'Security Prescriptive Analytics Development',
    'Security Descriptive Analytics': 'Security Descriptive Analytics Development',
    'Security Diagnostic Analytics': 'Security Diagnostic Analytics Development',
    'Security Statistical Analysis': 'Security Statistical Analysis Development',
    'Security Quantitative Analysis': 'Security Quantitative Analysis Development',
    'Security Qualitative Analysis': 'Security Qualitative Analysis Development',
    'Security Financial Analysis': 'Security Financial Analysis Development',
    'Security Risk Analysis': 'Security Risk Analysis Development',
    'Security Market Analysis': 'Security Market Analysis Development',
    'Security Competitive Analysis': 'Security Competitive Analysis Development',
    'Security SWOT Analysis': 'Security SWOT Analysis Development',
    'Security PEST Analysis': 'Security PEST Analysis Development',
    'Security Gap Analysis': 'Security Gap Analysis Development',
    'Security Root Cause Analysis': 'Security Root Cause Analysis Development',
    'Security Trend Analysis': 'Security Trend Analysis Development',
    'Security Sentiment Analysis': 'Security Sentiment Analysis Development',
    'Security Text Analysis': 'Security Text Analysis Development',
    'Security Image Analysis': 'Security Image Analysis Development',
    'Security Video Analysis': 'Security Video Analysis Development',
    'Security Audio Analysis': 'Security Audio Analysis Development',
    'Security Speech Analysis': 'Security Speech Analysis Development',
    'Security Voice Analysis': 'Security Voice Analysis Development',
    'Security Facial Recognition': 'Security Facial Recognition Development',
    'Security Object Detection': 'Security Object Detection Development',
    'Security Pattern Recognition': 'Security Pattern Recognition Development',
    'Security Anomaly Detection': 'Security Anomaly Detection Development',
    'Security Fraud Detection': 'Security Fraud Detection Development',
    'Security Threat Detection': 'Security Threat Detection Development',
    'Security Intrusion Detection': 'Security Intrusion Detection Development',
    'Security Malware Detection': 'Security Malware Detection Development',
    'Security Spam Detection': 'Security Spam Detection Development',
    'Security Phishing Detection': 'Security Phishing Detection Development',
  };
}

class ProfileScreen extends StatefulWidget {
  final bool isRecruiter;

  const ProfileScreen({this.isRecruiter = false, super.key});

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  Map<String, dynamic>? _profileData;

  // Controllers for editable fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _companyProfileController =
      TextEditingController();
  final TextEditingController _designationController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _currentCtcController = TextEditingController();
  final TextEditingController _expectedCtcController = TextEditingController();
  final TextEditingController _linkedinUrlController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();

  // Non-editable fields
  String? _mobileNumber;
  String? _email;
  String? _profilePhotoUrl;

  // Dropdown and multi-select fields for seekers
  String? _selectedSpecialization;
  String? _selectedEducation;
  String? _selectedCity;
  List<String> _selectedSkills = [];
  List<String> _allSkills = [];
  bool _skillsLoading = false;
  final TextEditingController _skillsSearchController = TextEditingController();
  final FocusNode _skillsSearchFocusNode = FocusNode();

  // Track if profile has been updated
  bool _isProfileUpdated = false;
  bool _isUploadingProfilePhoto = false;

  // Map old skills to new skills.json format for backward compatibility
  List<String> _mapOldSkillsToNewFormat(List<String> oldSkills) {
    final mapping = _getOldToNewSkillsMapping();
    final mappedSkills = <String>[];
    
    for (final skill in oldSkills) {
      final trimmedSkill = skill.trim();
      if (trimmedSkill.isEmpty) continue;
      
      // Check if skill already matches new format (contains "Development", "Engineering", etc.)
      if (trimmedSkill.contains('Development') || 
          trimmedSkill.contains('Engineering') || 
          trimmedSkill.contains('Implementation') ||
          trimmedSkill.contains('Integration') ||
          trimmedSkill.contains('Optimization') ||
          trimmedSkill.contains('Automation') ||
          trimmedSkill.contains('Administration') ||
          trimmedSkill.contains('Management') ||
          trimmedSkill.contains('Analysis') ||
          trimmedSkill.contains('Strategy') ||
          trimmedSkill.contains('Consulting') ||
          trimmedSkill.contains('Operations') ||
          trimmedSkill.contains('Support') ||
          trimmedSkill.contains('Design') ||
          trimmedSkill.contains('Architecture') ||
          trimmedSkill.contains('Deployment') ||
          trimmedSkill.contains('Monitoring') ||
          trimmedSkill.contains('Troubleshooting') ||
          trimmedSkill.contains('Security') ||
          trimmedSkill.contains('Testing') ||
          trimmedSkill.contains('Reporting') ||
          trimmedSkill.contains('Planning') ||
          trimmedSkill.contains('Configuration') ||
          trimmedSkill.contains('Migration') ||
          trimmedSkill.contains('Maintenance') ||
          trimmedSkill.contains('Training')) {
        // Skill is already in new format
        mappedSkills.add(trimmedSkill);
      } else {
        // Try to map old skill to new format
        final mappedSkill = mapping[trimmedSkill];
        if (mappedSkill != null) {
          mappedSkills.add(mappedSkill);
        } else {
          // If no mapping found, try to find a skill in _allSkills that contains the old skill name
          if (_allSkills.isNotEmpty) {
            final matchingSkill = _allSkills.firstWhere(
              (newSkill) => newSkill.toLowerCase().contains(trimmedSkill.toLowerCase()),
              orElse: () => '${trimmedSkill} Development', // Fallback: add "Development" suffix
            );
            mappedSkills.add(matchingSkill);
          } else {
            // Fallback when _allSkills is not yet loaded
            mappedSkills.add('${trimmedSkill} Development');
          }
        }
      }
    }
    
    // Remove duplicates while preserving order
    final seen = <String>{};
    return mappedSkills.where((skill) => seen.add(skill)).toList();
  }

  final List<String> experienceOptions = [
    'Fresher',
    '1-2 years',
    '2-4 years',
    '4-6 years',
    '6-8 years',
    '8-10 years',
    '10-12 years',
    '12+ years',
  ];

  List<String> get specializationOptions => _authService.specializationOptions;

  final List<String> educationOptions = [
    'Secondary (Class 10)',
    'Higher Secondary (Class 12)',
    'Diploma/Certificate',
    'Undergraduate (Bachelor\'s Degree)',
    'Postgraduate (Master\'s Degree)',
  ];

  final List<String> cityOptions = [
    'Mumbai',
    'Delhi',
    'Bangalore',
    'Hyderabad',
    'Ahmedabad',
    'Chennai',
    'Kolkata',
    'Surat',
    'Pune',
    'Jaipur',
    'Lucknow',
    'Kanpur',
    'Nagpur',
    'Indore',
    'Thane',
    'Bhopal',
    'Visakhapatnam',
    'Pimpri-Chinchwad',
    'Patna',
    'Vadodara',
    'Ghaziabad',
    'Ludhiana',
    'Agra',
    'Nashik',
    'Faridabad',
    'Meerut',
    'Rajkot',
    'Kalyan-Dombivali',
    'Vasai-Virar',
    'Varanasi',
    'Srinagar',
    'Aurangabad',
    'Dhanbad',
    'Amritsar',
    'Navi Mumbai',
    'Allahabad',
    'Ranchi',
    'Howrah',
    'Coimbatore',
    'Jabalpur',
    'Gwalior',
    'Vijayawada',
    'Jodhpur',
    'Madurai',
    'Raipur',
    'Kota',
    'Guwahati',
    'Chandigarh',
    'Solapur',
    'Hubballi-Dharwad',
    'Bareilly',
    'Moradabad',
    'Mysore',
    'Gurgaon',
    'Aligarh',
    'Jalandhar',
    'Tiruchirappalli',
    'Bhubaneswar',
    'Salem',
    'Warangal',
    'Guntur',
    'Bhiwandi',
    'Saharanpur',
    'Gorakhpur',
    'Bikaner',
    'Amravati',
    'Noida',
    'Jamshedpur',
    'Bhilai',
    'Cuttack',
    'Firozabad',
    'Kochi',
    'Nellore',
    'Bhavnagar',
    'Dehradun',
    'Durgapur',
    'Asansol',
    'Rourkela',
    'Nanded',
    'Kolhapur',
    'Ajmer',
    'Akola',
    'Gulbarga',
    'Jamnagar',
    'Ujjain',
    'Loni',
    'Siliguri',
    'Jhansi',
    'Ulhasnagar',
    'Jammu',
    'Sangli-Miraj & Kupwad',
    'Mangalore',
    'Erode',
    'Belgaum',
    'Ambattur',
    'Tirunelveli',
    'Malegaon',
    'Gaya',
    'Tiruppur',
    'Davanagere',
    'Kozhikode',
    'Akbarpur',
    'Kurnool',
    'Rajpur Sonarpur',
    'Bokaro',
    'South Dumdum',
    'Bellary',
    'Patiala',
    'Gopalpur',
    'Agartala',
    'Bhagalpur',
    'Muzaffarnagar',
    'Bhatpara',
    'Panihati',
    'Latur',
    'Dhule',
    'Tirupati',
    'Rohtak',
    'Korba',
    'Bhilwara',
    'Berhampur',
    'Muzaffarpur',
    'Ahmednagar',
    'Mathura',
    'Kollam',
    'Avadi',
    'Kadapa',
    'Kamarhati',
    'Sambalpur',
    'Bilaspur',
    'Shahjahanpur',
    'Satara',
    'Bijapur',
    'Rampur',
    'Shore',
    'Nagarcoil',
    'Alwar',
    'Bardhaman',
    'Kulti',
    'Kakinada',
    'Nizamabad',
    'Parbhani',
    'Tumkur',
    'Khammam',
    'Ozhukarai',
    'Bihar Sharif',
    'Panipat',
    'Darbhanga',
    'Bally',
    'Aizawl',
    'Dewas',
    'Ichalkaranji',
    'Karnal',
    'Bathinda',
    'Jalna',
    'Eluru',
    'Kirari Suleman Nagar',
    'Barasat',
    'Purnia',
    'Satna',
    'Mau',
    'Sonipat',
    'Farrukhabad',
    'Sagar',
    'Rourkela',
    'Durg',
    'Imphal',
    'Ratlam',
    'Hapur',
    'Arrah',
    'Karimnagar',
    'Anantapur',
    'Etawah',
    'Ambarnath',
    'North Dumdum',
    'Bharatpur',
    'Begusarai',
    'New Delhi',
    'Gandhidham',
    'Baranagar',
    'Tiruvottiyur',
    'Pondicherry',
    'Sikar',
    'Thoothukudi',
    'Rewa',
    'Mirzapur',
    'Raichur',
    'Pali',
    'Ramagundam',
    'Silchar',
    'Haridwar',
    'Vijayanagaram',
    'Tenali',
    'Nagercoil',
    'Sri Ganganagar',
    'Karawal Nagar',
    'Mango',
    'Thanjavur',
    'Bulandshahr',
    'Uluberia',
    'Katni',
    'Sambhal',
    'Singrauli',
    'Nadiad',
    'Secunderabad',
    'Naihati',
    'Yamunanagar',
    'Bidhan Nagar',
    'Pallavaram',
    'Bidar',
    'Munger',
    'Panchkula',
    'Burhanpur',
    'Raurkela Industrial Township',
    'Kharagpur',
    'Dindigul',
    'Gandhinagar',
    'Hospet',
    'Nangloi Jat',
    'Malda',
    'Ongole',
    'Deoghar',
    'Chapra',
    'Haldia',
    'Khandwa',
    'Nandyal',
    'Morena',
    'Amroha',
    'Anand',
    'Bhind',
    'Bhalswa Jahangir Pur',
    'Madhyamgram',
    'Bhiwani',
    'Berhampore',
    'Ambala',
    'Morbi',
    'Fatehpur',
    'Raebareli',
    'Khora',
    'Chittoor',
    'Bhusawal',
    'Orai',
    'Bahraich',
    'Phusro',
    'Vellore',
    'Mehsana',
    'Raiganj',
    'Sirsa',
    'Danapur',
    'Serampore',
    'Sultan Pur Majra',
    'Guna',
    'Jaunpur',
    'Panvel',
    'Shivpuri',
    'Surendranagar Dudhrej',
    'Unnao',
    'Chinsurah',
    'Alappuzha',
    'Kottayam',
    'Machilipatnam',
    'Shimla',
    'Adoni',
    'Udupi',
    'Katihar',
    'Proddatur',
    'Mahbubnagar',
    'Saharsa',
    'Dibrugarh',
    'Jorhat',
    'Hazaribagh',
    'Hindupur',
    'Nagaon',
    'Sasaram',
    'Hajipur',
    'Giridih',
    'Bhimavaram',
    'Kumbakonam',
    'Rajahmundry',
    'Kottayam',
    'Visakhapatnam',
    'Other',
  ];

  Map<String, List<String>> get skillsBySpecialization =>
      _authService.skillsBySpecialization;

  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _initSkills();
    _loadUserData();
    _currentCtcController.addListener(_formatCtcOnChange);
    _expectedCtcController.addListener(_formatCtcOnChange);
  }

  Future<void> _initSkills() async {
    if (_skillsLoading || _allSkills.isNotEmpty) return;
    _skillsLoading = true;
    try {
      final skills = await _loadSkillsFromAsset();
      if (!mounted) return;
      setState(() {
        _allSkills = skills;
      });
    } catch (e, st) {
      dev.log(
        'Failed to load skills.json: $e',
        name: 'ProfileScreen',
        stackTrace: st,
      );
    } finally {
      _skillsLoading = false;
    }
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => errorMessage = 'No user logged in');
      }
      return;
    }

    try {
      setState(() => isLoading = true);
      final data = await _authService.fetchProfileData(
        isRecruiter: widget.isRecruiter,
      );
      if (mounted) {
        if (data != null) {
          dev.log('Firestore data: $data', name: 'ProfileScreen');
          setState(() {
            _profileData = Map<String, dynamic>.from(data);
            _nameController.text = data['name']?.toString().trim() ?? '';
            _mobileNumber =
                data['mobileNumber']?.toString().trim() ??
                data['mobile']?.toString().trim() ??
                data['Mobile Number']?.toString().trim();
            if (_mobileNumber == null || _mobileNumber!.isEmpty) {
              dev.log(
                'Warning: Mobile number not found in Firestore data for UID: ${user.uid}',
                name: 'ProfileScreen',
              );
            }
            _email = user.email?.trim() ?? '';
            _profilePhotoUrl = data['photoUrl']?.toString().trim();
            if (_profilePhotoUrl != null && _profilePhotoUrl!.isEmpty) {
              _profilePhotoUrl = null;
            }
            _linkedinUrlController.text =
                data['linkedinUrl']?.toString().trim() ?? '';
            if (widget.isRecruiter) {
              _companyNameController.text =
                  data['companyName']?.toString().trim() ?? '';
              _companyProfileController.text =
                  data['companyProfile']?.toString().trim() ?? '';
              _designationController.text =
                  data['designation']?.toString().trim() ?? '';
            } else {
              _experienceController.text =
                  data['experience']?.toString().trim() ?? '';
              final education = data['education']?.toString().trim();
              _selectedEducation =
                  education != null && educationOptions.contains(education)
                  ? education
                  : education != null && education.isNotEmpty
                  ? 'Other'
                  : null;
              _selectedSkills = _mapOldSkillsToNewFormat(
                  (data['skills'] as List<dynamic>?)?.cast<String>() ?? []);
              _selectedSpecialization =
                  specializationOptions.contains(data['specialization'])
                  ? data['specialization']
                  : 'Others';
              _currentCtcController.text = _formatCtc(
                data['currentCtc']?.toString().trim() ?? '',
              );
              _expectedCtcController.text = _formatCtc(
                data['expectedCtc']?.toString().trim() ?? '',
              );
            }
            final city = data['city']?.toString().trim();
            _selectedCity = city != null && cityOptions.contains(city) ? city : city;
            _cityController.text = city ?? '';
            _isProfileUpdated =
                data['name'] != null &&
                data['name'].toString().trim().isNotEmpty &&
                data['city'] != null &&
                data['city'].toString().trim().isNotEmpty &&
                (widget.isRecruiter
                    ? data['companyName'] != null
                    : data['education'] != null);
          });
        } else {
          setState(() {
            errorMessage = 'Profile not found';
            _profileData = null;
            dev.log(
              'No profile data found for UID: ${user.uid}',
              name: 'ProfileScreen',
            );
          });
        }
      }
    } catch (e) {
      dev.log('Error loading profile: $e', name: 'ProfileScreen', error: e);
      if (mounted) {
        setState(() {
          errorMessage = 'Error loading profile: $e';
          _profileData = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  String _displayValue(dynamic v) {
    if (v == null) return 'N/A';
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? 'N/A' : t;
    }
    if (v is num || v is bool) return v.toString();
    if (v is Timestamp) return v.toDate().toIso8601String();
    return v.toString();
  }

  Widget _buildOnboardingDetailsCard() {
    final data = _profileData;
    if (data == null || data.isEmpty) return const SizedBox.shrink();

    Widget row(String label, dynamic value) {
      final text = _displayValue(value);
      if (text == 'N/A') return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.only(bottom: 8.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 140.w,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.blueGrey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 12.sp, color: Colors.black87),
              ),
            ),
          ],
        ),
      );
    }

    Widget chips(String label, List<dynamic>? values) {
      final list = values
              ?.map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          [];
      if (list.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.only(bottom: 10.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.blueGrey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 6.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: list
                  .map(
                    (t) => Chip(
                      label: Text(t, style: TextStyle(fontSize: 11.sp)),
                      backgroundColor: Colors.teal.shade50,
                      side: BorderSide(color: Colors.teal.shade100),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      );
    }

    final educationDetails = data['educationDetails'];
    final previousExps = data['previousExperiences'];

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 14.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withValues(alpha: 0.08),
            blurRadius: 18.r,
            offset: Offset(0, 8.h),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.only(top: 10.h),
          title: Text(
            'Onboarding Details',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          subtitle: Text(
            'Everything filled during profile setup',
            style: TextStyle(fontSize: 11.sp, color: Colors.blueGrey.shade500),
          ),
          children: [
            _buildSectionHeader(widget.isRecruiter ? 'Recruiter' : 'Seeker'),
            row('Current Status', data['currentStatus']),
            row('Job Title', data['jobTitle']),
            row('Industry', data['industry']),
            row('Current Company', data['currentCompany']),
            row('Employment Type', data['employmentType']),
            row('Total Experience (years)', data['totalExperienceYears']),
            row('Current Job Start', data['currentJobStartDate']),
            row('Current Job End', data['currentJobEndDate']),
            row('Previous Companies', data['previousCompanies']),
            row('Achievements', data['achievements']),
            row('Projects', data['projects']),
            row('Internships', data['internships']),
            row('Soft Skills', data['softSkills']),
            row('GitHub URL', data['githubUrl']),
            row('Portfolio URL', data['portfolioUrl']),
            row('Resume URL', data['resumeUrl']),
            if (widget.isRecruiter) ...[
              row('Company Website', data['companyWebsite']),
              row('Company Industry', data['companyIndustry']),
              row('Company Size', data['companySize']),
            ],
            chips('Skills', (data['skills'] as List?)?.cast<dynamic>()),
            if (educationDetails is Map) ...[
              SizedBox(height: 6.h),
              _buildSectionHeader('Education Details'),
              row(
                '10th - Passing Year',
                (educationDetails['tenth'] as Map?)?['passingYear'],
              ),
              row('10th - Score', (educationDetails['tenth'] as Map?)?['score']),
              row(
                '10th - Score Type',
                (educationDetails['tenth'] as Map?)?['scoreType'],
              ),
              row('After 10th', educationDetails['afterTenth']),
              row(
                '12th - Stream',
                (educationDetails['twelfth'] as Map?)?['stream'],
              ),
              row(
                '12th - Stream Other',
                (educationDetails['twelfth'] as Map?)?['streamOther'],
              ),
              row(
                '12th - Passing Year',
                (educationDetails['twelfth'] as Map?)?['passingYear'],
              ),
              row(
                '12th - Score',
                (educationDetails['twelfth'] as Map?)?['score'],
              ),
              row(
                '12th - Score Type',
                (educationDetails['twelfth'] as Map?)?['scoreType'],
              ),
              row('After 12th', educationDetails['afterTwelfth']),
              row(
                'Diploma - Branch',
                (educationDetails['diploma'] as Map?)?['branch'],
              ),
              row(
                'Diploma - University',
                (educationDetails['diploma'] as Map?)?['university'],
              ),
              row(
                'Diploma - Start Year',
                (educationDetails['diploma'] as Map?)?['startYear'],
              ),
              row(
                'Diploma - End Year',
                (educationDetails['diploma'] as Map?)?['endYear'],
              ),
              row(
                'Diploma - Score',
                (educationDetails['diploma'] as Map?)?['score'],
              ),
              row(
                'Diploma - Score Type',
                (educationDetails['diploma'] as Map?)?['scoreType'],
              ),
              row(
                'Graduation After Diploma',
                educationDetails['graduationAfterDiploma'],
              ),
              row(
                'Graduation - Degree',
                (educationDetails['graduation'] as Map?)?['degree'],
              ),
              row(
                'Graduation - Major',
                (educationDetails['graduation'] as Map?)?['major'],
              ),
              row(
                'Graduation - University',
                (educationDetails['graduation'] as Map?)?['university'],
              ),
              row(
                'Graduation - Start Year',
                (educationDetails['graduation'] as Map?)?['startYear'],
              ),
              row(
                'Graduation - End Year',
                (educationDetails['graduation'] as Map?)?['endYear'],
              ),
              row(
                'Graduation - Score',
                (educationDetails['graduation'] as Map?)?['score'],
              ),
              row(
                'Graduation - Score Type',
                (educationDetails['graduation'] as Map?)?['scoreType'],
              ),
              row(
                'Graduation - Currently Studying',
                (educationDetails['graduation'] as Map?)?['currentlyStudying'],
              ),
              // Post-Graduation details
              if (educationDetails['postGraduation'] is Map) ...[
                SizedBox(height: 6.h),
                _buildSectionHeader('Post-Graduation'),
                row(
                  'Post-Graduation - Degree',
                  (educationDetails['postGraduation'] as Map?)?['degree'],
                ),
                row(
                  'Post-Graduation - Major',
                  (educationDetails['postGraduation'] as Map?)?['major'],
                ),
                row(
                  'Post-Graduation - University',
                  (educationDetails['postGraduation'] as Map?)?['university'],
                ),
                row(
                  'Post-Graduation - Start Year',
                  (educationDetails['postGraduation'] as Map?)?['startYear'],
                ),
                row(
                  'Post-Graduation - End Year',
                  (educationDetails['postGraduation'] as Map?)?['endYear'],
                ),
                row(
                  'Post-Graduation - Currently Studying',
                  (educationDetails['postGraduation'] as Map?)?['currentlyStudying'],
                ),
              ],
            ],
            if (previousExps is List && previousExps.isNotEmpty) ...[
              SizedBox(height: 6.h),
              _buildSectionHeader('Previous Experiences'),
              ...previousExps.take(10).whereType<Map>().map((e) {
                final company = e['companyName'] ?? e['company'] ?? '';
                final title = e['jobTitle'] ?? e['role'] ?? '';
                final from = e['startDate'] ?? e['from'] ?? '';
                final to = e['endDate'] ?? e['to'] ?? '';
                final line =
                    '${_displayValue(company)} • ${_displayValue(title)} • ${_displayValue(from)} - ${_displayValue(to)}';
                return Padding(
                  padding: EdgeInsets.only(bottom: 6.h),
                  child: Text(
                    line,
                    style: TextStyle(fontSize: 12.sp, color: Colors.black87),
                  ),
                );
              }),
              if (previousExps.length > 10)
                Padding(
                  padding: EdgeInsets.only(top: 4.h),
                  child: Text(
                    'Showing first 10 experiences',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.blueGrey.shade500,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadProfilePhoto() async {
    if (_isUploadingProfilePhoto) return;

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
      );

      if (image == null) return;

      if (mounted) {
        setState(() => _isUploadingProfilePhoto = true);
      }

      final photoUrl = await _authService.uploadProfilePhoto(
        file: File(image.path),
        isRecruiter: widget.isRecruiter,
      );

      if (mounted) {
        setState(() {
          _profilePhotoUrl = photoUrl;
          _isUploadingProfilePhoto = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      dev.log(
        'Error uploading profile photo: $e',
        name: 'ProfileScreen',
        error: e,
      );
      if (mounted) {
        setState(() => _isUploadingProfilePhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload profile photo: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatCtc(String value) {
    value = value.replaceAll(' LPA (INR)', '').trim();
    double? number = double.tryParse(value);
    if (number == null) {
      return '0.0 LPA (INR)';
    }
    return '${number.toStringAsFixed(1)} LPA (INR)';
  }

  void _formatCtcOnChange() {
    final controller =
        _currentCtcController ==
            FocusScope.of(context).focusedChild?.context?.widget
        ? _currentCtcController
        : _expectedCtcController;

    final value = controller.text;
    final formattedValue = _formatCtc(value);
    if (controller.text != formattedValue) {
      final selection = controller.selection;
      controller.text = formattedValue;
      controller.selection = selection.extent.offset == value.length
          ? TextSelection.fromPosition(
              TextPosition(offset: formattedValue.length),
            )
          : TextSelection.collapsed(offset: selection.extent.offset);
    }
  }

  Map<String, dynamic> _generateResumeData() {
    if (widget.isRecruiter) return {};
    return {
      'name': _nameController.text.trim(),
      'email': _email ?? '',
      'mobileNumber': _mobileNumber ?? '',
      'city': _selectedCity ?? '',
      'skills': _selectedSkills,
      'education': _selectedEducation ?? 'Other',
      'experience': _experienceController.text.trim(),
      'specialization': _selectedSpecialization ?? 'Others',
      'currentCtc': _currentCtcController.text
          .replaceAll(' LPA (INR)', '')
          .trim(),
      'expectedCtc': _expectedCtcController.text
          .replaceAll(' LPA (INR)', '')
          .trim(),
      'linkedinUrl': _linkedinUrlController.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> _updateProfile(
    Map<String, dynamic> profileData,
    Function setDialogState,
  ) async {
    final user = _auth.currentUser;
    if (user == null) {
      setDialogState(() => errorMessage = 'No user logged in');
      return;
    }

    if (profileData['name'].trim().isEmpty) {
      setDialogState(() => errorMessage = 'Name is required');
      return;
    }
    if (_mobileNumber == null || _mobileNumber!.trim().isEmpty) {
      setDialogState(
        () => errorMessage =
            'Mobile number is required. Please ensure it is set in your profile.',
      );
      return;
    }
    if (widget.isRecruiter) {
      if (profileData['companyName'].trim().isEmpty) {
        setDialogState(() => errorMessage = 'Company Name is required');
        return;
      }
    } else {
      if (profileData['skills'].isEmpty) {
        setDialogState(() => errorMessage = 'At least one skill is required');
        return;
      }
      if (profileData['education'] == null) {
        setDialogState(() => errorMessage = 'Education is required');
        return;
      }
      if (profileData['experience'].trim().isEmpty) {
        setDialogState(() => errorMessage = 'Experience is required');
        return;
      }
      if (profileData['specialization'] == null) {
        setDialogState(() => errorMessage = 'Specialization is required');
        return;
      }
    }

    // Validate LinkedIn URL if provided
    if (profileData['linkedinUrl'] != null &&
        profileData['linkedinUrl'].toString().trim().isNotEmpty) {
      final linkedinValidationError = _validateLinkedInUrl(
        profileData['linkedinUrl'],
      );
      if (linkedinValidationError != null) {
        setDialogState(() => errorMessage = linkedinValidationError);
        return;
      }
    }

    setDialogState(() => isLoading = true);
    try {
      dev.log(
        'Updating profile with data: $profileData',
        name: 'ProfileScreen',
      );
      await _authService.storeSignupData(
        isRecruiter: widget.isRecruiter,
        data: profileData,
      );

      if (mounted) {
        // Refresh full profile data so all sections, including onboarding
        // and preferences, reflect latest values.
        await _loadUserData();
        setState(() {
          _isProfileUpdated = true;
          errorMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully'),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Don't pop here - let the dialog close itself from the save button
      }
    } catch (e) {
      dev.log('Error updating profile: $e', name: 'ProfileScreen', error: e);
      if (mounted) {
        setDialogState(() => errorMessage = 'Error updating profile: $e');
      }
    } finally {
      if (mounted) {
        setDialogState(() => isLoading = false);
      }
    }
  }

  void _showUpdateProfileDialog({String section = 'all'}) {
    showDialog(
      context: context,
      builder: (context) => ProfileDialog(
        isRecruiter: widget.isRecruiter,
        initialData: {
          'name': _nameController.text,
          'companyName': _companyNameController.text,
          'companyProfile': _companyProfileController.text,
          'designation': _designationController.text,
          'experience': _experienceController.text,
          'currentCtc': _currentCtcController.text,
          'expectedCtc': _expectedCtcController.text,
          'specialization': _selectedSpecialization,
          'education': _selectedEducation,
          'city': _selectedCity,
          'skills': List<String>.from(_selectedSkills),
          'linkedinUrl': _linkedinUrlController.text,
          // pass full profile data so dialog can show
          // onboarding / additional sections read-only
          'profileData': _profileData,
        },
        experienceOptions: experienceOptions,
        specializationOptions: specializationOptions,
        educationOptions: educationOptions,
        cityOptions: cityOptions,
        skillsBySpecialization: skillsBySpecialization,
        isProfileUpdated: _isProfileUpdated,
        mobileNumber: _mobileNumber,
        onUpdate: _updateProfile,
        section: section,
      ),
    );
  }

  double _calculateProfileCompletion() {
    if (widget.isRecruiter) {
      // For recruiters, calculate based on their fields
      int filled = 0;
      int total = 4; // name, companyName, companyProfile, designation
      if (_nameController.text.trim().isNotEmpty) filled++;
      if (_companyNameController.text.trim().isNotEmpty) filled++;
      if (_companyProfileController.text.trim().isNotEmpty) filled++;
      if (_designationController.text.trim().isNotEmpty) filled++;
      return (filled / total) * 100;
    } else {
      // For seekers
      int filled = 0;
      int total = 8; // name, city, specialization, education, experience, skills, currentCtc, expectedCtc
      if (_nameController.text.trim().isNotEmpty) filled++;
      if (_selectedCity != null && _selectedCity!.trim().isNotEmpty) filled++;
      if (_selectedSpecialization != null && _selectedSpecialization!.trim().isNotEmpty) filled++;
      if (_selectedEducation != null && _selectedEducation!.trim().isNotEmpty) filled++;
      if (_experienceController.text.trim().isNotEmpty) filled++;
      if (_selectedSkills.isNotEmpty) filled++;
      if (_currentCtcController.text.trim().isNotEmpty && _currentCtcController.text.trim() != '0') filled++;
      if (_expectedCtcController.text.trim().isNotEmpty && _expectedCtcController.text.trim() != '0') filled++;
      return (filled / total) * 100;
    }
  }

  InputDecoration _fieldDecoration(
    String label, {
    IconData? icon,
    bool enabled = true,
  }) {
    final borderColor = enabled
        ? Colors.blueGrey.shade200
        : Colors.blueGrey.shade100;
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: Colors.blueGrey.shade600,
        fontSize: 12.sp,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: icon == null
          ? null
          : Icon(icon, size: 18.sp, color: Colors.blueGrey.shade500),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: borderColor),
        borderRadius: BorderRadius.circular(14.r),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.teal.shade500, width: 1.8.w),
        borderRadius: BorderRadius.circular(14.r),
      ),
      disabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.blueGrey.shade100),
        borderRadius: BorderRadius.circular(14.r),
      ),
      filled: true,
      fillColor: enabled ? Colors.white : Colors.blueGrey.shade50,
      contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
    );
  }

  IconData _iconForLabel(String label) {
    switch (label.toLowerCase()) {
      case 'email':
        return Icons.mail_outline;
      case 'mobile number':
        return Icons.phone_outlined;
      case 'name':
        return Icons.person_outline;
      case 'company name':
        return Icons.apartment_outlined;
      case 'company profile':
        return Icons.business_center_outlined;
      case 'designation':
        return Icons.badge_outlined;
      case 'specialization':
        return Icons.auto_awesome_mosaic_outlined;
      case 'education':
        return Icons.school_outlined;
      case 'experience':
        return Icons.timeline_outlined;
      case 'current ctc':
      case 'expected ctc':
        return Icons.currency_rupee_outlined;
      case 'linkedin url':
        return Icons.link_outlined;
      case 'city':
        return Icons.location_city_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Container(
            width: 4.w,
            height: 18.h,
            decoration: BoxDecoration(
              color: Colors.teal.shade500,
              borderRadius: BorderRadius.circular(20.r),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            title,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
              color: Colors.blueGrey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    final display = (value ?? '').toString().trim();
    final isEmpty = display.isEmpty ||
        display.toLowerCase() == 'null' ||
        display.toLowerCase() == 'not provided';
    // Only show rows that have a value; hide "Not provided" fields
    if (isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.blueGrey.shade700,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
          SizedBox(height: 4.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: 10.w,
              vertical: 8.h,
            ),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(
                color: Colors.grey.shade300,
                width: 0.8,
              ),
            ),
            child: Text(
              display,
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Generic card layout used for each profile section.
  Widget _buildProfileSectionCard({
    required String title,
    required List<Widget> children,
    String section = 'all',
  }) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: 14.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withValues(alpha: 0.08),
            blurRadius: 18.r,
            offset: Offset(0, 8.h),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.blueGrey.shade800,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 18.sp,
                    color: Colors.teal.shade700,
                  ),
                  tooltip: 'Edit $title',
                  onPressed: () => _showUpdateProfileDialog(section: section),
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          ...children,
        ],
      ),
    );
  }

  Widget _buildBasicInformationCard() {
    final data = _profileData ?? {};
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : data['name']?.toString();
    final city = _selectedCity ??
        (_cityController.text.trim().isNotEmpty
            ? _cityController.text.trim()
            : data['city']?.toString());

    return _buildProfileSectionCard(
      title: 'Basic Information',
      section: 'basic',
      children: [
        _buildInfoRow('Name', name),
        _buildInfoRow('Email', _email),
        _buildInfoRow('Mobile Number', _mobileNumber),
        _buildInfoRow('City', city),
        _buildInfoRow('Current Status', data['currentStatus']?.toString()),
        _buildInfoRow('Job Title', data['jobTitle']?.toString()),
        _buildInfoRow('Current Company', data['currentCompany']?.toString()),
        _buildInfoRow('Employment Type', data['employmentType']?.toString()),
        _buildInfoRow(
          'Total Experience (years)',
          data['totalExperienceYears']?.toString(),
        ),
      ],
    );
  }

  Widget _buildEducationalDetailsCard() {
    final data = _profileData;
    final educationDetails = data?['educationDetails'] as Map?;

    final widgets = <Widget>[];

    if (educationDetails is Map) {
      final tenth = educationDetails['tenth'] as Map?;
      final twelfth = educationDetails['twelfth'] as Map?;
      final diploma = educationDetails['diploma'] as Map?;
      final graduation = educationDetails['graduation'] as Map?;
      final postGraduation = educationDetails['postGraduation'] as Map?;

      widgets.addAll([
        _buildInfoRow('After 10th', educationDetails['afterTenth']?.toString()),
        _buildInfoRow(
          '10th - Passing Year',
          tenth?['passingYear']?.toString(),
        ),
        _buildInfoRow('10th - Score', tenth?['score']?.toString()),
        _buildInfoRow('10th - Score Type', tenth?['scoreType']?.toString()),
        _buildInfoRow('After 12th', educationDetails['afterTwelfth']?.toString()),
        _buildInfoRow('12th - Stream', twelfth?['stream']?.toString()),
        _buildInfoRow('12th - Stream Other', twelfth?['streamOther']?.toString()),
        _buildInfoRow(
          '12th - Passing Year',
          twelfth?['passingYear']?.toString(),
        ),
        _buildInfoRow('12th - Score', twelfth?['score']?.toString()),
        _buildInfoRow('12th - Score Type', twelfth?['scoreType']?.toString()),
        _buildInfoRow('Diploma - Branch', diploma?['branch']?.toString()),
        _buildInfoRow('Diploma - University', diploma?['university']?.toString()),
        _buildInfoRow('Diploma - Start Year', diploma?['startYear']?.toString()),
        _buildInfoRow('Diploma - End Year', diploma?['endYear']?.toString()),
        _buildInfoRow('Diploma - Score', diploma?['score']?.toString()),
        _buildInfoRow('Diploma - Score Type', diploma?['scoreType']?.toString()),
        _buildInfoRow(
          'Graduation After Diploma',
          educationDetails['graduationAfterDiploma']?.toString(),
        ),
        _buildInfoRow('Graduation - Degree', graduation?['degree']?.toString()),
        _buildInfoRow('Graduation - Major', graduation?['major']?.toString()),
        _buildInfoRow(
          'Graduation - University',
          graduation?['university']?.toString(),
        ),
        _buildInfoRow(
          'Graduation - Start Year',
          graduation?['startYear']?.toString(),
        ),
        _buildInfoRow(
          'Graduation - End Year',
          graduation?['endYear']?.toString(),
        ),
        _buildInfoRow('Graduation - Score', graduation?['score']?.toString()),
        _buildInfoRow(
          'Graduation - Score Type',
          graduation?['scoreType']?.toString(),
        ),
        _buildInfoRow(
          'Graduation - Currently Studying',
          graduation?['currentlyStudying']?.toString(),
        ),
        // Post-Graduation details
        if (postGraduation != null) ...[
          _buildInfoRow('Post-Graduation - Degree', postGraduation['degree']?.toString()),
          _buildInfoRow('Post-Graduation - Major', postGraduation['major']?.toString()),
          _buildInfoRow('Post-Graduation - University', postGraduation['university']?.toString()),
          _buildInfoRow('Post-Graduation - Start Year', postGraduation['startYear']?.toString()),
          _buildInfoRow('Post-Graduation - End Year', postGraduation['endYear']?.toString()),
          _buildInfoRow('Post-Graduation - Currently Studying', postGraduation['currentlyStudying']?.toString()),
        ],
      ]);
    }

    if (widgets.isEmpty) {
      widgets.add(
        Text(
          'No educational details added yet.',
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.blueGrey.shade500,
          ),
        ),
      );
    }

    return _buildProfileSectionCard(
      title: 'Educational Details',
      children: widgets,
    );
  }

  Widget _buildPreviousExperienceCard() {
    final previousExps = _profileData?['previousExperiences'];

    final widgets = <Widget>[];

    if (previousExps is List && previousExps.isNotEmpty) {
      widgets.addAll(
        previousExps.take(10).whereType<Map>().map((e) {
          final company = e['companyName'] ?? e['company'] ?? '';
          final title = e['jobTitle'] ?? e['role'] ?? '';
          final from = e['startDate'] ?? e['from'] ?? '';
          final to = e['endDate'] ?? e['to'] ?? '';
          final line =
              '${company.toString().trim()} • ${title.toString().trim()} • ${from.toString().trim()} - ${to.toString().trim()}';
          return Padding(
            padding: EdgeInsets.only(bottom: 6.h),
            child: Text(
              line.trim(),
              style: TextStyle(fontSize: 12.sp, color: Colors.black87),
            ),
          );
        }),
      );

      if (previousExps.length > 10) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: 4.h),
            child: Text(
              'Showing first 10 experiences',
              style: TextStyle(
                fontSize: 11.sp,
                color: Colors.blueGrey.shade500,
              ),
            ),
          ),
        );
      }
    } else {
      widgets.add(
        Text(
          'No previous experience added yet.',
          style: TextStyle(
            fontSize: 12.sp,
            color: Colors.blueGrey.shade500,
          ),
        ),
      );
    }

    return _buildProfileSectionCard(
      title: 'Previous Experience',
      children: widgets,
    );
  }

  Widget _buildResumeCard() {
    final data = _profileData ?? {};
    final resumeUrl = data['resumeUrl']?.toString().trim();
    final githubUrl = data['githubUrl']?.toString().trim();
    final portfolioUrl = data['portfolioUrl']?.toString().trim();

    return _buildProfileSectionCard(
      title: 'Resume',
      children: [
        _buildInfoRow('Resume URL', resumeUrl),
        _buildInfoRow('GitHub URL', githubUrl),
        _buildInfoRow('Portfolio URL', portfolioUrl),
        if (!widget.isRecruiter) ...[
          SizedBox(height: 8.h),
          Text(
            'Your resume preview in the top bar is generated from the latest profile details.',
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.blueGrey.shade500,
            ),
          ),
        ],
      ],
    );
  }

  /// Validate LinkedIn URL
  String? _validateLinkedInUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // LinkedIn URL is optional
    }
    final trimmed = value.trim();
    // Check if it's a valid LinkedIn URL pattern (allows query parameters and fragments)
    final linkedinRegex = RegExp(
      r'^(https?://)?(www\.)?linkedin\.com/(in|pub|company)/[a-zA-Z0-9_-]+/?',
      caseSensitive: false,
    );
    if (!linkedinRegex.hasMatch(trimmed)) {
      return 'Please enter a valid LinkedIn profile URL';
    }
    return null;
  }

  Widget _buildTextField(
    String label, {
    bool isPassword = false,
    bool multiline = false,
    TextEditingController? controller,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Container(
        constraints: BoxConstraints(maxWidth: 300.w),
        child: TextFormField(
          controller: controller,
          obscureText: isPassword,
          maxLines: multiline ? 4 : 1,
          maxLength: multiline ? 500 : 100,
          decoration: _fieldDecoration(
            label,
            icon: _iconForLabel(label),
          ).copyWith(counterText: multiline ? null : ''),
          validator: validator,
          onChanged: (value) {
            if (mounted) setState(() => errorMessage = null);
          },
        ),
      ),
    );
  }

  Widget _buildNonEditableField(String label, String? value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Container(
        constraints: BoxConstraints(maxWidth: 300.w),
        child: TextFormField(
          initialValue: value ?? 'N/A',
          enabled: false,
          decoration: _fieldDecoration(
            label,
            enabled: false,
            icon: _iconForLabel(label),
          ),
          style: TextStyle(
            fontSize: 14.sp,
            color: Colors.blueGrey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildSpecializationDropdown({bool enabled = true}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Container(
        constraints: BoxConstraints(maxWidth: 300.w),
        child: DropdownButtonFormField<String>(
          initialValue: _selectedSpecialization,
          decoration: _fieldDecoration(
            'Specialization',
            enabled: enabled,
            icon: _iconForLabel('Specialization'),
          ),
          isExpanded: true,
          menuMaxHeight: 300.h,
          items: specializationOptions.map((String specialization) {
            return DropdownMenuItem<String>(
              value: specialization,
              child: Container(
                constraints: BoxConstraints(maxWidth: 250.w),
                child: Text(
                  specialization,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.black87, fontSize: 12.sp),
                ),
              ),
            );
          }).toList(),
          onChanged: enabled
              ? (value) {
                  if (mounted) {
                    setState(() {
                      _selectedSpecialization = value;
                      errorMessage = null;
                    });
                  }
                }
              : null,
          validator: (value) =>
              value == null ? 'Specialization is required' : null,
        ),
      ),
    );
  }

  Widget _buildEducationDropdown({bool enabled = true}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Container(
        constraints: BoxConstraints(maxWidth: 300.w),
        child: DropdownButtonFormField<String>(
          initialValue: _selectedEducation,
          decoration: _fieldDecoration(
            'Education',
            enabled: enabled,
            icon: _iconForLabel('Education'),
          ),
          isExpanded: true,
          menuMaxHeight: 300.h,
          items: educationOptions.map((String education) {
            return DropdownMenuItem<String>(
              value: education,
              child: Container(
                constraints: BoxConstraints(maxWidth: 250.w),
                child: Text(
                  education,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.black87, fontSize: 12.sp),
                ),
              ),
            );
          }).toList(),
          onChanged: enabled
              ? (value) {
                  if (mounted) {
                    setState(() {
                      _selectedEducation = value;
                      errorMessage = null;
                    });
                  }
                }
              : null,
          validator: (value) => value == null ? 'Education is required' : null,
        ),
      ),
    );
  }

  Widget _buildExperienceDropdown({bool enabled = true}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Container(
        constraints: BoxConstraints(maxWidth: 300.w),
        child: DropdownButtonFormField<String>(
          initialValue:
              _experienceController.text.isNotEmpty &&
                  experienceOptions.contains(_experienceController.text)
              ? _experienceController.text
              : null,
          decoration: _fieldDecoration(
            'Experience',
            enabled: enabled,
            icon: _iconForLabel('Experience'),
          ),
          isExpanded: true,
          menuMaxHeight: 300.h,
          items: experienceOptions.map((String experience) {
            return DropdownMenuItem<String>(
              value: experience,
              child: Container(
                constraints: BoxConstraints(maxWidth: 250.w),
                child: Text(
                  experience,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.black87, fontSize: 12.sp),
                ),
              ),
            );
          }).toList(),
          onChanged: enabled
              ? (value) {
                  if (mounted) {
                    setState(() {
                      _experienceController.text = value ?? '';
                      errorMessage = null;
                    });
                  }
                }
              : null,
          validator: (value) => value == null ? 'Experience is required' : null,
        ),
      ),
    );
  }

  Widget _buildSkillsAutocomplete({bool enabled = true}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Card(
        elevation: 0,
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Container(
          constraints: BoxConstraints(maxWidth: 300.w),
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.cyan.shade50, Colors.teal.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.teal.shade100),
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bolt_outlined,
                    size: 18.sp,
                    color: Colors.teal.shade700,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    'Skills',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.teal.shade800,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
              SizedBox(height: 10.h),
              TypeAheadField<String>(
                controller: _skillsSearchController,
                focusNode: _skillsSearchFocusNode,
                hideOnEmpty: true,
                suggestionsCallback: (search) {
                  final q = search.trim().toLowerCase();
                  if (q.isEmpty) return const <String>[];
                  final selectedLower =
                      _selectedSkills.map((e) => e.toLowerCase()).toSet();
                  
                  // Get all available skills (both from skills.json and old skills)
                  final allAvailableSkills = <String>[];
                  allAvailableSkills.addAll(_allSkills); // New skills from JSON
                  
                  // Add old skills from skillsBySpecialization for backward compatibility
                  final oldSkills = skillsBySpecialization.values
                      .expand((skills) => skills)
                      .where((skill) => !selectedLower.contains(skill.toLowerCase()))
                      .toList();
                  allAvailableSkills.addAll(oldSkills);
                  
                  // Filter skills that match search query and aren't already selected
                  final matchingSkills = allAvailableSkills
                      .where((s) =>
                          !selectedLower.contains(s.toLowerCase()) &&
                          s.toLowerCase().contains(q))
                      .toSet()
                      .toList();
                  
                  // Sort results: prioritize exact matches, then skills starting with query
                  matchingSkills.sort((a, b) {
                    final aLower = a.toLowerCase();
                    final bLower = b.toLowerCase();
                    final qLower = q;
                    
                    // Exact match first
                    if (aLower == qLower) return -1;
                    if (bLower == qLower) return 1;
                    
                    // Skills starting with query next
                    final aStarts = aLower.startsWith(qLower);
                    final bStarts = bLower.startsWith(qLower);
                    if (aStarts && !bStarts) return -1;
                    if (!aStarts && bStarts) return 1;
                    
                    // Alphabetical order
                    return aLower.compareTo(bLower);
                  });
                  
                  return matchingSkills.take(20).toList();
                },
                itemBuilder: (context, suggestion) {
                  return ListTile(
                    dense: true,
                    title: Text(
                      suggestion,
                      style: TextStyle(fontSize: 13.sp),
                    ),
                  );
                },
                onSelected: enabled
                    ? (suggestion) {
                        if (!mounted) return;
                        setState(() {
                          if (!_selectedSkills.contains(suggestion)) {
                            _selectedSkills = [..._selectedSkills, suggestion];
                          }
                          errorMessage = null;
                        });
                        _skillsSearchController.clear();
                        _skillsSearchFocusNode.requestFocus();
                      }
                    : null,
                builder: (context, controller, focusNode) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    enabled: enabled,
                    decoration: _fieldDecoration(
                      'Select Skills',
                      icon: Icons.search,
                    ).copyWith(
                      hintText: 'Type a skill',
                    ),
                  );
                },
              ),
              if (_selectedSkills.isNotEmpty) ...[
                SizedBox(height: 10.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: _selectedSkills.map((s) {
                    return Chip(
                      label: Text(s, overflow: TextOverflow.ellipsis),
                      onDeleted: enabled
                          ? () {
                              setState(() {
                                _selectedSkills =
                                    _selectedSkills.where((x) => x != s).toList();
                              });
                            }
                          : null,
                    );
                  }).toList(),
                ),
              ],
              if (_selectedSkills.isEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 6.h),
                  child: Text(
                    'At least one skill is required',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  


  Widget _buildCityAutocompleteField() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Container(
        constraints: BoxConstraints(maxWidth: 300.w),
        child: Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<String>.empty();
            }
            return cityOptions.where((String option) {
              return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
            });
          },
          onSelected: (String selection) {
            setState(() {
              _selectedCity = selection;
              _cityController.text = selection;
              errorMessage = null;
            });
          },
          fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
            // Initialize the autocomplete controller with our current value
            if (textEditingController.text != _cityController.text) {
              textEditingController.text = _cityController.text;
            }
            // Add listener to update our state when text changes
            textEditingController.addListener(() {
              if (_selectedCity != textEditingController.text) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _selectedCity = textEditingController.text;
                      _cityController.text = textEditingController.text;
                      errorMessage = null;
                    });
                  }
                });
              }
            });
            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              decoration: _fieldDecoration(
                'City',
                icon: _iconForLabel('City'),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'City is required'
                  : null,
              autovalidateMode: AutovalidateMode.onUserInteraction,
            );
          },
          optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                child: Container(
                  constraints: BoxConstraints(maxWidth: 300.w, maxHeight: 200.h),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return ListTile(
                        title: Text(
                          option,
                          style: TextStyle(fontSize: 14.sp),
                        ),
                        onTap: () {
                          onSelected(option);
                        },
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _currentCtcController.removeListener(_formatCtcOnChange);
    _expectedCtcController.removeListener(_formatCtcOnChange);
    _nameController.dispose();
    _companyNameController.dispose();
    _companyProfileController.dispose();
    _designationController.dispose();
    _experienceController.dispose();
    _currentCtcController.dispose();
    _expectedCtcController.dispose();
    _cityController.dispose();
    _linkedinUrlController.dispose();
    _skillsSearchController.dispose();
    _skillsSearchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 690),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(
              widget.isRecruiter ? 'Recruiter Profile' : 'Seeker Profile',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontSize: 18.sp,
              ),
            ),
            centerTitle: true,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.teal.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            elevation: 0,
            actions: [
              if (!widget.isRecruiter) ...[
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.description_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                    padding: EdgeInsets.all(2.w),
                    onPressed: () {
                      dev.log('Opening resume preview', name: 'ProfileScreen');
                      final resumeData = _generateResumeData();
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          title: Container(
                            padding: EdgeInsets.all(12.w),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.blue.shade700,
                                  Colors.blue.shade900,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(16.r),
                              ),
                            ),
                            child: const Text(
                              'Resume Preview',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          content: SingleChildScrollView(
                            child: Container(
                              constraints: BoxConstraints(maxWidth: 300.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Email: ${resumeData['email'] ?? 'N/A'}',
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                  Text(
                                    'Mobile: ${resumeData['mobileNumber'] ?? 'N/A'}',
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                  Text(
                                    'Name: ${resumeData['name'] ?? 'N/A'}',
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                  SizedBox(height: 6.h),
                                  Text(
                                    'Skills:',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: Colors.blue.shade800,
                                    ),
                                  ),
                                  Wrap(
                                    spacing: 6.w,
                                    runSpacing: 4.h,
                                    children:
                                        (resumeData['skills'] as List<dynamic>?)
                                            ?.cast<String>()
                                            .map(
                                              (skill) => Chip(
                                                label: Text(
                                                  skill,
                                                  style: TextStyle(
                                                    fontSize: 12.sp,
                                                  ),
                                                ),
                                                backgroundColor:
                                                    Colors.teal.shade100,
                                                labelStyle: TextStyle(
                                                  color: Colors.teal.shade900,
                                                ),
                                              ),
                                            )
                                            .toList() ??
                                        [
                                          const Chip(
                                            label: Text(
                                              'N/A',
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ),
                                        ],
                                  ),
                                  SizedBox(height: 6.h),
                                  Text(
                                    'Education: ${resumeData['education'] ?? 'N/A'}',
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                  Text(
                                    'Experience: ${resumeData['experience'] ?? 'N/A'}',
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                  Text(
                                    'Specialization: ${resumeData['specialization'] ?? 'N/A'}',
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                  Text(
                                    'Current CTC: ${_formatCtc(resumeData['currentCtc'] ?? '0.0')}',
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                  Text(
                                    'Expected CTC: ${_formatCtc(resumeData['expectedCtc'] ?? '0.0')}',
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                  if (resumeData['linkedinUrl'] != null &&
                                      resumeData['linkedinUrl']
                                          .toString()
                                          .isNotEmpty)
                                    Text(
                                      'LinkedIn: ${resumeData['linkedinUrl']}',
                                      style: TextStyle(fontSize: 14.sp),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text(
                                'Close',
                                style: TextStyle(
                                  color: Colors.teal,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              Container(
                margin: EdgeInsets.only(
                  right: 8.w,
                  left: 4.w,
                  top: 6.h,
                  bottom: 6.h,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  padding: EdgeInsets.all(2.w),
                  onPressed: _showUpdateProfileDialog,
                ),
              ),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade50,
                  Colors.teal.shade50,
                  Colors.white,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.teal.shade500,
                      ),
                      strokeWidth: 3.5.w,
                    ),
                  )
                : errorMessage != null
                ? Center(
                    child: Container(
                      margin: EdgeInsets.all(18.w),
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(color: Colors.red.shade100),
                      ),
                      child: Text(
                        errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 24.h),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade700,
                                Colors.teal.shade500,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.teal.withValues(alpha: 0.25),
                                blurRadius: 16.r,
                                offset: Offset(0, 8.h),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    width: 52.w,
                                    height: 52.w,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      shape: BoxShape.circle,
                                      image: _profilePhotoUrl != null
                                          ? DecorationImage(
                                              image: NetworkImage(
                                                _profilePhotoUrl!,
                                              ),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: _profilePhotoUrl == null
                                        ? Icon(
                                            Icons.person_rounded,
                                            color: Colors.white,
                                            size: 28.sp,
                                          )
                                        : null,
                                  ),
                                  Positioned(
                                    right: -1.w,
                                    bottom: -1.h,
                                    child: GestureDetector(
                                      onTap: _pickAndUploadProfilePhoto,
                                      child: Container(
                                        width: 20.w,
                                        height: 20.w,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Colors.teal.shade400,
                                            width: 1.5.w,
                                          ),
                                        ),
                                        child: _isUploadingProfilePhoto
                                            ? Padding(
                                                padding: EdgeInsets.all(4.w),
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2.w,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                        Color
                                                      >(Colors.teal.shade600),
                                                ),
                                              )
                                            : Icon(
                                                Icons.camera_alt_rounded,
                                                size: 11.sp,
                                                color: Colors.teal.shade700,
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _nameController.text.isNotEmpty
                                          ? _nameController.text
                                          : 'Your Profile',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16.sp,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      _email ?? 'No email',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        fontSize: 12.sp,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10.w,
                                  vertical: 5.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(30.r),
                                ),
                                child: Text(
                                  widget.isRecruiter ? 'Recruiter' : 'Seeker',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11.sp,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!widget.isRecruiter) ...[
                          SizedBox(height: 14.h),
                          Container(
                            padding: EdgeInsets.all(16.w),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.blueGrey.withValues(alpha: 0.08),
                                  blurRadius: 12.r,
                                  offset: Offset(0, 4.h),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    SizedBox(
                                      width: 60.w,
                                      height: 60.w,
                                      child: CircularProgressIndicator(
                                        value: _calculateProfileCompletion() / 100,
                                        strokeWidth: 6.w,
                                        backgroundColor: Colors.grey.shade200,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          _calculateProfileCompletion() >= 80
                                              ? Colors.green.shade500
                                              : _calculateProfileCompletion() >= 50
                                                  ? Colors.orange.shade500
                                                  : Colors.red.shade500,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${_calculateProfileCompletion().toInt()}%',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(width: 16.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Profile Completion',
                                        style: TextStyle(
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      SizedBox(height: 4.h),
                                      Text(
                                        _calculateProfileCompletion() >= 80
                                            ? 'Great! Your profile is almost complete.'
                                            : _calculateProfileCompletion() >= 50
                                                ? 'Good progress! Keep filling in your details.'
                                                : 'Complete your profile to get better job matches.',
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        SizedBox(height: 14.h),
                        _buildBasicInformationCard(),
                        _buildEducationalDetailsCard(),
                        _buildPreviousExperienceCard(),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class ProfileDialog extends StatefulWidget {
  final bool isRecruiter;
  final Map<String, dynamic> initialData;
  final List<String> experienceOptions;
  final List<String> specializationOptions;
  final List<String> educationOptions;
  final List<String> cityOptions;
  final Map<String, List<String>> skillsBySpecialization;
  final bool isProfileUpdated;
  final String? mobileNumber;
  final Future<void> Function(Map<String, dynamic>, Function) onUpdate;
  final String section; // 'all' | 'basic'

  const ProfileDialog({
    required this.isRecruiter,
    required this.initialData,
    required this.experienceOptions,
    required this.specializationOptions,
    required this.educationOptions,
    required this.cityOptions,
    required this.skillsBySpecialization,
    required this.isProfileUpdated,
    required this.mobileNumber,
    required this.onUpdate,
    this.section = 'all',
    super.key,
  });

  @override
  ProfileDialogState createState() => ProfileDialogState();
}

class ProfileDialogState extends State<ProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _companyNameController;
  late final TextEditingController _companyProfileController;
  late final TextEditingController _designationController;
  late final TextEditingController _experienceController;
  late final TextEditingController _currentCtcController;
  late final TextEditingController _expectedCtcController;
  late final TextEditingController _linkedinUrlController;
  late final TextEditingController _cityController;
  late final TextEditingController _addressController;
  String? _specialization;
  String? _education;
  String? _selectedCity;
  List<String> _skills = [];
  List<String> _allSkills = [];
  bool _skillsLoading = false;
  final TextEditingController _skillsSearchController = TextEditingController();
  final FocusNode _skillsSearchFocusNode = FocusNode();
  // ignore: prefer_final_fields
  bool _isLoading = false;
  String? _errorMessage;

  // Map old skills to new skills.json format for backward compatibility
  List<String> _mapOldSkillsToNewFormat(List<String> oldSkills) {
    final mapping = _getOldToNewSkillsMapping();
    final mappedSkills = <String>[];
    
    for (final skill in oldSkills) {
      final trimmedSkill = skill.trim();
      if (trimmedSkill.isEmpty) continue;
      
      // Check if skill already matches new format (contains "Development", "Engineering", etc.)
      if (trimmedSkill.contains('Development') || 
          trimmedSkill.contains('Engineering') || 
          trimmedSkill.contains('Implementation') ||
          trimmedSkill.contains('Integration') ||
          trimmedSkill.contains('Optimization') ||
          trimmedSkill.contains('Automation') ||
          trimmedSkill.contains('Administration') ||
          trimmedSkill.contains('Management') ||
          trimmedSkill.contains('Analysis') ||
          trimmedSkill.contains('Strategy') ||
          trimmedSkill.contains('Consulting') ||
          trimmedSkill.contains('Operations') ||
          trimmedSkill.contains('Support') ||
          trimmedSkill.contains('Design') ||
          trimmedSkill.contains('Architecture') ||
          trimmedSkill.contains('Deployment') ||
          trimmedSkill.contains('Monitoring') ||
          trimmedSkill.contains('Troubleshooting') ||
          trimmedSkill.contains('Security') ||
          trimmedSkill.contains('Testing') ||
          trimmedSkill.contains('Reporting') ||
          trimmedSkill.contains('Planning') ||
          trimmedSkill.contains('Configuration') ||
          trimmedSkill.contains('Migration') ||
          trimmedSkill.contains('Maintenance') ||
          trimmedSkill.contains('Training')) {
        // Skill is already in new format
        mappedSkills.add(trimmedSkill);
      } else {
        // Try to map old skill to new format
        final mappedSkill = mapping[trimmedSkill];
        if (mappedSkill != null) {
          mappedSkills.add(mappedSkill);
        } else {
          // If no mapping found, try to find a skill in _allSkills that contains the old skill name
          if (_allSkills.isNotEmpty) {
            final matchingSkill = _allSkills.firstWhere(
              (newSkill) => newSkill.toLowerCase().contains(trimmedSkill.toLowerCase()),
              orElse: () => '${trimmedSkill} Development', // Fallback: add "Development" suffix
            );
            mappedSkills.add(matchingSkill);
          } else {
            // Fallback when _allSkills is not yet loaded
            mappedSkills.add('${trimmedSkill} Development');
          }
        }
      }
    }
    
    // Remove duplicates while preserving order
    final seen = <String>{};
    return mappedSkills.where((skill) => seen.add(skill)).toList();
  }

  Map<String, dynamic>? get _profileDataFromInitial =>
      widget.initialData['profileData'] is Map<String, dynamic>
          ? widget.initialData['profileData'] as Map<String, dynamic>
          : null;

  // Onboarding / preferences editable controllers
  late final TextEditingController _currentStatusController;
  late final TextEditingController _jobTitleController;
  late final TextEditingController _currentCompanyController;
  late final TextEditingController _employmentTypeController;
  late final TextEditingController _totalExperienceYearsController;

  // Additional onboarding fields (seeker) – editable in Edit Profile
  late final TextEditingController _industryController;
  late final TextEditingController _projectsController;
  late final TextEditingController _internshipsController;
  late final TextEditingController _softSkillsController;
  late final TextEditingController _achievementsController;
  late final TextEditingController _githubUrlController;
  late final TextEditingController _portfolioUrlController;
  late final TextEditingController _resumeUrlController;

  // Education details (seeker) – editable in Edit Profile
  late final TextEditingController _tenthPassingYearController;
  late final TextEditingController _tenthScoreController;
  String? _tenthScoreType = 'Percentage';
  String? _afterTenthChoice;
  late final TextEditingController _twelfthStreamOtherController;
  late final TextEditingController _twelfthPassingYearController;
  late final TextEditingController _twelfthScoreController;
  String? _twelfthScoreType = 'Percentage';
  String? _twelfthStreamChoice;
  String? _afterTwelfthChoice;
  late final TextEditingController _diplomaBranchController;
  late final TextEditingController _diplomaUniversityController;
  late final TextEditingController _diplomaStartYearController;
  late final TextEditingController _diplomaEndYearController;
  late final TextEditingController _diplomaScoreController;
  String? _diplomaScoreType = 'Percentage';
  late final TextEditingController _graduationDegreeController;
  late final TextEditingController _graduationMajorController;
  late final TextEditingController _graduationUniversityController;
  late final TextEditingController _graduationStartYearController;
  late final TextEditingController _graduationEndYearController;
  late final TextEditingController _graduationScoreController;
  String? _graduationScoreType = 'CGPA';

  // Post-Graduation controllers
  late final TextEditingController _postGraduationDegreeController;
  late final TextEditingController _postGraduationMajorController;
  late final TextEditingController _postGraduationUniversityController;
  late final TextEditingController _postGraduationStartYearController;
  late final TextEditingController _postGraduationEndYearController;
  bool _hasPostGraduation = false;

  static const List<String> _afterTenthOptions = ['Class 12th', 'Diploma'];
  static const List<String> _twelfthStreamOptions = [
    'Science',
    'Commerce',
    'Arts',
    'Other',
  ];
  static const List<String> _afterTwelfthOptions = [
    'Diploma',
    'Graduation',
    'Other certifications',
    'None',
  ];
  static const List<String> _scoreTypeOptions = ['Percentage', 'CGPA'];

  // Previous experiences – list of {companyName, jobTitle, startDate, endDate}
  List<Map<String, String>> _previousExperiencesList = [];
  // Controllers for each previous experience row (same length as list)
  List<Map<String, TextEditingController>> _prevExpControllers = [];

  @override
  void initState() {
    super.initState();
    _initSkills();
    _nameController = TextEditingController(text: widget.initialData['name']);
    _companyNameController = TextEditingController(
      text: widget.initialData['companyName'],
    );
    _companyProfileController = TextEditingController(
      text: widget.initialData['companyProfile'],
    );
    _designationController = TextEditingController(
      text: widget.initialData['designation'],
    );
    _experienceController = TextEditingController(
      text: widget.initialData['experience'],
    );
    _currentCtcController = TextEditingController(
      text: widget.initialData['currentCtc'],
    );
    _expectedCtcController = TextEditingController(
      text: widget.initialData['expectedCtc'],
    );
    _linkedinUrlController = TextEditingController(
      text: widget.initialData['linkedinUrl'],
    );
    _cityController = TextEditingController(
      text: widget.initialData['city'],
    );
    _addressController = TextEditingController(
      text: widget.initialData['city'],
    );
    _specialization = widget.initialData['specialization'];
    _education = widget.initialData['education'];
    _selectedCity = widget.initialData['city'];
    _skills = _mapOldSkillsToNewFormat(List<String>.from(widget.initialData['skills'] ?? []));

    final p = _profileDataFromInitial ?? const <String, dynamic>{};
    _currentStatusController = TextEditingController(
      text: p['currentStatus']?.toString() ?? '',
    );
    _jobTitleController = TextEditingController(
      text: p['jobTitle']?.toString() ?? '',
    );
    _currentCompanyController = TextEditingController(
      text: p['currentCompany']?.toString() ?? '',
    );
    _employmentTypeController = TextEditingController(
      text: p['employmentType']?.toString() ?? '',
    );
    _totalExperienceYearsController = TextEditingController(
      text: p['totalExperienceYears']?.toString() ?? '',
    );

    _industryController = TextEditingController(
      text: p['industry']?.toString() ?? '',
    );
    _projectsController = TextEditingController(
      text: p['projects']?.toString() ?? '',
    );
    _internshipsController = TextEditingController(
      text: p['internships']?.toString() ?? '',
    );
    _softSkillsController = TextEditingController(
      text: p['softSkills']?.toString() ?? '',
    );
    _achievementsController = TextEditingController(
      text: p['achievements']?.toString() ?? '',
    );
    _githubUrlController = TextEditingController(
      text: p['githubUrl']?.toString() ?? '',
    );
    _portfolioUrlController = TextEditingController(
      text: p['portfolioUrl']?.toString() ?? '',
    );
    _resumeUrlController = TextEditingController(
      text: p['resumeUrl']?.toString() ?? '',
    );

    _tenthPassingYearController = TextEditingController();
    _tenthScoreController = TextEditingController();
    _twelfthStreamOtherController = TextEditingController();
    _twelfthPassingYearController = TextEditingController();
    _twelfthScoreController = TextEditingController();
    _diplomaBranchController = TextEditingController();
    _diplomaUniversityController = TextEditingController();
    _diplomaStartYearController = TextEditingController();
    _diplomaEndYearController = TextEditingController();
    _diplomaScoreController = TextEditingController();
    _graduationDegreeController = TextEditingController();
    _graduationMajorController = TextEditingController();
    _graduationUniversityController = TextEditingController();
    _graduationStartYearController = TextEditingController();
    _graduationEndYearController = TextEditingController();
    _graduationScoreController = TextEditingController();
    _postGraduationDegreeController = TextEditingController();
    _postGraduationMajorController = TextEditingController();
    _postGraduationUniversityController = TextEditingController();
    _postGraduationStartYearController = TextEditingController();
    _postGraduationEndYearController = TextEditingController();

    final edu = p['educationDetails'];
    if (edu is Map) {
      final tenth = edu['tenth'];
      if (tenth is Map) {
        _tenthPassingYearController.text =
            tenth['passingYear']?.toString() ?? '';
        _tenthScoreController.text = tenth['score']?.toString() ?? '';
        final st = tenth['scoreType']?.toString();
        if (st != null && _scoreTypeOptions.contains(st)) _tenthScoreType = st;
      }
      final at = edu['afterTenth']?.toString();
      if (at != null && _afterTenthOptions.contains(at)) _afterTenthChoice = at;
      final twelfth = edu['twelfth'];
      if (twelfth is Map) {
        _twelfthStreamOtherController.text =
            twelfth['streamOther']?.toString() ?? '';
        _twelfthPassingYearController.text =
            twelfth['passingYear']?.toString() ?? '';
        _twelfthScoreController.text = twelfth['score']?.toString() ?? '';
        final st = twelfth['scoreType']?.toString();
        if (st != null && _scoreTypeOptions.contains(st)) {
          _twelfthScoreType = st;
        }
        final stream = twelfth['stream']?.toString();
        if (stream != null &&
            _twelfthStreamOptions.contains(stream)) {
          _twelfthStreamChoice = stream;
        }
      }
      final at12 = edu['afterTwelfth']?.toString();
      if (at12 != null &&
          _afterTwelfthOptions.contains(at12)) _afterTwelfthChoice = at12;
      final diploma = edu['diploma'];
      if (diploma is Map) {
        _diplomaBranchController.text = diploma['branch']?.toString() ?? '';
        _diplomaUniversityController.text =
            diploma['university']?.toString() ?? '';
        _diplomaStartYearController.text =
            diploma['startYear']?.toString() ?? '';
        _diplomaEndYearController.text = diploma['endYear']?.toString() ?? '';
        _diplomaScoreController.text = diploma['score']?.toString() ?? '';
        final st = diploma['scoreType']?.toString();
        if (st != null && _scoreTypeOptions.contains(st)) {
          _diplomaScoreType = st;
        }
      }
      final graduation = edu['graduation'];
      if (graduation is Map) {
        _graduationDegreeController.text =
            graduation['degree']?.toString() ?? '';
        _graduationMajorController.text =
            graduation['major']?.toString() ?? '';
        _graduationUniversityController.text =
            graduation['university']?.toString() ?? '';
        _graduationStartYearController.text =
            graduation['startYear']?.toString() ?? '';
        _graduationEndYearController.text =
            graduation['endYear']?.toString() ?? '';
        _graduationScoreController.text =
            graduation['score']?.toString() ?? '';
        final st = graduation['scoreType']?.toString();
        if (st != null && _scoreTypeOptions.contains(st)) {
          _graduationScoreType = st;
        }
      }

      final postGraduation = edu['postGraduation'];
      if (postGraduation is Map) {
        _hasPostGraduation = true;
        _postGraduationDegreeController.text =
            postGraduation['degree']?.toString() ?? '';
        _postGraduationMajorController.text =
            postGraduation['major']?.toString() ?? '';
        _postGraduationUniversityController.text =
            postGraduation['university']?.toString() ?? '';
        _postGraduationStartYearController.text =
            postGraduation['startYear']?.toString() ?? '';
        _postGraduationEndYearController.text =
            postGraduation['endYear']?.toString() ?? '';
      }
    }

    final prevExps = p['previousExperiences'];
    if (prevExps is List) {
      _previousExperiencesList = prevExps
          .whereType<Map>()
          .map<Map<String, String>>((e) => {
                'companyName':
                    (e['companyName'] ?? e['company'] ?? '').toString(),
                'jobTitle':
                    (e['jobTitle'] ?? e['role'] ?? '').toString(),
                'startDate':
                    (e['startDate'] ?? e['from'] ?? '').toString(),
                'endDate': (e['endDate'] ?? e['to'] ?? '').toString(),
              })
          .toList();
    }
    for (final entry in _previousExperiencesList) {
      _prevExpControllers.add({
        'companyName': TextEditingController(text: entry['companyName'] ?? ''),
        'jobTitle': TextEditingController(text: entry['jobTitle'] ?? ''),
        'startDate': TextEditingController(text: entry['startDate'] ?? ''),
        'endDate': TextEditingController(text: entry['endDate'] ?? ''),
      });
    }
  }

  Future<void> _initSkills() async {
    if (_skillsLoading || _allSkills.isNotEmpty) return;
    _skillsLoading = true;
    try {
      final skills = await _loadSkillsFromAsset();
      if (!mounted) return;
      setState(() {
        _allSkills = skills;
      });
    } catch (e, st) {
      dev.log(
        'Failed to load skills.json: $e',
        name: 'ProfileDialog',
        stackTrace: st,
      );
    } finally {
      _skillsLoading = false;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyNameController.dispose();
    _companyProfileController.dispose();
    _designationController.dispose();
    _experienceController.dispose();
    _currentCtcController.dispose();
    _expectedCtcController.dispose();
    _linkedinUrlController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _skillsSearchController.dispose();
    _skillsSearchFocusNode.dispose();
    _currentStatusController.dispose();
    _jobTitleController.dispose();
    _currentCompanyController.dispose();
    _employmentTypeController.dispose();
    _totalExperienceYearsController.dispose();
    _industryController.dispose();
    _projectsController.dispose();
    _internshipsController.dispose();
    _softSkillsController.dispose();
    _achievementsController.dispose();
    _githubUrlController.dispose();
    _portfolioUrlController.dispose();
    _resumeUrlController.dispose();
    _tenthPassingYearController.dispose();
    _tenthScoreController.dispose();
    _twelfthStreamOtherController.dispose();
    _twelfthPassingYearController.dispose();
    _twelfthScoreController.dispose();
    _diplomaBranchController.dispose();
    _diplomaUniversityController.dispose();
    _diplomaStartYearController.dispose();
    _diplomaEndYearController.dispose();
    _diplomaScoreController.dispose();
    _graduationDegreeController.dispose();
    _graduationMajorController.dispose();
    _graduationUniversityController.dispose();
    _graduationStartYearController.dispose();
    _graduationEndYearController.dispose();
    _graduationScoreController.dispose();
    _postGraduationDegreeController.dispose();
    _postGraduationMajorController.dispose();
    _postGraduationUniversityController.dispose();
    _postGraduationStartYearController.dispose();
    _postGraduationEndYearController.dispose();
    for (final map in _prevExpControllers) {
      map['companyName']?.dispose();
      map['jobTitle']?.dispose();
      map['startDate']?.dispose();
      map['endDate']?.dispose();
    }
    super.dispose();
  }

  Widget _buildSkillsAutocomplete() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Container(
          constraints: BoxConstraints(maxWidth: 300.w),
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade50, Colors.blue.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Skills',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.blue.shade800,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              SizedBox(height: 10.h),
              TypeAheadField<String>(
                controller: _skillsSearchController,
                focusNode: _skillsSearchFocusNode,
                hideOnEmpty: true,
                suggestionsCallback: (search) {
                  final q = search.trim().toLowerCase();
                  if (q.isEmpty) return const <String>[];
                  final selectedLower =
                      _skills.map((e) => e.toLowerCase()).toSet();
                  
                  // Get all available skills (both from skills.json and old skills)
                  final allAvailableSkills = <String>[];
                  allAvailableSkills.addAll(_allSkills); // New skills from JSON
                  
                  // Add old skills from skillsBySpecialization for backward compatibility
                  final oldSkills = widget.skillsBySpecialization.values
                      .expand((skills) => skills)
                      .where((skill) => !selectedLower.contains(skill.toLowerCase()))
                      .toList();
                  allAvailableSkills.addAll(oldSkills);
                  
                  // Filter skills that match search query and aren't already selected
                  final matchingSkills = allAvailableSkills
                      .where((s) =>
                          !selectedLower.contains(s.toLowerCase()) &&
                          s.toLowerCase().contains(q))
                      .toSet()
                      .toList();
                  
                  // Sort results: prioritize exact matches, then skills starting with query
                  matchingSkills.sort((a, b) {
                    final aLower = a.toLowerCase();
                    final bLower = b.toLowerCase();
                    final qLower = q;
                    
                    // Exact match first
                    if (aLower == qLower) return -1;
                    if (bLower == qLower) return 1;
                    
                    // Skills starting with query next
                    final aStarts = aLower.startsWith(qLower);
                    final bStarts = bLower.startsWith(qLower);
                    if (aStarts && !bStarts) return -1;
                    if (!aStarts && bStarts) return 1;
                    
                    // Alphabetical order
                    return aLower.compareTo(bLower);
                  });
                  
                  return matchingSkills.take(20).toList();
                },
                itemBuilder: (context, suggestion) {
                  return ListTile(
                    dense: true,
                    title: Text(
                      suggestion,
                      style: TextStyle(fontSize: 13.sp),
                    ),
                  );
                },
                onSelected: (suggestion) {
                  if (!mounted) return;
                  setState(() {
                    if (!_skills.contains(suggestion)) {
                      _skills = [..._skills, suggestion];
                    }
                    _errorMessage = null;
                  });
                  _skillsSearchController.clear();
                  _skillsSearchFocusNode.requestFocus();
                },
                builder: (context, controller, focusNode) {
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      labelText: 'Select Skills',
                      labelStyle: TextStyle(color: Colors.grey, fontSize: 12.sp),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.teal, width: 2.w),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 10.h,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.teal.shade600,
                        size: 18.sp,
                      ),
                      hintText: 'Type a skill',
                    ),
                  );
                },
              ),
              if (_skills.isNotEmpty) ...[
                SizedBox(height: 10.h),
                Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: _skills.map((s) {
                    return Chip(
                      label: Text(s, overflow: TextOverflow.ellipsis),
                      onDeleted: () {
                        setState(() {
                          _skills = _skills.where((x) => x != s).toList();
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
              if (_skills.isEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 6.h),
                  child: Text(
                    'At least one skill is required',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadOnlyLabelValue(String label, String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty || text.toLowerCase() == 'null') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.blueGrey.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            text,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlySectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.only(top: 12.h, bottom: 6.h),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13.sp,
          fontWeight: FontWeight.w700,
          color: Colors.blueGrey.shade900,
        ),
      ),
    );
  }

  Widget _buildEditableOnboardingField({
    required String label,
    required TextEditingController controller,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.blueGrey.shade600,
            fontSize: 12.sp,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 10.w,
            vertical: 8.h,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  DateTime? _parseDate(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    final parsed = DateTime.tryParse(t);
    if (parsed != null) return parsed;
    final parts = t.split(RegExp(r'[/\-.,\s]+'));
    if (parts.length >= 3) {
      final y = int.tryParse(parts.length == 3 ? parts[2] : parts[0]);
      final m = int.tryParse(parts[0].length <= 2 ? parts[0] : parts[1]);
      final day = int.tryParse(parts[1].length <= 2 ? parts[1] : parts[2]);
      if (y != null && m != null && day != null && m >= 1 && m <= 12 && day >= 1 && day <= 31)
        return DateTime(y, m, day);
    }
    return null;
  }

  /// Computes total experience in years from all previous experience entries
  /// (start/end dates) and updates [_totalExperienceYearsController].
  void _updateTotalExperienceFromPrevExperiences() {
    double totalYears = 0.0;
    for (final ctrls in _prevExpControllers) {
      final startText = ctrls['startDate']?.text.trim() ?? '';
      final endText = ctrls['endDate']?.text.trim() ?? '';
      final start = _parseDate(startText);
      if (start == null) continue;
      final end = endText.isEmpty
          ? DateTime.now()
          : _parseDate(endText) ?? DateTime.now();
      if (end.isBefore(start)) continue;
      totalYears += end.difference(start).inDays / 365.25;
    }
    final value = totalYears < 0.1
        ? '0'
        : totalYears >= 12
            ? '12+'
            : totalYears.toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '');
    if (_totalExperienceYearsController.text != value) {
      _totalExperienceYearsController.text = value;
    }
  }

  Widget _buildDatePickerField({
    required String label,
    required TextEditingController controller,
    DateTime? firstDate,
    DateTime? lastDate,
    VoidCallback? onDatePicked,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        onTap: () async {
          final initial = _parseDate(controller.text) ?? DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: initial,
            firstDate: firstDate ?? DateTime(1950, 1, 1),
            lastDate: lastDate ?? DateTime.now(),
          );
          if (picked != null && mounted) {
            setState(() {
              controller.text = _formatDate(picked);
              onDatePicked?.call();
            });
          }
        },
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: Colors.blueGrey.shade600,
            fontSize: 12.sp,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
          ),
          contentPadding: EdgeInsets.symmetric(
            horizontal: 10.w,
            vertical: 8.h,
          ),
          filled: true,
          fillColor: Colors.white,
          suffixIcon: Icon(Icons.calendar_today, size: 20.sp, color: Colors.blueGrey.shade600),
        ),
      ),
    );
  }

  /// Build educationDetails map for save (same shape as onboarding).
  Map<String, dynamic> _buildEducationDetailsPayload() {
    final payload = <String, dynamic>{
      'tenth': {
        'passingYear': _tenthPassingYearController.text.trim(),
        'scoreType': _tenthScoreType ?? 'Percentage',
        'score': _tenthScoreController.text.trim(),
      },
      'afterTenth': _afterTenthChoice,
    };
    if (_afterTenthChoice == 'Class 12th') {
      payload['twelfth'] = {
        'stream': _twelfthStreamChoice,
        'streamOther': _twelfthStreamOtherController.text.trim(),
        'passingYear': _twelfthPassingYearController.text.trim(),
        'scoreType': _twelfthScoreType ?? 'Percentage',
        'score': _twelfthScoreController.text.trim(),
      };
      payload['afterTwelfth'] = _afterTwelfthChoice;
    }
    final showDiploma =
        _afterTenthChoice == 'Diploma' ||
        (_afterTwelfthChoice == 'Diploma');
    if (showDiploma) {
      payload['diploma'] = {
        'branch': _diplomaBranchController.text.trim(),
        'university': _diplomaUniversityController.text.trim(),
        'startYear': _diplomaStartYearController.text.trim(),
        'endYear': _diplomaEndYearController.text.trim(),
        'scoreType': _diplomaScoreType ?? 'Percentage',
        'score': _diplomaScoreController.text.trim(),
      };
    }
    final showGraduation = _afterTwelfthChoice == 'Graduation';
    if (showGraduation) {
      payload['graduation'] = {
        'degree': _graduationDegreeController.text.trim(),
        'major': _graduationMajorController.text.trim(),
        'university': _graduationUniversityController.text.trim(),
        'startYear': _graduationStartYearController.text.trim(),
        'endYear': _graduationEndYearController.text.trim(),
        'scoreType': _graduationScoreType ?? 'CGPA',
        'score': _graduationScoreController.text.trim(),
      };
    }

    // Add post-graduation data if applicable
    if (showGraduation && _hasPostGraduation) {
      payload['postGraduation'] = {
        'degree': _postGraduationDegreeController.text.trim(),
        'major': _postGraduationMajorController.text.trim(),
        'university': _postGraduationUniversityController.text.trim(),
        'startYear': _postGraduationStartYearController.text.trim(),
        'endYear': _postGraduationEndYearController.text.trim(),
      };
    }
    return payload;
  }

  Widget _buildDropdownFormField<T>({
    required String label,
    required T? value,
    required List<T> items,
    required void Function(T?) onChanged,
    String Function(T)? itemLabel,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.blueGrey.shade600, fontSize: 12.sp),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
          contentPadding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
          filled: true,
          fillColor: Colors.white,
        ),
        isExpanded: true,
        items: items.map((T v) {
          return DropdownMenuItem<T>(
            value: v,
            child: Text(
              itemLabel != null ? itemLabel(v) : v.toString(),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.sp),
            ),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  /// Validate LinkedIn URL
  String? _validateLinkedInUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // LinkedIn URL is optional
    }
    final trimmed = value.trim();
    // Check if it's a valid LinkedIn URL pattern (allows query parameters and fragments)
    final linkedinRegex = RegExp(
      r'^(https?://)?(www\.)?linkedin\.com/(in|pub|company)/[a-zA-Z0-9_-]+/?',
      caseSensitive: false,
    );
    if (!linkedinRegex.hasMatch(trimmed)) {
      return 'Please enter a valid LinkedIn profile URL';
    }
    return null;
  }

  Widget _buildTextField(
    String label, {
    bool multiline = false,
    TextEditingController? controller,
    String? Function(String?)? validator,
  }) {
    final isUrl =
        label.toLowerCase().contains('url') ||
        label.toLowerCase().contains('link');
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Container(
        constraints: BoxConstraints(maxWidth: 300.w),
        child: TextFormField(
          controller: controller,
          maxLines: multiline ? 4 : 1,
          maxLength: multiline ? 500 : (isUrl ? 255 : 100),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.grey, fontSize: 12.sp),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(12.r),
            ),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.teal, width: 2.w),
              borderRadius: BorderRadius.circular(12.r),
            ),
            errorBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.red, width: 2.w),
              borderRadius: BorderRadius.circular(12.r),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderSide: BorderSide(color: Colors.red, width: 2.w),
              borderRadius: BorderRadius.circular(12.r),
            ),
            errorStyle: TextStyle(
              color: Colors.red.shade700,
              fontWeight: FontWeight.w600,
              fontSize: 11.sp,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12.w,
              vertical: 10.h,
            ),
            counterText: multiline ? null : '',
          ),
          validator: validator,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          onChanged: (value) {
            if (mounted) setState(() => _errorMessage = null);
          },
        ),
      ),
    );
  }

  Widget _buildCityAutocompleteField() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Container(
        constraints: BoxConstraints(maxWidth: 300.w),
        child: Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (textEditingValue.text.isEmpty) {
              return const Iterable<String>.empty();
            }
            return widget.cityOptions.where((String option) {
              return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
            });
          },
          onSelected: (String selection) {
            setState(() {
              _selectedCity = selection;
              _cityController.text = selection;
              _errorMessage = null;
            });
          },
          fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
            // Initialize the autocomplete controller with our current value
            if (textEditingController.text != _cityController.text) {
              textEditingController.text = _cityController.text;
            }
            // Add listener to update our state when text changes
            textEditingController.addListener(() {
              if (_selectedCity != textEditingController.text) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _selectedCity = textEditingController.text;
                      _cityController.text = textEditingController.text;
                      _errorMessage = null;
                    });
                  }
                });
              }
            });
            return TextFormField(
              controller: textEditingController,
              focusNode: focusNode,
              decoration: InputDecoration(
                labelText: 'City',
                labelStyle: TextStyle(color: Colors.grey, fontSize: 12.sp),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.teal, width: 2.w),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                errorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red, width: 2.w),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red, width: 2.w),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                errorStyle: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w600,
                  fontSize: 11.sp,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 10.h,
                ),
                prefixIcon: Icon(
                  Icons.location_city_outlined,
                  color: Colors.teal.shade600,
                  size: 18.sp,
                ),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'City is required'
                  : null,
              autovalidateMode: AutovalidateMode.onUserInteraction,
            );
          },
          optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4.0,
                child: Container(
                  constraints: BoxConstraints(maxWidth: 300.w, maxHeight: 200.h),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (BuildContext context, int index) {
                      final String option = options.elementAt(index);
                      return ListTile(
                        title: Text(
                          option,
                          style: TextStyle(fontSize: 14.sp),
                        ),
                        onTap: () {
                          onSelected(option);
                        },
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      title: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade700, Colors.blue.shade900],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
        ),
        child: Text(
          widget.isProfileUpdated ? 'Edit Profile' : 'Update Profile',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      content: SingleChildScrollView(
        child: Container(
          constraints: BoxConstraints(maxWidth: 300.w),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null)
                  Padding(
                    padding: EdgeInsets.only(bottom: 8.h),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12.sp,
                      ),
                    ),
                  ),
                if (widget.isRecruiter) ...[
                  _buildTextField(
                    'Name',
                    controller: _nameController,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Name is required'
                        : null,
                  ),
                  _buildTextField(
                    'Company Name',
                    controller: _companyNameController,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Company Name is required'
                        : null,
                  ),
                  _buildTextField(
                    'Company Profile',
                    multiline: true,
                    controller: _companyProfileController,
                  ),
                  _buildTextField(
                    'Designation',
                    controller: _designationController,
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Container(
                      constraints: BoxConstraints(maxWidth: 300.w),
                      child: AddressAutocompleteField(
                        controller: _addressController,
                        labelText: 'Headquarters address (India)',
                        helperText: 'Start typing to see location suggestions',
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                        decoration: InputDecoration(
                          labelStyle:
                              TextStyle(color: Colors.grey, fontSize: 12.sp),
                          enabledBorder: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.teal,
                              width: 2.w,
                            ),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.red, width: 2.w),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.red, width: 2.w),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          errorStyle: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 11.sp,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 10.h,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _buildTextField(
                    'LinkedIn URL',
                    controller: _linkedinUrlController,
                    validator: _validateLinkedInUrl,
                  ),
                ] else ...[
                  // For seekers, always show the full set of fields
                  _buildTextField(
                    'Name',
                    controller: _nameController,
                    validator: (value) =>
                        value == null || value.trim().isEmpty
                            ? 'Name is required'
                            : null,
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Container(
                      constraints: BoxConstraints(maxWidth: 300.w),
                      child: AddressAutocompleteField(
                        controller: _addressController,
                        labelText: 'Address (India)',
                        helperText: 'Start typing to see location suggestions',
                        textInputAction: TextInputAction.next,
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                        decoration: InputDecoration(
                          labelStyle:
                              TextStyle(color: Colors.grey, fontSize: 12.sp),
                          enabledBorder: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.teal,
                              width: 2.w,
                            ),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.red, width: 2.w),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.red, width: 2.w),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          errorStyle: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w600,
                            fontSize: 11.sp,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 10.h,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Container(
                      constraints: BoxConstraints(maxWidth: 300.w),
                      child: DropdownButtonFormField<String>(
                        initialValue:
                            widget.specializationOptions.contains(_specialization)
                                ? _specialization
                                : null,
                        decoration: InputDecoration(
                          labelText: 'Specialization',
                          labelStyle: TextStyle(
                            color: Colors.grey,
                            fontSize: 12.sp,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: Colors.teal,
                              width: 2.w,
                            ),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 10.h,
                          ),
                        ),
                        isExpanded: true,
                        menuMaxHeight: 300.h,
                        items: widget.specializationOptions.map((
                          String specialization,
                        ) {
                          return DropdownMenuItem<String>(
                            value: specialization,
                            child: Container(
                              constraints: BoxConstraints(maxWidth: 250.w),
                              child: Text(
                                specialization,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 12.sp,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _specialization = value;
                            _errorMessage = null;
                          });
                        },
                        validator: (value) => value == null
                            ? 'Specialization is required'
                            : null,
                      ),
                    ),
                  ),
                  _buildSkillsAutocomplete(),
                  _buildTextField(
                    'Current CTC',
                    controller: _currentCtcController,
                  ),
                  _buildTextField(
                    'Expected CTC',
                    controller: _expectedCtcController,
                  ),
                  _buildTextField(
                    'LinkedIn URL',
                    controller: _linkedinUrlController,
                    validator: _validateLinkedInUrl,
                  ),
                ], // end of seeker/recruiter fields (else block)
                const SizedBox(height: 16),
                if (!widget.isRecruiter) ...[
                  _buildReadOnlySectionTitle('Career details'),
                  _buildEditableOnboardingField(
                    label: 'Current Status',
                    controller: _currentStatusController,
                  ),
                  _buildEditableOnboardingField(
                    label: 'Job Title',
                    controller: _jobTitleController,
                  ),
                  _buildEditableOnboardingField(
                    label: 'Current Company',
                    controller: _currentCompanyController,
                  ),
                  _buildEditableOnboardingField(
                    label: 'Employment Type',
                    controller: _employmentTypeController,
                  ),
                  _buildEditableOnboardingField(
                    label: 'Total Experience (years)',
                    controller: _totalExperienceYearsController,
                  ),
                  _buildEditableOnboardingField(
                    label: 'Industry',
                    controller: _industryController,
                  ),
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: false,
                      title: Text(
                        'Education details',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.blueGrey.shade900,
                        ),
                      ),
                      children: [
                        _buildDropdownFormField<String>(
                          label: 'After 10th',
                          value: _afterTenthChoice,
                          items: _afterTenthOptions,
                          onChanged: (v) => setState(() => _afterTenthChoice = v),
                        ),
                        _buildEditableOnboardingField(
                          label: '10th - Passing Year',
                          controller: _tenthPassingYearController,
                        ),
                        _buildEditableOnboardingField(
                          label: '10th - Score',
                          controller: _tenthScoreController,
                        ),
                        _buildDropdownFormField<String>(
                          label: '10th - Score Type',
                          value: _tenthScoreType,
                          items: _scoreTypeOptions,
                          onChanged: (v) => setState(() => _tenthScoreType = v),
                        ),
                        if (_afterTenthChoice == 'Class 12th') ...[
                          _buildDropdownFormField<String>(
                            label: '12th - Stream',
                            value: _twelfthStreamChoice,
                            items: _twelfthStreamOptions,
                            onChanged: (v) => setState(() => _twelfthStreamChoice = v),
                          ),
                          _buildEditableOnboardingField(
                            label: '12th - Stream Other',
                            controller: _twelfthStreamOtherController,
                          ),
                          _buildEditableOnboardingField(
                            label: '12th - Passing Year',
                            controller: _twelfthPassingYearController,
                          ),
                          _buildEditableOnboardingField(
                            label: '12th - Score',
                            controller: _twelfthScoreController,
                          ),
                          _buildDropdownFormField<String>(
                            label: '12th - Score Type',
                            value: _twelfthScoreType,
                            items: _scoreTypeOptions,
                            onChanged: (v) => setState(() => _twelfthScoreType = v),
                          ),
                          _buildDropdownFormField<String>(
                            label: 'After 12th',
                            value: _afterTwelfthChoice,
                            items: _afterTwelfthOptions,
                            onChanged: (v) => setState(() => _afterTwelfthChoice = v),
                          ),
                        ],
                        if (_afterTenthChoice == 'Diploma' ||
                            _afterTwelfthChoice == 'Diploma') ...[
                          _buildEditableOnboardingField(
                            label: 'Diploma - Branch',
                            controller: _diplomaBranchController,
                          ),
                          _buildEditableOnboardingField(
                            label: 'Diploma - University',
                            controller: _diplomaUniversityController,
                          ),
                          _buildEditableOnboardingField(
                            label: 'Diploma - Start Year',
                            controller: _diplomaStartYearController,
                          ),
                          _buildEditableOnboardingField(
                            label: 'Diploma - End Year',
                            controller: _diplomaEndYearController,
                          ),
                          _buildEditableOnboardingField(
                            label: 'Diploma - Score',
                            controller: _diplomaScoreController,
                          ),
                          _buildDropdownFormField<String>(
                            label: 'Diploma - Score Type',
                            value: _diplomaScoreType,
                            items: _scoreTypeOptions,
                            onChanged: (v) => setState(() => _diplomaScoreType = v),
                          ),
                        ],
                        if (_afterTwelfthChoice == 'Graduation') ...[
                          _buildEditableOnboardingField(
                            label: 'Graduation - Degree',
                            controller: _graduationDegreeController,
                          ),
                          _buildEditableOnboardingField(
                            label: 'Graduation - Major',
                            controller: _graduationMajorController,
                          ),
                          _buildEditableOnboardingField(
                            label: 'Graduation - University',
                            controller: _graduationUniversityController,
                          ),
                          _buildEditableOnboardingField(
                            label: 'Graduation - Start Year',
                            controller: _graduationStartYearController,
                          ),
                          _buildEditableOnboardingField(
                            label: 'Graduation - End Year',
                            controller: _graduationEndYearController,
                          ),
                          _buildEditableOnboardingField(
                            label: 'Graduation - Score',
                            controller: _graduationScoreController,
                          ),
                          _buildDropdownFormField<String>(
                            label: 'Graduation - Score Type',
                            value: _graduationScoreType,
                            items: _scoreTypeOptions,
                            onChanged: (v) => setState(() => _graduationScoreType = v),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Post-Graduation section
                  if (_afterTwelfthChoice == 'Graduation') ...[
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(bottom: 12.h),
                      padding: EdgeInsets.all(14.w),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Post-Graduation (optional)',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Switch(
                                value: _hasPostGraduation,
                                onChanged: (v) => setState(() => _hasPostGraduation = v),
                              ),
                            ],
                          ),
                          if (_hasPostGraduation) ...[
                            SizedBox(height: 12.h),
                            _buildEditableOnboardingField(
                              label: 'Post-Graduation - Degree',
                              controller: _postGraduationDegreeController,
                            ),
                            _buildEditableOnboardingField(
                              label: 'Post-Graduation - Major',
                              controller: _postGraduationMajorController,
                            ),
                            _buildEditableOnboardingField(
                              label: 'Post-Graduation - University',
                              controller: _postGraduationUniversityController,
                            ),
                            _buildEditableOnboardingField(
                              label: 'Post-Graduation - Start Year',
                              controller: _postGraduationStartYearController,
                            ),
                            _buildEditableOnboardingField(
                              label: 'Post-Graduation - End Year',
                              controller: _postGraduationEndYearController,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: false,
                      title: Text(
                        'Projects, links & more',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.blueGrey.shade900,
                        ),
                      ),
                      children: [
                        _buildEditableOnboardingField(
                          label: 'Projects',
                          controller: _projectsController,
                        ),
                        _buildEditableOnboardingField(
                          label: 'Internships',
                          controller: _internshipsController,
                        ),
                        _buildEditableOnboardingField(
                          label: 'Soft skills',
                          controller: _softSkillsController,
                        ),
                        _buildEditableOnboardingField(
                          label: 'Achievements',
                          controller: _achievementsController,
                        ),
                        _buildEditableOnboardingField(
                          label: 'GitHub URL',
                          controller: _githubUrlController,
                        ),
                        _buildEditableOnboardingField(
                          label: 'Portfolio URL',
                          controller: _portfolioUrlController,
                        ),
                        _buildEditableOnboardingField(
                          label: 'Resume URL',
                          controller: _resumeUrlController,
                        ),
                      ],
                    ),
                  ),
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: false,
                      title: Text(
                        'Previous experience',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.blueGrey.shade900,
                        ),
                      ),
                      children: [
                        ...List.generate(_prevExpControllers.length, (i) {
                          final ctrls = _prevExpControllers[i];
                          return Padding(
                            padding: EdgeInsets.only(bottom: 8.h),
                            child: Card(
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding: EdgeInsets.all(8.w),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Experience ${i + 1}',
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.remove_circle_outline,
                                              size: 20.sp, color: Colors.red),
                                          onPressed: () {
                                            setState(() {
                                              final removed = _prevExpControllers.removeAt(i);
                                              removed['companyName']?.dispose();
                                              removed['jobTitle']?.dispose();
                                              removed['startDate']?.dispose();
                                              removed['endDate']?.dispose();
                                              if (i < _previousExperiencesList.length) {
                                                _previousExperiencesList.removeAt(i);
                                              }
                                              _updateTotalExperienceFromPrevExperiences();
                                            });
                                          },
                                          padding: EdgeInsets.zero,
                                          constraints: BoxConstraints(),
                                        ),
                                      ],
                                    ),
                                    _buildEditableOnboardingField(
                                      label: 'Company',
                                      controller: ctrls['companyName']!,
                                    ),
                                    _buildEditableOnboardingField(
                                      label: 'Job Title',
                                      controller: ctrls['jobTitle']!,
                                    ),
                                    _buildDatePickerField(
                                      label: 'Start Date',
                                      controller: ctrls['startDate']!,
                                      lastDate: DateTime.now(),
                                      onDatePicked: _updateTotalExperienceFromPrevExperiences,
                                    ),
                                    _buildDatePickerField(
                                      label: 'End Date',
                                      controller: ctrls['endDate']!,
                                      lastDate: DateTime.now(),
                                      onDatePicked: _updateTotalExperienceFromPrevExperiences,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _previousExperiencesList.add({
                                'companyName': '',
                                'jobTitle': '',
                                'startDate': '',
                                'endDate': '',
                              });
                              _prevExpControllers.add({
                                'companyName': TextEditingController(),
                                'jobTitle': TextEditingController(),
                                'startDate': TextEditingController(),
                                'endDate': TextEditingController(),
                              });
                            });
                          },
                          icon: Icon(Icons.add, size: 18.sp),
                          label: Text('Add experience'),
                        ),
                      ],
                    ),
                  ),
                ],
              ], // end of children list
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text(
            'Back',
            style: TextStyle(color: Colors.grey, fontSize: 12.sp),
          ),
        ),
        TextButton(
          onPressed: _isLoading
              ? null
              : () async {
                  // run field validators first
                  if (!_formKey.currentState!.validate()) {
                    return;
                  }

                  final mobileNumber = widget.mobileNumber?.trim() ?? '';
                  if (mobileNumber.isEmpty) {
                    setState(() {
                      _errorMessage =
                          'Mobile number is required to update profile.';
                    });
                    return;
                  }

                  // no need for separate LinkedIn validation; field validator covers it

                  final profileData = widget.isRecruiter
                      ? {
                          'name': _nameController.text.trim(),
                          'mobileNumber': mobileNumber,
                          'city': _addressController.text.trim(),
                          'companyName': _companyNameController.text.trim(),
                          'companyProfile':
                              _companyProfileController.text.trim(),
                          'designation': _designationController.text.trim(),
                          'linkedinUrl': _linkedinUrlController.text.trim(),
                          'updatedAt': FieldValue.serverTimestamp(),
                        }
                      : {
                          'name': _nameController.text.trim(),
                          'mobileNumber': mobileNumber,
                          'city': _addressController.text.trim(),
                          'skills': _skills,
                          'education': _education,
                          'experience': _experienceController.text.trim(),
                          'specialization': _specialization,
                          'currentCtc': _currentCtcController.text
                              .replaceAll(' LPA (INR)', '')
                              .trim(),
                          'expectedCtc': _expectedCtcController.text
                              .replaceAll(' LPA (INR)', '')
                              .trim(),
                          'linkedinUrl': _linkedinUrlController.text.trim(),
                          // Onboarding extras (basic info)
                          'currentStatus':
                              _currentStatusController.text.trim(),
                          'jobTitle': _jobTitleController.text.trim(),
                          'currentCompany':
                              _currentCompanyController.text.trim(),
                          'employmentType':
                              _employmentTypeController.text.trim(),
                          'totalExperienceYears':
                              _totalExperienceYearsController.text.trim(),
                          // Onboarding fields edited in-place
                          'industry': _industryController.text.trim(),
                          'projects': _projectsController.text.trim(),
                          'internships': _internshipsController.text.trim(),
                          'softSkills': _softSkillsController.text.trim(),
                          'achievements': _achievementsController.text.trim(),
                          'githubUrl': _githubUrlController.text.trim(),
                          'portfolioUrl': _portfolioUrlController.text.trim(),
                          'resumeUrl': _resumeUrlController.text.trim(),
                          'educationDetails': _buildEducationDetailsPayload(),
                          'previousExperiences': _prevExpControllers
                              .map((c) => {
                                    'companyName': c['companyName']!.text.trim(),
                                    'jobTitle': c['jobTitle']!.text.trim(),
                                    'startDate': c['startDate']!.text.trim(),
                                    'endDate': c['endDate']!.text.trim(),
                                  })
                              .toList(),
                          'updatedAt': FieldValue.serverTimestamp(),
                        };

                  // Capture context before asynchronous gap
                  // ignore: use_build_context_synchronously
                  final dialogContext = context;
                  // Call the update and wait for it to complete
                  await widget.onUpdate(profileData, setState);

                  // After successful update, close the dialog if still mounted
                  if (!mounted) return;
                  if (_errorMessage == null) {
                    // ignore: use_build_context_synchronously
                    Navigator.of(dialogContext).pop();
                  }
                },
          child: _isLoading
              ? SizedBox(
                  width: 20.w,
                  height: 20.h,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.w,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                  ),
                )
              : Text(
                  'Save',
                  style: TextStyle(color: Colors.teal, fontSize: 12.sp),
                ),
        ),
      ],
    );
  }
}
class AnimatedScaleButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;

  const AnimatedScaleButton({
    required this.onPressed,
    required this.child,
    super.key,
  });

  @override
  AnimatedScaleButtonState createState() => AnimatedScaleButtonState();
}

class AnimatedScaleButtonState extends State<AnimatedScaleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onPressed();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

class MultiSelectDialog extends StatefulWidget {
  final List<String> items;
  final List<String> selectedItems;

  const MultiSelectDialog({
    required this.items,
    required this.selectedItems,
    super.key,
  });

  @override
  MultiSelectDialogState createState() => MultiSelectDialogState();
}

class MultiSelectDialogState extends State<MultiSelectDialog> {
  late List<String> _tempSelectedItems;

  @override
  void initState() {
    super.initState();
    _tempSelectedItems = List.from(widget.selectedItems);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      title: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade700, Colors.blue.shade900],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
        ),
        child: const Text(
          'Select Skills',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      content: SingleChildScrollView(
        child: Container(
          constraints: BoxConstraints(maxWidth: 300.w),
          child: Column(
            children: widget.items.map((item) {
              return CheckboxListTile(
                title: Text(
                  item,
                  style: TextStyle(color: Colors.black87, fontSize: 12.sp),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                value: _tempSelectedItems.contains(item),
                activeColor: Colors.teal,
                checkColor: Colors.white,
                contentPadding: EdgeInsets.symmetric(horizontal: 8.w),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _tempSelectedItems.add(item);
                    } else {
                      _tempSelectedItems.remove(item);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context, _tempSelectedItems);
          },
          child: const Text(
            'OK',
            style: TextStyle(color: Colors.teal, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
