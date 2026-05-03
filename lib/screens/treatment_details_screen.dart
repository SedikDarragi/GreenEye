import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/plant_disease.dart';

class TreatmentDetailsScreen extends StatelessWidget {
  final PlantDisease disease;

  const TreatmentDetailsScreen({super.key, required this.disease});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(disease.name, style: GoogleFonts.poppins()),
        backgroundColor: Colors.green.shade900,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Recommended Treatment",
              style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(disease.description, style: const TextStyle(fontStyle: FontStyle.italic)),
            const SizedBox(height: 15),
            Expanded(
              child: ListView.builder(
                itemCount: disease.treatments.length,
                itemBuilder: (context, index) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green,
                    child: Text("${index + 1}", style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(disease.treatments[index]),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () => Navigator.pop(context),
                child: const Text("DONE"),
              ),
            )
          ],
        ),
      ),
    );
  }
}