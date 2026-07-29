# GreenEYe 🌿

[![Live Demo](https://img.shields.io/badge/🌿_Live_Demo-Click_Here-4CAF50?style=for-the-badge&logo=googlechrome&logoColor=white)](https://YOUR_USERNAME.github.io/GreenEYe/) (work in progress)

GreenEYe is a real-time plant disease classifier built with Flutter and TensorFlow Lite. It aims to support the **Sustainable Development Goals (SDG)**, specifically focusing on "Life on Land" by helping farmers and home gardeners identify plant pathologies early and take action with recommended treatments.

## ✨ Features

- **Real-time Classification:** Uses the device camera to identify diseases instantly.
- **Offline-first:** Model inference happens on-device using TFLite, requiring no internet connection.
- **Actionable Insights:** Provides detailed descriptions and specific treatment steps for identified conditions.
- **Multi-Platform:** Support for Android, iOS, and web.

## 🚀 How it Works

1.  **Image Stream:** The app captures live frames from the `camera` package.
2.  **TFLite Inference:** Frames are processed by the `plant_model.tflite` model.
3.  **Label Parsing:** The app uses custom logic to clean raw model output (e.g., removing numeric indices and formatting underscores).
4.  **Data Mapping:** The cleaned label is matched against a repository of plant diseases in `lib/models/plant_disease.dart`, which provides:
    *   Scientific names of pathogens.
    *   Detailed symptoms.
    *   Step-by-step treatment plans.

## 🛠️ Installation & Setup

### Prerequisites
- Flutter SDK (v3.0.0 or higher)
- Android Studio / Xcode for mobile deployment
- TFLite Model: Ensure `assets/models/plant_model.tflite` and `assets/models/labels.txt` are present.

### Setup Steps

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/SedikDarragi/GreenEye.git
    cd GreenEye
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Run the application:**
    ```bash
    # For a specific device
    flutter run
    ```

## 📂 Project Structure

- `lib/models/`: Contains the logic for disease data and label cleaning.
- `assets/models/`: Stores the TFLite model and labels.
- `analysis_options.yaml`: Configured with strict linting for high code quality.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

---
*Developed as a tool for sustainable agriculture and environmental protection.*
