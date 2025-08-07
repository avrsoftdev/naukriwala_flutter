import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:naukariwala/services/auth_service.dart';
import 'dart:developer' as dev;

class ProfileScreen extends StatefulWidget {
  final bool isRecruiter;

  const ProfileScreen({this.isRecruiter = false, super.key});

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();
  final AuthService _authService = AuthService();

  // Controllers for editable fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _companyNameController = TextEditingController();
  final TextEditingController _companyProfileController = TextEditingController();
  final TextEditingController _designationController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _educationController = TextEditingController();
  final TextEditingController _currentCompanyController = TextEditingController();
  final TextEditingController _currentCtcController = TextEditingController();
  final TextEditingController _expectedCtcController = TextEditingController();

  // Non-editable fields
  String? _mobileNumber;
  String? _email;

  // Dropdown and multi-select fields for seekers
  String? _selectedSpecialization;
  List<String> _selectedSkills = [];

  // Specialization options (same as PostJobScreen, ApplyJobScreen, JobDetailsScreen)
  final List<String> specializationOptions = [
    'Computer Science / IT',
    'Electronics / Electrical / Robotics',
    'Mechanical / Civil / Architecture',
    'Business / Finance / Management',
    'Medicine / Healthcare / Pharma',
    'Law / Political Science / Public Administration',
    'Arts / Humanities / Education',
    'Design / Media / Communication',
    'Hotel / Travel / Event Management',
    'Science / Research / Environment',
    'Others',
  ];

  // Skills by specialization (same as PostJobScreen, ApplyJobScreen, JobDetailsScreen)
  final Map<String, List<String>> skillsBySpecialization = {
    'Computer Science / IT': [
      'Java', 'Python', 'C++', 'C#', 'Dart', 'Flutter', 'Android Development',
      'iOS Development', 'React', 'Angular', 'Vue.js', 'Node.js', 'Firebase',
      'AWS', 'Docker', 'Kubernetes', 'SQL', 'MongoDB', 'REST APIs', 'GraphQL',
      'Machine Learning', 'Data Structures & Algorithms', 'DevOps', 'Cybersecurity',
      'System Design',
    ],
    'Electronics / Electrical / Robotics': [
      'Embedded Systems', 'PCB Design', 'VLSI', 'MATLAB', 'Simulink', 'Verilog',
      'FPGA Programming', 'Arduino', 'Raspberry Pi', 'IoT Development',
      'Signal Processing', 'Power Systems', 'Automation', 'SCADA',
    ],
    'Mechanical / Civil / Architecture': [
      'AutoCAD', 'SolidWorks', 'CATIA', 'ANSYS', 'STAAD Pro', 'Revit',
      'Structural Analysis', 'Thermodynamics', 'Manufacturing Processes',
      'Fluid Mechanics', 'Construction Management', 'Urban Planning',
    ],
    'Business / Finance / Management': [
      'Financial Analysis', 'Accounting', 'MS Excel', 'Tally', 'Business Intelligence',
      'SAP', 'QuickBooks', 'Digital Marketing', 'Google Ads', 'SEO',
      'Social Media Marketing', 'Project Management', 'Agile', 'Scrum',
      'Business Strategy', 'Market Research', 'Customer Relationship Management (CRM)',
      'Salesforce',
    ],
    'Medicine / Healthcare / Pharma': [
      'Clinical Research', 'Patient Care', 'Surgical Assistance', 'Nursing Procedures',
      'Medical Coding', 'Public Health', 'Pharmacology', 'First Aid', 'CPR',
      'Health Education', 'Lab Testing', 'Radiology', 'Therapeutic Skills',
    ],
    'Law / Political Science / Public Administration': [
      'Legal Research', 'Case Analysis', 'Contract Drafting', 'Litigation',
      'Legal Compliance', 'Constitutional Law', 'Criminal Law', 'International Law',
      'Arbitration', 'Policy Analysis', 'Public Speaking',
    ],
    'Arts / Humanities / Education': [
      'Creative Writing', 'Content Writing', 'Linguistics', 'Public Speaking',
      'Editing & Proofreading', 'Critical Thinking', 'Classroom Management',
      'Curriculum Development', 'E-Learning Tools', 'Art History', 'Philosophical Analysis',
    ],
    'Design / Media / Communication': [
      'Adobe Photoshop', 'Adobe Illustrator', 'Adobe XD', 'Figma', 'Canva',
      'UI/UX Design', 'Video Editing', '3D Modeling', 'Motion Graphics', 'Photography',
      'Copywriting', 'Branding', 'Social Media Content Creation', 'Typography', 'Storyboarding',
      'Final Cut Pro', 'Lightroom',
    ],
    'Hotel / Travel / Event Management': [
      'Event Planning', 'Hospitality Management', 'Customer Service', 'Bartending',
      'Housekeeping', 'Food & Beverage Service', 'Travel Planning', 'Ticketing & Reservations',
      'Catering Services', 'Inventory Management', 'Public Relations', 'Vendor Management',
    ],
    'Science / Research / Environment': [
      'Laboratory Techniques', 'Statistical Analysis', 'Research Writing', 'Data Collection',
      'Environmental Impact Assessment', 'Geographic Information System (GIS)', 'Microscopy',
      'Chemical Analysis', 'Climate Modeling', 'Bioinformatics',
    ],
    'Others': [
      'Communication Skills', 'Problem Solving', 'Teamwork', 'Leadership', 'Time Management',
      'Adaptability', 'Creativity', 'Conflict Resolution', 'Critical Thinking', 'Customer Support',
      'Basic Computer Skills', 'Typing', 'Remote Work Tools (Zoom, Slack, Trello)', 'Virtual Assistant',
      'Content Moderation',
    ],
  };

