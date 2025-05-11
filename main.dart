import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SubsidyCalculatorApp());
}

class SubsidyCalculatorApp extends StatelessWidget {
  const SubsidyCalculatorApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Pakistan Electricity Subsidy Calculator',
      theme: ThemeData(
        primarySwatch: Colors.green,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.green.shade50,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.green),
          titleTextStyle: TextStyle(
            color: Colors.green.shade800,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final List<Widget> _screens = [
    const SubsidyCalculatorScreen(),
    const DashboardScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: 'Calculator',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

// Model for Calculation History
class CalculationRecord {
  final int income;
  final int familyMembers;
  final String area;
  final double subsidy;
  final bool solarEligible;
  final DateTime timestamp;

  CalculationRecord({
    required this.income,
    required this.familyMembers,
    required this.area,
    required this.subsidy,
    required this.solarEligible,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'income': income,
      'familyMembers': familyMembers,
      'area': area,
      'subsidy': subsidy,
      'solarEligible': solarEligible,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory CalculationRecord.fromJson(Map<String, dynamic> json) {
    return CalculationRecord(
      income: json['income'],
      familyMembers: json['familyMembers'],
      area: json['area'],
      subsidy: json['subsidy'],
      solarEligible: json['solarEligible'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

// Storage Service for Calculation History
class StorageService {
  static const String _historyKey = 'calculation_history';

  static Future<List<CalculationRecord>> getCalculationHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList(_historyKey) ?? [];
    
    return historyJson.map((recordJson) {
      return CalculationRecord.fromJson(json.decode(recordJson));
    }).toList();
  }

  static Future<void> saveCalculation(CalculationRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getStringList(_historyKey) ?? [];
    
    // Add new record
    historyJson.add(json.encode(record.toJson()));
    
    // Keep only the latest 50 records
    if (historyJson.length > 50) {
      historyJson.removeAt(0);
    }
    
    await prefs.setStringList(_historyKey, historyJson);
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_historyKey, []);
  }
}

class SubsidyCalculator {
  /// Calculates the monthly electricity subsidy for a family based on income, 
  /// family size, and area.
  ///
  /// Parameters:
  /// - income: Monthly family income in Rupees
  /// - familyMembers: Number of family members
  /// - area: "Urban" or "Rural"
  ///
  /// Returns the calculated subsidy amount in Rupees.
  double calculateSubsidy(int income, int familyMembers, String area) {
    // Base subsidy
    const double baseSubsidy = 2000.0;
    
    // Calculate income adjustment factor
    double incomeAdjustmentFactor;
    if (income < 15000) {
      incomeAdjustmentFactor = 1.5;
    } else if (income >= 15000 && income <= 30000) {
      incomeAdjustmentFactor = 1.2;
    } else {
      incomeAdjustmentFactor = 1.0;
    }
    
    // Calculate family size adjustment factor
    double familySizeAdjustment = 1 + 0.1 * (familyMembers - 4);
    // Cap the family size adjustment factor at 2.0
    familySizeAdjustment = familySizeAdjustment > 2.0 ? 2.0 : familySizeAdjustment;
    familySizeAdjustment = familySizeAdjustment < 0.6 ? 0.6 : familySizeAdjustment;
    
    // Area adjustment factor
    double areaAdjustmentFactor = area == 'Rural' ? 1.2 : 1.0;
    
    // Calculate the final subsidy
    double finalSubsidy = baseSubsidy * incomeAdjustmentFactor * familySizeAdjustment * areaAdjustmentFactor;
    
    return finalSubsidy;
  }
  
  /// Determines if a family is eligible for the Roshan Gharana solar panel program.
  ///
  /// Parameters:
  /// - income: Monthly family income in Rupees
  /// - area: "Urban" or "Rural"
  ///
  /// Returns true if eligible, false otherwise.
  bool isEligibleForSolar(int income, String area) {
    // Family is eligible if income is less than Rs 20,000 AND area is Rural
    return income < 20000 && area == 'Rural';
  }
  
  /// Checks if the total subsidies remain within the government budget
  ///
  /// Parameters:
  /// - subsidies: List of subsidy amounts
  /// - governmentBudget: Total budget allocated by government
  ///
  /// Returns true if total subsidies are within budget, false otherwise
  bool isAffordable(List<double> subsidies, double governmentBudget) {
    double totalSubsidies = subsidies.fold(0, (sum, subsidy) => sum + subsidy);
    return totalSubsidies <= governmentBudget;
  }
}

class SubsidyCalculatorScreen extends StatefulWidget {
  const SubsidyCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<SubsidyCalculatorScreen> createState() => _SubsidyCalculatorScreenState();
}

class _SubsidyCalculatorScreenState extends State<SubsidyCalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _incomeController = TextEditingController();
  final _familyMembersController = TextEditingController();
  String _selectedArea = 'Urban';
  
  double _subsidy = 0;
  bool _solarEligible = false;
  bool _hasCalculated = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _incomeController.dispose();
    _familyMembersController.dispose();
    super.dispose();
  }

  Future<void> _calculateSubsidy() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // Simulating network delay
      await Future.delayed(const Duration(milliseconds: 500));

      final income = int.parse(_incomeController.text);
      final familyMembers = int.parse(_familyMembersController.text);
      final area = _selectedArea;

      final calculator = SubsidyCalculator();
      final subsidy = calculator.calculateSubsidy(income, familyMembers, area);
      final solarEligible = calculator.isEligibleForSolar(income, area);

      // Save calculation record
      final record = CalculationRecord(
        income: income,
        familyMembers: familyMembers,
        area: area,
        subsidy: subsidy,
        solarEligible: solarEligible,
        timestamp: DateTime.now(),
      );
      await StorageService.saveCalculation(record);

      setState(() {
        _subsidy = subsidy;
        _solarEligible = solarEligible;
        _hasCalculated = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Electricity Subsidy Calculator'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Banner Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 120,
                      color: Colors.green.shade100,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.eco,
                              size: 40,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Roshan Pakistan Energy Program',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Description
                  Card(
                    elevation: 0,
                    color: Colors.blue.shade50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Text(
                            'Energy Access Reform Calculator',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Calculate your eligibility for electricity subsidies and solar panel installation under the national energy access reforms.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Monthly Income Input
                  _buildInputLabel('Monthly Family Income (Rs)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _incomeController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Enter monthly income in rupees',
                      prefixIcon: Icon(Icons.money),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your monthly income';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Family Members Input
                  _buildInputLabel('Number of Family Members'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _familyMembersController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Enter number of family members',
                      prefixIcon: Icon(Icons.people),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter the number of family members';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Area Dropdown
                  _buildInputLabel('Area'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedArea,
                        icon: const Icon(Icons.keyboard_arrow_down),
                        items: ['Urban', 'Rural'].map((String area) {
                          return DropdownMenuItem<String>(
                            value: area,
                            child: Row(
                              children: [
                                Icon(
                                  area == 'Urban' ? Icons.location_city : Icons.landscape,
                                  color: Colors.grey.shade700,
                                ),
                                const SizedBox(width: 12),
                                Text(area),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _selectedArea = newValue;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Calculate Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _calculateSubsidy,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: _isLoading 
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'CALCULATE SUBSIDY',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Results Section
                  if (_hasCalculated) ...[
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green),
                              const SizedBox(width: 8),
                              Text(
                                'Results',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Subsidy Amount
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.money, color: Colors.green),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Monthly Subsidy Amount',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Rs ${_subsidy.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Solar Eligibility
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _solarEligible 
                                      ? Colors.orange.shade100 
                                      : Colors.grey.shade200,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.wb_sunny, 
                                  color: _solarEligible ? Colors.orange : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Roshan Gharana Solar Program',
                                      style: TextStyle(
                                        color: Colors.black54,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _solarEligible 
                                          ? 'Eligible for solar panel installation'
                                          : 'Not eligible for solar panel installation',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: _solarEligible ? Colors.green.shade800 : Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          // Calculation Breakdown Section
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 16),
                          Text(
                            'Calculation Breakdown',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildCalculationDetail('Base Subsidy', 'Rs 2,000'),
                          _buildCalculationDetail(
                            'Income Adjustment', 
                            '${_getIncomeAdjustmentFactor(int.parse(_incomeController.text))}x'
                          ),
                          _buildCalculationDetail(
                            'Family Size Adjustment', 
                            '${_getFamilySizeAdjustmentFactor(int.parse(_familyMembersController.text))}x'
                          ),
                          _buildCalculationDetail(
                            'Area Adjustment', 
                            '${_selectedArea == 'Rural' ? '1.2x' : '1.0x'}'
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: Colors.black87,
      ),
    );
  }
  
  Widget _buildCalculationDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade700,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  String _getIncomeAdjustmentFactor(int income) {
    if (income < 15000) {
      return '1.5';
    } else if (income >= 15000 && income <= 30000) {
      return '1.2';
    } else {
      return '1.0';
    }
  }
  
  String _getFamilySizeAdjustmentFactor(int familyMembers) {
    double factor = 1 + 0.1 * (familyMembers - 4);
    factor = factor > 2.0 ? 2.0 : factor;
    factor = factor < 0.6 ? 0.6 : factor;
    return factor.toStringAsFixed(1);
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<CalculationRecord> _calculationHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCalculationHistory();
  }

  Future<void> _loadCalculationHistory() async {
    setState(() {
      _isLoading = true;
    });

    final history = await StorageService.getCalculationHistory();
    
    setState(() {
      _calculationHistory = history;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCalculationHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _calculationHistory.isEmpty
              ? _buildEmptyState()
              : _buildDashboardContent(),
    );
  }

 Widget _buildEmptyState() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.history,
          size: 80,
          color: Colors.grey.shade300,
        ),
        const SizedBox(height: 16),
        Text(
          'No calculation history yet',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your calculation history will appear here',
          style: TextStyle(
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          icon: const Icon(Icons.calculate),
          label: const Text('Go to Calculator'),
          onPressed: () {
            // Use Navigator instead of direct state manipulation
            Navigator.of(context).pushReplacementNamed('/calculator'); // If you have named routes
            
            // Alternatively, if you're using a TabController or bottom navigation elsewhere:
            // final TabController? tabController = DefaultTabController.of(context);
            // if (tabController != null) {
            //   tabController.animateTo(0);
            // }
          },
        ),
      ],
    ),
  );
}

  Widget _buildDashboardContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStatisticsCard(),
          const SizedBox(height: 24),
          _buildSubsidyChart(),
          const SizedBox(height: 24),
          _buildHistoryList(),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
    // Calculate statistics
    final totalCalculations = _calculationHistory.length;
    final avgSubsidy = _calculationHistory.isEmpty
        ? 0.0
        : _calculationHistory.map((e) => e.subsidy).reduce((a, b) => a + b) / totalCalculations;
    final solarEligibleCount = _calculationHistory.where((e) => e.solarEligible).length;
    final solarEligiblePercentage = totalCalculations > 0
        ? (solarEligibleCount / totalCalculations * 100).toStringAsFixed(1)
        : '0';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Summary Statistics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Total Calculations',
                    totalCalculations.toString(),
                    Icons.calculate,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Average Subsidy',
                    'Rs ${avgSubsidy.toStringAsFixed(2)}',
                    Icons.money,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Solar Eligible',
                    '$solarEligibleCount families',
                    Icons.wb_sunny,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Eligibility Rate',
                    '$solarEligiblePercentage%',
                    Icons.pie_chart,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 28,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildSubsidyChart() {
    // Get the last 7 records for the chart or fewer if not available
    final chartData = _calculationHistory.length > 7
        ? _calculationHistory.sublist(_calculationHistory.length - 7)
        : _calculationHistory;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Subsidy Trend',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Last ${chartData.length} calculations',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            chartData.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        'No data available for chart',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  )
                : SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 1000,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                              color: Colors.grey.shade200,
                              strokeWidth: 1,
                            );
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() >= 0 && value.toInt() < chartData.length) {
                                  final date = chartData[value.toInt()].timestamp;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(
                                      DateFormat('dd/MM').format(date),
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 10,
                                      ),
                                    ),
                                  );
                                }
                                return const Text('');
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString(),
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 10,
                                  ),
                                );
                              },
                              reservedSize: 40,
                            ),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        minX: 0,
                        maxX: (chartData.length - 1).toDouble(),
                        minY: 0,
                        maxY: chartData.isEmpty
                            ? 5000
                            : (chartData.map((e) => e.subsidy).reduce((a, b) => a > b ? a : b) * 1.2),
                        lineBarsData: [
                          LineChartBarData(
                            spots: List.generate(
                              chartData.length,
                              (index) => FlSpot(
                                index.toDouble(),
                                chartData[index].subsidy,
                              ),
                            ),
                            isCurved: true,
                            color: Colors.green,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                return FlDotCirclePainter(
                                  radius: 4,
                                  color: Colors.white,
                                  strokeWidth: 2,
                                  strokeColor: Colors.green,
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.green.withOpacity(0.2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Calculation History',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            if (_calculationHistory.isNotEmpty)
              TextButton.icon(
                icon: Icon(
                  Icons.delete,
                  color: Colors.red.shade400,
                  size: 18,
                ),
                label: Text(
                  'Clear',
                  style: TextStyle(
                    color: Colors.red.shade400,
                  ),
                ),
                onPressed: () async {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Clear History'),
                      content: const Text(
                        'Are you sure you want to clear all calculation history? This cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('CANCEL'),
                        ),
                        TextButton(
                          onPressed: () async {
                            await StorageService.clearHistory();
                            Navigator.pop(context);
                            _loadCalculationHistory();
                          },
                          child: const Text('CLEAR'),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_calculationHistory.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                'No calculation history available',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _calculationHistory.length,
            itemBuilder: (context, index) {
              final record = _calculationHistory[_calculationHistory.length - 1 - index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: record.solarEligible
                          ? Colors.orange.shade100
                          : Colors.blue.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      record.solarEligible ? Icons.wb_sunny : Icons.lightbulb,
                      color: record.solarEligible ? Colors.orange : Colors.blue,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        'Rs ${record.subsidy.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: record.solarEligible
                              ? Colors.green.shade100
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          record.solarEligible
                              ? 'Solar Eligible'
                              : 'Solar Ineligible',
                          style: TextStyle(
                            fontSize: 12,
                            color: record.solarEligible
                                ? Colors.green.shade800
                                : Colors.grey.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'Income: Rs ${record.income} | Family: ${record.familyMembers} | Area: ${record.area}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd MMM yyyy, HH:mm').format(record.timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode = false;
  bool _notificationsEnabled = true;
  String _language = 'English';
  final List<String> _availableLanguages = ['English', 'Urdu', 'Punjabi', 'Sindhi'];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = prefs.getBool('darkMode') ?? false;
      _notificationsEnabled = prefs.getBool('notifications') ?? true;
      _language = prefs.getString('language') ?? 'English';
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', _darkMode);
    await prefs.setBool('notifications', _notificationsEnabled);
    await prefs.setString('language', _language);

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Settings saved successfully'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildProfileSection(),
            const SizedBox(height: 24),
            _buildGeneralSettingsSection(),
            const SizedBox(height: 24),
            _buildNotificationSection(),
            const SizedBox(height: 24),
            _buildAboutSection(),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('SAVE SETTINGS'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.green.shade100,
              child: Icon(
                Icons.person,
                size: 40,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Guest User',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Using the app in guest mode',
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Account feature coming soon!'),
                    backgroundColor: Colors.blue,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Create Account'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralSettingsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'General Settings',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 16),
            _buildSettingsSwitchTile(
              'Dark Mode',
              'Enable dark theme for the app',
              Icons.dark_mode,
              _darkMode,
              (value) {
                setState(() {
                  _darkMode = value;
                });
              },
            ),
            const Divider(),
            _buildLanguageSetting(),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSetting() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.language,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Language',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Change the language of the app',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          DropdownButton<String>(
            value: _language,
            underline: Container(),
            items: _availableLanguages.map((language) {
              return DropdownMenuItem<String>(
                value: language,
                child: Text(language),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _language = value;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notifications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 16),
            _buildSettingsSwitchTile(
              'Enable Notifications',
              'Receive important updates and alerts',
              Icons.notifications,
              _notificationsEnabled,
              (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'About',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 16),
            _buildSettingsListTile(
              'App Version',
              '1.0.0',
              Icons.info,
              () {},
            ),
            const Divider(),
            _buildSettingsListTile(
              'Terms & Conditions',
              'Read our terms and conditions',
              Icons.description,
              () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Terms & Conditions coming soon!'),
                    backgroundColor: Colors.blue,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
            ),
            const Divider(),
            _buildSettingsListTile(
              'Privacy Policy',
              'Read our privacy policy',
              Icons.privacy_tip,
              () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Privacy Policy coming soon!'),
                    backgroundColor: Colors.blue,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
            ),
            const Divider(),
            _buildSettingsListTile(
              'Contact Support',
              'Get help with the app',
              Icons.support_agent,
              () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Support feature coming soon!'),
                    backgroundColor: Colors.blue,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.blue.shade700,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsListTile(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}