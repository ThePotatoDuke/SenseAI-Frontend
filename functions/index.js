const functions = require("firebase-functions");
const speech = require("@google-cloud/speech");

const client = new speech.SpeechClient(); // Uses Firebase default credentials

exports.transcribeAudio = functions.https.onRequest(async (req, res) => {
  try {
    const audioBytes = req.body.audio; // Base64 encoded WAV file

    const audio = { content: audioBytes };
    const config = {
      encoding: "LINEAR16",
      sampleRateHertz: 44100,
      languageCode: "en-US",
      enableAutomaticPunctuation: true,
    };

    const request = { audio, config };

    const [response] = await client.recognize(request);
    const transcript = response.results
      .map((result) => result.alternatives[0].transcript)
      .join("\n");

    res.status(200).send({ transcript });
  } catch (e) {
    console.error(e);
    res.status(500).send("Failed to transcribe");
  }
});