  File? _imageFile;
  String? _imageUrl;
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => errorMessage = 'No user logged in');
      return;
    }

    try {
      setState(() => isLoading = true);
      final data = await _authService.fetchProfileData(isRecruiter: widget.isRecruiter);
      if (data != null && mounted) {
        dev.log('Firestore data: $data', name: 'ProfileScreen');
        setState(() {
          _nameController.text = data['name'] ?? '';
          _mobileNumber = data['mobileNumber'] ?? data['mobile'] ?? data['Mobile Number'] ?? '';
          _email = user.email ?? '';
          _imageUrl = widget.isRecruiter ? data['companyLogo'] : data['photoUrl'];
          if (widget.isRecruiter) {
            _companyNameController.text = data['companyName'] ?? '';
            _companyProfileController.text = data['companyProfile'] ?? '';
            _designationController.text = data['designation'] ?? '';
          } else {
            _experienceController.text = data['experience'] ?? '';
            _educationController.text = data['education'] ?? '';
            _selectedSkills = (data['skills'] as List<dynamic>?)?.cast<String>() ?? [];
            _selectedSpecialization = specializationOptions.contains(data['specialization'])
                ? data['specialization']
                : 'Others';
            _currentCompanyController.text = data['currentCompany'] ?? '';
            _currentCtcController.text = data['currentCtc'] ?? '';
            _expectedCtcController.text = data['expectedCtc'] ?? '';
          }
        });
      } else if (mounted) {
        setState(() => errorMessage = 'Profile not found');
      }
    } catch (e) {
      dev.log('Error loading profile: $e', name: 'ProfileScreen');
      if (mounted) {
        setState(() => errorMessage = 'Error loading profile: $e');
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null && mounted) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return _imageUrl;
    try {
      final url = widget.isRecruiter
          ? await _authService.uploadCompanyLogo(_imageFile!)
          : await _authService.uploadSeekerPhoto(_imageFile!);
      return url;
    } catch (e) {
      dev.log('Error uploading image: $e', name: 'ProfileScreen');
      if (mounted) {
        setState(() => errorMessage = 'Error uploading image: $e');
      }
      return null;
    }
  }

  Map<String, dynamic> _generateResumeData() {
    if (widget.isRecruiter) return {};
    return {
      'name': _nameController.text.trim(),
      'email': _email ?? '',
      'mobileNumber': _mobileNumber ?? '',
      'skills': _selectedSkills,
      'education': _educationController.text.trim(),
      'experience': _experienceController.text.trim(),
      'specialization': _selectedSpecialization ?? 'Others',
      'currentCompany': _currentCompanyController.text.trim(),
      'currentCtc': _currentCtcController.text.trim(),
      'expectedCtc': _expectedCtcController.text.trim(),
      'photoUrl': _imageUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> _updateProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => errorMessage = 'No user logged in');
      return;
    }

    // Validate required fields
    if (_nameController.text.trim().isEmpty) {
      setState(() => errorMessage = 'Name is required');
      return;
    }
    if (widget.isRecruiter) {
      if (_companyNameController.text.trim().isEmpty) {
        setState(() => errorMessage = 'Company Name is required');
        return;
      }
    } else {
      if (_selectedSkills.isEmpty) {
        setState(() => errorMessage = 'At least one skill is required');
        return;
      }
      if (_educationController.text.trim().isEmpty) {
        setState(() => errorMessage = 'Education is required');
        return;
      }
      if (_experienceController.text.trim().isEmpty) {
        setState(() => errorMessage = 'Experience is required');
        return;
      }
      final experienceMatch = RegExp(r'^\d+\s*(years?|yrs?)?$').hasMatch(_experienceController.text.trim());
      if (!experienceMatch) {
        setState(() => errorMessage = 'Experience must be in format "X years" (e.g., "2 years")');
        return;
      }
      if (_selectedSpecialization == null) {
        setState(() => errorMessage = 'Specialization is required');
        return;
      }
    }

    try {
      setState(() => isLoading = true);
      final imageUrl = await _uploadImage();
      final profileData = widget.isRecruiter
          ? {
              'name': _nameController.text.trim(),
              'companyName': _companyNameController.text.trim(),
              'companyProfile': _companyProfileController.text.trim(),
              'designation': _designationController.text.trim(),
              'updatedAt': FieldValue.serverTimestamp(),
              if (imageUrl != null) 'companyLogo': imageUrl,
            }
          : {
              'name': _nameController.text.trim(),
              'skills': _selectedSkills,
              'education': _educationController.text.trim(),
              'experience': _experienceController.text.trim(),
              'specialization': _selectedSpecialization,
              'currentCompany': _currentCompanyController.text.trim(),
              'currentCtc': _currentCtcController.text.trim(),
              'expectedCtc': _expectedCtcController.text.trim(),
              'updatedAt': FieldValue.serverTimestamp(),
              if (imageUrl != null) 'photoUrl': imageUrl,
            };

      dev.log('Updating profile with data: $profileData', name: 'ProfileScreen');
      await _authService.storeSignupData(
        isRecruiter: widget.isRecruiter,
        data: profileData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Profile updated successfully'),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );
        setState(() => errorMessage = null);
      }
    } catch (e) {
      dev.log('Error updating profile: $e', name: 'ProfileScreen');
      if (mounted) {
        setState(() => errorMessage = 'Error updating profile: $e');
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    try {
      setState(() => isLoading = true);
      await _authService.signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (e) {
      dev.log('Logout error: $e', name: 'ProfileScreen');
      if (e is FirebaseAuthException) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Firebase Error: ${e.message}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Widget _buildTextField(String label,
      {bool isPassword = false,
      bool multiline = false,
      TextEditingController? controller,
      String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        maxLines: multiline ? 4 : 1,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey),
          enabledBorder: const UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.grey),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.teal, width: 2),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        validator: validator,
        onChanged: (value) {
          if (mounted) setState(() => errorMessage = null);
        },
      ),
    );
  }

  Widget _buildNonEditableField(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade50, Colors.blue.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 14, color: Colors.blue.shade800, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                value ?? 'N/A',
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecializationDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: DropdownButtonFormField<String>(
        value: _selectedSpecialization,
        decoration: InputDecoration(
          labelText: 'Specialization',
          labelStyle: const TextStyle(color: Colors.grey),
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.teal, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        items: specializationOptions.map((String specialization) {
          return DropdownMenuItem<String>(
            value: specialization,
            child: Text(specialization, style: const TextStyle(color: Colors.black87)),
          );
        }).toList(),
        onChanged: (value) {
          if (mounted) {
            setState(() {
              _selectedSpecialization = value;
              _selectedSkills = []; // Reset skills when specialization changes
              errorMessage = null;
            });
          }
        },
        validator: (value) => value == null ? 'Specialization is required' : null,
      ),
    );
  }

  Widget _buildSkillsMultiSelect() {
    final availableSkills = skillsBySpecialization[_selectedSpecialization ?? 'Others'] ?? [];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: GestureDetector(
          onTap: () async {
            final selected = await showDialog<List<String>>(
              context: context,
              builder: (context) => MultiSelectDialog(
                items: availableSkills,
                selectedItems: _selectedSkills,
              ),
            );
            if (selected != null && mounted) {
              setState(() {
                _selectedSkills = selected;
                errorMessage = null;
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.blue.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Skills',
                  style: TextStyle(fontSize: 14, color: Colors.blue.shade800, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedSkills.isEmpty ? 'Select skills' : _selectedSkills.join(', '),
                  style: TextStyle(
                    fontSize: 16,
                    color: _selectedSkills.isEmpty ? Colors.grey : Colors.black87,
                  ),
                ),
                if (_selectedSkills.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'At least one skill is required',
                      style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _companyNameController.dispose();
    _companyProfileController.dispose();
    _designationController.dispose();
    _experienceController.dispose();
    _educationController.dispose();
    _currentCompanyController.dispose();
    _currentCtcController.dispose();
    _expectedCtcController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isRecruiter ? 'Recruiter Profile' : 'Seeker Profile',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade700, Colors.blue.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 4,
        actions: [
          if (!widget.isRecruiter)
            IconButton(
              icon: const Icon(Icons.description, color: Colors.white),
              onPressed: () {
                final resumeData = _generateResumeData();
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade700, Colors.blue.shade900],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: const Text(
                        'Resume Preview',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    content: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Name: ${resumeData['name'] ?? 'N/A'}', style: const TextStyle(fontSize: 16)),
                          Text('Email: ${resumeData['email'] ?? 'N/A'}', style: const TextStyle(fontSize: 16)),
                          Text('Mobile: ${resumeData['mobileNumber'] ?? 'N/A'}', style: const TextStyle(fontSize: 16)),
                          const SizedBox(height: 8),
                          Text('Skills:', style: TextStyle(fontSize: 14, color: Colors.blue.shade800)),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: (resumeData['skills'] as List<dynamic>?)
                                    ?.cast<String>()
                                    .map((skill) => Chip(
                                          label: Text(skill),
                                          backgroundColor: Colors.teal.shade100,
                                          labelStyle: TextStyle(color: Colors.teal.shade900),
                                        ))
                                    .toList() ??
                                [Chip(
                                  label: const Text('N/A'),
                                  backgroundColor: Colors.grey.shade200,
                                )],
                          ),
                          Text('Education: ${resumeData['education'] ?? 'N/A'}', style: const TextStyle(fontSize: 16)),
                          Text('Experience: ${resumeData['experience'] ?? 'N/A'}', style: const TextStyle(fontSize: 16)),
                          Text('Specialization: ${resumeData['specialization'] ?? 'N/A'}', style: const TextStyle(fontSize: 16)),
                          Text('Current Company: ${resumeData['currentCompany'] ?? 'N/A'}', style: const TextStyle(fontSize: 16)),
                          Text('Current CTC: ${resumeData['currentCtc'] ?? 'N/A'}', style: const TextStyle(fontSize: 16)),
                          Text('Expected CTC: ${resumeData['expectedCtc'] ?? 'N/A'}', style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close', style: TextStyle(color: Colors.teal)),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
              ),
            )
          : errorMessage != null
              ? Center(
                  child: Card(
                    elevation: 4,
                    color: Colors.red.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        errorMessage!,
                        style: TextStyle(color: Colors.red.shade700, fontSize: 16),
                      ),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Form(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Image Display and Upload
                            Center(
                              child: Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: [Colors.blue.shade700, Colors.teal.shade400],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: CircleAvatar(
                                      radius: 70,
                                      backgroundImage: _imageFile != null
                                          ? FileImage(_imageFile!)
                                          : _imageUrl != null
                                              ? NetworkImage(_imageUrl!)
                                              : null,
                                      backgroundColor: Colors.grey.shade200,
                                      child: _imageFile == null && _imageUrl == null
                                          ? const Icon(Icons.person, size: 70, color: Colors.grey)
                                          : null,
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: _pickImage,
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.teal,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.2),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 24),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              widget.isRecruiter ? 'Company Logo' : 'Profile Photo',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            // Common Fields
                            _buildTextField(
                              'Name',
                              controller: _nameController,
                              validator: (value) => value == null || value.trim().isEmpty ? 'Name is required' : null,
                            ),
                            _buildNonEditableField('Mobile Number', _mobileNumber),
                            _buildNonEditableField('Email Id', _email),
                            // Recruiter-Specific Fields
                            if (widget.isRecruiter) ...[
                              _buildTextField(
                                'Company Name',
                                controller: _companyNameController,
                                validator: (value) => value == null || value.trim().isEmpty ? 'Company Name is required' : null,
                              ),
                              _buildTextField('Company Profile', multiline: true, controller: _companyProfileController),
                              _buildTextField('Designation', controller: _designationController),
                            ]
                            // Seeker-Specific Fields
                            else ...[
                              _buildSpecializationDropdown(),
                              _buildSkillsMultiSelect(),
                              _buildTextField(
                                'Education (e.g., Bachelor\'s in Computer Science)',
                                controller: _educationController,
                                validator: (value) => value == null || value.trim().isEmpty ? 'Education is required' : null,
                              ),
                              _buildTextField(
                                'Experience (e.g., 2 years)',
                                controller: _experienceController,
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Experience is required';
                                  }
                                  final match = RegExp(r'^\d+\s*(years?|yrs?)?$').hasMatch(value.trim());
                                  if (!match) {
                                    return 'Experience must be in format "X years" (e.g., "2 years")';
                                  }
                                  return null;
                                },
                              ),
                              _buildTextField('Current Company', controller: _currentCompanyController),
                              _buildTextField('Current CTC', controller: _currentCtcController),
                              _buildTextField('Expected CTC', controller: _expectedCtcController),
                            ],
                            const SizedBox(height: 24),
                            Center(
                              child: AnimatedScaleButton(
                                onPressed: _updateProfile,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.blue.shade700, Colors.teal.shade400],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    'Update Profile',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Center(
                              child: AnimatedScaleButton(
                                onPressed: _logout,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.red.shade600, Colors.red.shade800],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: const Text(
                                    'Logout',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
    );
  }
}

// Custom Animated Button Widget
class AnimatedScaleButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;

  const AnimatedScaleButton({required this.onPressed, required this.child, super.key});

  @override
  AnimatedScaleButtonState createState() => AnimatedScaleButtonState();
}

class AnimatedScaleButtonState extends State<AnimatedScaleButton> with SingleTickerProviderStateMixin {
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
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: widget.child,
      ),
    );
  }
}

// Multi-select dialog for skills
class MultiSelectDialog extends StatefulWidget {
  final List<String> items;
  final List<String> selectedItems;

  const MultiSelectDialog({required this.items, required this.selectedItems, super.key});

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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade700, Colors.blue.shade900],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: const Text(
          'Select Skills',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          children: widget.items.map((item) {
            return CheckboxListTile(
              title: Text(item, style: const TextStyle(color: Colors.black87)),
              value: _tempSelectedItems.contains(item),
              activeColor: Colors.teal,
              checkColor: Colors.white,
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
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context, _tempSelectedItems);
          },
          child: const Text('OK', style: TextStyle(color: Colors.teal)),
        ),
      ],
    );
  }
}
