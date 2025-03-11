import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:developer' as developer;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_allergy_identifier/routes.dart';

// Custom JSON decoder to handle NaN values
dynamic _parseAndDecode(String response) {
  // Replace NaN with null before parsing
  final sanitized = response
      .replaceAll('NaN', 'null')
      .replaceAll('Infinity', 'null')
      .replaceAll('-Infinity', 'null');
  return jsonDecode(sanitized);
}

// Helper function to convert Map<Object?, Object?> to Map<String, dynamic>
Map<String, dynamic> convertMap(Map<Object?, Object?> map) {
  return map.map((key, value) {
    // Convert nested maps
    if (value is Map<Object?, Object?>) {
      return MapEntry(key.toString(), convertMap(value));
    }
    // Convert nested lists
    else if (value is List) {
      return MapEntry(key.toString(), convertList(value));
    }
    // Convert simple values
    else {
      return MapEntry(key.toString(), value);
    }
  });
}

// Helper function to convert List<Object?> to List<dynamic>
List<dynamic> convertList(List<Object?> list) {
  return list.map((item) {
    if (item is Map<Object?, Object?>) {
      return convertMap(item);
    } else if (item is List) {
      return convertList(item as List<Object?>);
    } else {
      return item;
    }
  }).toList();
}

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _analysisData;

  @override
  void initState() {
    super.initState();
    _fetchAnalysis();
  }

  Future<void> _fetchAnalysis() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Get the Firebase Functions instance
      final functions = FirebaseFunctions.instance;
      
      // Create a reference to the 'getPollenAnalysis' callable function
      final callable = functions.httpsCallable('getPollenAnalysis');

      // Call the function (no payload needed)
      final result = await callable.call({});
      
      // Print only the raw response data
      // ignore: avoid_print
      print('ANALYSIS_RESPONSE: ${result.data}');
      
      // The result data needs to be properly converted
      final rawData = result.data;
      
      // Check if we have data and convert it to the right type
      if (rawData != null) {
        Map<String, dynamic> convertedData;
        
        if (rawData is Map<Object?, Object?>) {
          // Convert the map to the correct type
          convertedData = convertMap(rawData);
        } else if (rawData is Map) {
          // Try direct casting if possible
          convertedData = Map<String, dynamic>.from(rawData);
        } else {
          throw Exception('Unexpected data type: ${rawData.runtimeType}');
        }
        
        setState(() {
          _analysisData = convertedData;
          _isLoading = false;
        });
      } else {
        setState(() {
          _analysisData = null;
          _isLoading = false;
        });
      }
    } on FirebaseFunctionsException catch (e) {
      // Handle Firebase Functions specific errors
      
      // If this is a "not enough data" error, don't treat it as an error
      // but instead set a "not enough data" state
      if (e.message?.toLowerCase().contains('not enough data') == true || 
          e.code == 'internal' && e.message?.contains('3 feedback entries') == true) {
        setState(() {
          _analysisData = {'dataPoints': 0, 'notEnoughData': true};
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Error: ${e.message}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Allergy Analysis'),
        actions: [
          // Show debug indicator in debug mode
          if (kDebugMode)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'DEBUG',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: isDesktop ? 900 : double.infinity,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 32.0 : 16.0,
            vertical: 16.0,
          ),
          child: _buildContent(context, isDesktop),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchAnalysis,
        tooltip: 'Refresh',
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isDesktop) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Analyzing your feedback data...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              'Error: $_errorMessage',
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchAnalysis,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (_analysisData == null) {
      return const Center(child: Text('No analysis data available.'));
    }

    // Extract data points count
    final dataPoints = _analysisData!['dataPoints'] ?? 0;
    final notEnoughData = _analysisData!['notEnoughData'] == true || dataPoints < 3;

    // If we don't have enough data, show a single, clear message
    if (notEnoughData) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, color: Colors.blue, size: 64),
            const SizedBox(height: 24),
            const Text(
              'More Data Needed',
              style: TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                dataPoints == 0
                    ? 'You haven\'t submitted any feedback yet.'
                    : dataPoints == 1
                        ? 'You currently have 1 feedback entry. You need at least 3 feedback entries for analysis.'
                        : 'You currently have $dataPoints feedback entries. You need at least 3 feedback entries for analysis.',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                'Submit feedback on days when you feel good and days when you have symptoms to help us identify patterns.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, Routes.feedback);
              },
              icon: const Icon(Icons.rate_review),
              label: const Text('Submit Feedback'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    // Extract all correlations
    final correlations = _analysisData!['correlations'] as Map<String, dynamic>? ?? {};

    // Check if we have any valid correlations
    bool hasValidCorrelations = false;
    correlations.forEach((key, value) {
      if (value is Map<String, dynamic> && value['correlation'] != null) {
        hasValidCorrelations = true;
      }
    });

    // If we have enough data points but no valid correlations, show a different message
    if (!hasValidCorrelations) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.analytics, color: Colors.orange, size: 64),
            const SizedBox(height: 24),
            const Text(
              'More Varied Data Needed',
              style: TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                'You have $dataPoints feedback entries, but we need more varied data to identify patterns.',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                'Try submitting feedback on days when you have different symptom levels and at different locations to help us identify patterns.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, Routes.feedback);
              },
              icon: const Icon(Icons.rate_review),
              label: const Text('Submit More Feedback'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Text(
            'Your Allergy Analysis',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Based on $dataPoints feedback entries',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // Correlations card
          _buildCorrelationsCard(correlations),
          
          const SizedBox(height: 24),

          // Explanation
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Understanding the Analysis',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Positive correlation values indicate that higher pollen levels are associated with worse symptoms. '
                    'The stronger the positive correlation, the more likely that pollen type is affecting you.\n\n'
                    'Negative correlation values suggest that higher pollen levels are associated with fewer symptoms for that pollen type.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Continue submitting daily feedback to improve the accuracy of this analysis.',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          
          // Debug section to show raw backend response data
          if (kDebugMode && _analysisData != null) ...[
            const SizedBox(height: 32),
            const Divider(thickness: 2),
            const SizedBox(height: 16),
            
            Row(
              children: [
                const Icon(Icons.bug_report, color: Colors.grey),
                const SizedBox(width: 8),
                const Text(
                  'DEBUG: Backend Response Data',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.content_copy, size: 18),
                  onPressed: () {
                    // Copy the JSON to clipboard
                    final jsonString = const JsonEncoder.withIndent('  ')
                        .convert(_analysisData);
                    // This would use a clipboard package in a real app
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('JSON copied to clipboard')),
                    );
                  },
                  tooltip: 'Copy JSON',
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            Card(
              color: Colors.grey.shade100,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Display the keys in the response
                    Text(
                      'Response Keys: ${_analysisData!.keys.join(', ')}',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Display the raw JSON in a scrollable container
                    Container(
                      constraints: const BoxConstraints(maxHeight: 300),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Text(
                            const JsonEncoder.withIndent('  ')
                                .convert(_analysisData),
                            style: const TextStyle(
                              color: Colors.lightGreenAccent,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCorrelationsCard(Map<String, dynamic> correlations) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Potential Allergens',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Pollen types sorted from most positive to most negative correlations. Positive values suggest potential allergies.',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            if (correlations.isEmpty)
              const Text('No correlation data available.')
            else
              ..._getSortedCorrelations(correlations).map((entry) {
                final pollenType = entry.key;
                final data = entry.value as Map<String, dynamic>? ?? {};
                final correlation = data['correlation'];
                final pValue = data['p_value'];
                final significant = data['significant'] ?? false;

                // Skip if correlation is null
                if (correlation == null) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            pollenType,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ),
                        const Text(
                          'Insufficient data',
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Determine color based on correlation strength
                Color barColor;
                if (correlation > 0.5) {
                  barColor = Colors.red;
                } else if (correlation > 0.3) {
                  barColor = Colors.orange;
                } else if (correlation > 0) {
                  barColor = Colors.yellow;
                } else if (correlation > -0.3) {
                  barColor = Colors.green.shade300;
                } else {
                  barColor = Colors.green;
                }

                // Calculate bar width as percentage of max width
                final barWidth = (correlation.abs() * 100).clamp(5, 100);
                
                // Format correlation as percentage
                final correlationStr = (correlation * 100)
                    .toStringAsFixed(1);

                // Determine if this is a positive or negative correlation
                final isPositive = correlation > 0;
                final correlationText = '$correlationStr%';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              pollenType,
                              style: TextStyle(
                                fontWeight: significant ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          Text(
                            correlationText,
                            style: TextStyle(
                              color: significant ? Colors.red : Colors.black,
                            ),
                          ),
                          if (isPositive && correlation > 0.2)
                            Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: Icon(
                                Icons.warning,
                                color: significant ? Colors.red : Colors.orange,
                                size: 16,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: 12,
                        width: MediaQuery.of(context).size.width * barWidth / 100,
                        decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
          ],
        ),
      ),
    );
  }
  
  // Helper method to sort correlations by actual value (not absolute value)
  List<MapEntry<String, dynamic>> _getSortedCorrelations(Map<String, dynamic> correlations) {
    final entries = correlations.entries.toList();
    
    // Sort by correlation value, most positive first to most negative last
    entries.sort((a, b) {
      final aData = a.value as Map<String, dynamic>? ?? {};
      final bData = b.value as Map<String, dynamic>? ?? {};
      
      final aCorrelation = aData['correlation'] as double?;
      final bCorrelation = bData['correlation'] as double?;
      
      // Handle null values
      if (aCorrelation == null && bCorrelation == null) return 0;
      if (aCorrelation == null) return 1; // b comes first
      if (bCorrelation == null) return -1; // a comes first
      
      // Sort by actual value, most positive first
      return bCorrelation.compareTo(aCorrelation);
    });
    
    return entries;
  }
}
