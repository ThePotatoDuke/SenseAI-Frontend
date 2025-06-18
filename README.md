# SenseAI
<p float="left">
  <img src="https://i.imgur.com/aCocyGt.png" alt="SenseAI Home Screen" width="200" style="margin-right:10px;"/>
  <img src="https://i.imgur.com/0eJo6ww.png" alt="SenseAI Previous Chats" width="200" style="margin-right:10px;"/>
  <img src="https://i.imgur.com/dLJe9rj.png" alt="Chat screen" width="200"/>
</p>




**SenseAI** is a cross-platform Flutter application focused on promoting mental wellness and mindfulness using AI-powered guidance and interactive features.

## 🌟 Features

- 🧠 AI-powered mental wellness assistant  
- 📱 Cross-platform: Runs smoothly on Android and iOS  
- 🧘 Guided meditation and breathing exercises  
- 📊 Emotion tracking & journaling  
- 🔔 Daily mental health reminders  
- 💬 Chat-based interface using NLP models  

## 📦 Installation

You can download and install the latest APK to try out the app:

👉 [Download APK](https://yourlink.com/senseai-latest.apk)

> ⚠️ **Note:** Some features like the AI chatbot may not work because the backend is currently connected through a temporary `ngrok` tunnel. For full functionality, please run the project locally as described below.


To run this project locally:

1. Clone the repository:
   ```bash
   git clone https://github.com/YourUsername/SenseAI-Frontend.git
   cd SenseAI
Install dependencies:

bash
Copy
Edit
flutter pub get
Run the app:

bash
Copy
Edit
flutter run
Make sure you have Flutter SDK installed. You can check by running flutter doctor.

## 🔧 Backend Configuration

SenseAI communicates with a backend server for AI-powered analysis. To allow local development and testing, the backend URL is configurable.

By default, the app connects to a locally hosted server at:

http://192.168.1.10:5000/analyze/full

pgsql
Copy
Edit

> ⚠️ Replace `192.168.1.10` with your actual local IP address. Both your backend server and mobile device must be connected to the same Wi-Fi network.

### 💻 Running with a Custom Backend URL

You can override the backend URL using `--dart-define`:

flutter run --dart-define=BACKEND_URL=http://192.168.1.XX:5000
📦 Building the APK with a Custom Backend
If you're building a release version:

bash
Copy
Edit
flutter build apk --release --dart-define=BACKEND_URL=http://192.168.1.XX:5000
⚠️ APK Limitation Notice
You can download and install the APK here, but note:

🔒 The chatbot may not function unless the backend server is running and accessible on your local network.

If you are using the default build or a shared APK without setting up the backend, certain features will not work.



## 🛠 Tech Stack
Flutter – UI Framework

Dart – Programming Language

Firebase – Authentication and Cloud Firestore

GadgetBridge - For smart band compatibility
