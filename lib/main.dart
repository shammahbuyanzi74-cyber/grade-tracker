import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:charts_flutter/flutter.dart' as charts;

void main() async {
  await Hive.initFlutter();
  Hive.registerAdapter(GradeAdapter());
  await Hive.openBox<Grade>('grades');
  runApp(const GradeTrackerApp());
}

class GradeTrackerApp extends StatelessWidget {
  const GradeTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Medical School Grade Tracker',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        scaffoldBackgroundColor: Colors.teal.shade50,
      ),
      home: const DashboardPage(),
    );
  }
}

@HiveType(typeId: 0)
class Grade extends HiveObject {
  @HiveField(0)
  String subject;

  @HiveField(1)
  int score;

  @HiveField(2)
  int semester;

  Grade(this.subject, this.score, this.semester);

  String get status => score >= 50 ? "Pass" : "Fail";
}

class GradeAdapter extends TypeAdapter<Grade> {
  @override
  final typeId = 0;

  @override
  Grade read(BinaryReader reader) {
    return Grade(reader.readString(), reader.readInt(), reader.readInt());
  }

  @override
  void write(BinaryWriter writer, Grade obj) {
    writer.writeString(obj.subject);
    writer.writeInt(obj.score);
    writer.writeInt(obj.semester);
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<Grade>('grades');
    return Scaffold(
      appBar: AppBar(title: const Text("Dashboard")),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<Grade> gradesBox, _) {
          final grades = gradesBox.values.toList();
          final total = grades.length;
          final passes = grades.where((g) => g.score >= 50).length;
          final fails = total - passes;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  "Summary: $total subjects | $passes Pass | $fails Fail",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SemesterPage()),
                  );
                },
                child: const Text("Go to Grade Tracker"),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SemesterPage extends StatefulWidget {
  const SemesterPage({super.key});

  @override
  _SemesterPageState createState() => _SemesterPageState();
}

class _SemesterPageState extends State<SemesterPage> {
  final _subjectController = TextEditingController();
  final _scoreController = TextEditingController();
  final _semesterController = TextEditingController();
  String _suggestion = "";

  void _addGrade() {
    final box = Hive.box<Grade>('grades');
    final grade = Grade(
      _subjectController.text,
      int.parse(_scoreController.text),
      int.parse(_semesterController.text),
    );
    box.add(grade);
    _subjectController.clear();
    _scoreController.clear();
    _semesterController.clear();
  }

  void _analyzePerformance(List<Grade> grades) {
    final fails = grades.where((g) => g.score < 50).toList();
    if (fails.isEmpty) {
      setState(() {
        _suggestion = "Excellent! You passed all subjects.";
      });
    } else {
      setState(() {
        _suggestion = "You need to improve in: " +
            fails.map((g) => "${g.subject} (Semester ${g.semester})").join(", ");
      });
    }
  }

  void _predictImprovement(List<Grade> grades) {
    final fails = grades.where((g) => g.score < 50).toList();
    if (fails.isEmpty) {
      setState(() {
        _suggestion = "No prediction needed — all passes!";
      });
    } else {
      setState(() {
        _suggestion =
            "Prediction: To clear all fails by Semester 3, aim for at least 60% in upcoming subjects.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<Grade>('grades');
    return Scaffold(
      appBar: AppBar(title: const Text("Medical School Tracker")),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<Grade> gradesBox, _) {
          final grades = gradesBox.values.toList();

          final barSeries = [
            charts.Series<Grade, String>(
              id: 'Grades',
              colorFn: (Grade grade, _) =>
                  grade.score >= 50 ? charts.MaterialPalette.green.shadeDefault
                                    : charts.MaterialPalette.red.shadeDefault,
              domainFn: (Grade grade, _) =>
                  "${grade.subject} (S${grade.semester})",
              measureFn: (Grade grade, _) => grade.score,
              data: grades,
            )
          ];

          final lineSeries = [
            charts.Series<Grade, int>(
              id: 'Semester Progress',
              colorFn: (_, __) => charts.MaterialPalette.teal.shadeDefault,
              domainFn: (Grade grade, _) => grade.semester,
              measureFn: (Grade grade, _) => grade.score,
              data: grades,
            )
          ];

          return SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: 300, child: charts.BarChart(barSeries, animate: true)),
                SizedBox(height: 300, child: charts.LineChart(lineSeries, animate: true)),
                ElevatedButton(
                  onPressed: () => _analyzePerformance(grades),
                  child: const Text("Analyze Performance"),
                ),
                ElevatedButton(
                  onPressed: () => _predictImprovement(grades),
                  child: const Text("Predict Improvement"),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(_suggestion,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                // Input form
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      TextField(
                          controller: _subjectController,
                          decoration:
                              const InputDecoration(labelText: "Subject")),
                      TextField(
                          controller: _scoreController,
                          decoration:
                              const InputDecoration(labelText: "Score")),
                      TextField(
                          controller: _semesterController,
                          decoration:
                              const InputDecoration(labelText: "Semester")),
                      ElevatedButton(
                          onPressed: _addGrade,
                          child: const Text("Add Grade")),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
