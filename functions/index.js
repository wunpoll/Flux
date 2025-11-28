// functions/index.js
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {VertexAI} = require("@google-cloud/vertexai");
const {setGlobalOptions} = require("firebase-functions/v2");

// Явно задаем настройки для Gen 2
setGlobalOptions({region: "us-central1"});

const vertexAi = new VertexAI({
  project: process.env.GCLOUD_PROJECT,
  location: "us-central1",
});

exports.chatWithGemini = onCall(async (request) => {
  // В Gen 2 данные лежат внутри request.data
  const data = request.data;

  // Логируем входящие данные
  console.log("Incoming data:", JSON.stringify(data));

  const {systemInstructionText, allMessagesFromFlutter} = data;

  if (!systemInstructionText || !allMessagesFromFlutter ||
      !Array.isArray(allMessagesFromFlutter) ||
      allMessagesFromFlutter.length === 0) {
    throw new HttpsError(
        "invalid-argument",
        "Invalid input: systemInstructionText/allMessagesFromFlutter required.",
    );
  }

  try {
    const model = vertexAi.getGenerativeModel({model: "gemini-2.5-flash"});

    const lastMsgIndex = allMessagesFromFlutter.length - 1;
    const currentUserMessage = allMessagesFromFlutter[lastMsgIndex];

    if (currentUserMessage.role !== "user" || !currentUserMessage.text) {
      throw new HttpsError(
          "invalid-argument",
          "Last message must be from user.",
      );
    }

    // Формируем историю
    const history = [];
    for (let i = 0; i < allMessagesFromFlutter.length - 1; i++) {
      const msg = allMessagesFromFlutter[i];
      if (msg.text) {
        history.push({
          role: msg.role === "user" ? "user" : "model",
          parts: [{text: msg.text}],
        });
      }
    }

    const chat = model.startChat({
      systemInstruction: {
        role: "system",
        parts: [{text: systemInstructionText}],
      },
      history: history,
    });

    const result = await chat.sendMessage(currentUserMessage.text);

    // Безопасное извлечение ответа
    const candidate = result.response.candidates[0];
    const responseText = candidate?.content?.parts[0]?.text ||
        "No response text.";

    return {text: responseText};
  } catch (error) {
    console.error("Vertex AI Error:", error);
    throw new HttpsError("internal", "AI processing failed", error.message);
  }
});
